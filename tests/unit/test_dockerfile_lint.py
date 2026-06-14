"""Unit tests : Dockerfile lint + image structure invariants."""
from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

import pytest


IMAGES = [
    "mariadb",
    "centreon-engine",
    "centreon-broker-sql",
    "centreon-broker-rrd",
    "centreon-gorgone",
    "centreon-web",
]


@pytest.fixture
def images_dir(project_root) -> Path:
    return project_root / "images"


@pytest.mark.unit
@pytest.mark.parametrize("img", IMAGES)
def test_dockerfile_exists(images_dir: Path, img: str):
    assert (images_dir / img / "Dockerfile").is_file()


@pytest.mark.unit
@pytest.mark.parametrize("img", IMAGES)
def test_image_has_entrypoint(images_dir: Path, img: str):
    # mariadb uses the upstream docker-entrypoint.sh
    if img == "mariadb":
        pytest.skip("mariadb uses upstream docker-entrypoint.sh")
    assert (images_dir / img / "entrypoint.sh").is_file()


@pytest.mark.unit
@pytest.mark.parametrize("img", IMAGES)
def test_image_has_healthcheck(images_dir: Path, img: str):
    assert (images_dir / img / "healthcheck.sh").is_file()


@pytest.mark.unit
@pytest.mark.parametrize("img", IMAGES)
def test_dockerfile_non_root_user(images_dir: Path, img: str):
    """Every Dockerfile must declare USER 1001 (non-root UID)."""
    text = (images_dir / img / "Dockerfile").read_text()
    assert re.search(r"^USER\s+1001(:0)?", text, re.MULTILINE), \
        f"{img}/Dockerfile must contain 'USER 1001:0'"


@pytest.mark.unit
@pytest.mark.parametrize("img", IMAGES)
def test_dockerfile_uses_tini(images_dir: Path, img: str):
    """tini must be PID 1 (except mariadb which inherits the upstream image)."""
    if img == "mariadb":
        pytest.skip("mariadb inherits docker-entrypoint.sh from the upstream image")
    text = (images_dir / img / "Dockerfile").read_text()
    assert "tini" in text, f"{img}/Dockerfile must use tini as PID 1"
    assert re.search(r'ENTRYPOINT\s*\[\s*"/usr/bin/tini"', text), \
        f"{img}/Dockerfile ENTRYPOINT must invoke tini"


@pytest.mark.unit
@pytest.mark.parametrize("img", IMAGES)
def test_dockerfile_has_healthcheck_directive(images_dir: Path, img: str):
    text = (images_dir / img / "Dockerfile").read_text()
    assert re.search(r"^HEALTHCHECK", text, re.MULTILINE), \
        f"{img}/Dockerfile must declare HEALTHCHECK"


@pytest.mark.unit
@pytest.mark.parametrize("img", IMAGES)
def test_entrypoint_uses_strict_mode(images_dir: Path, img: str):
    if img == "mariadb":
        pytest.skip("mariadb uses upstream docker-entrypoint.sh")
    text = (images_dir / img / "entrypoint.sh").read_text()
    assert "set -euo pipefail" in text, \
        f"{img}/entrypoint.sh must enable strict mode"


@pytest.mark.unit
@pytest.mark.parametrize("img", IMAGES)
def test_hadolint(images_dir: Path, img: str):
    """Run hadolint when available, skip otherwise."""
    if not shutil.which("hadolint"):
        pytest.skip("hadolint not installed")
    res = subprocess.run(
        ["hadolint", "--no-fail", str(images_dir / img / "Dockerfile")],
        capture_output=True, text=True,
    )
    # Warnings are accepted but not fatal errors (DL3000+).
    fatals = [l for l in res.stdout.splitlines() if " error " in l.lower()]
    assert not fatals, f"hadolint errors for {img}:\n{res.stdout}"
