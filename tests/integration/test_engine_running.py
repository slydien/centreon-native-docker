"""centreon-engine : process alive + command file accessible.

Supports two exec backends :
  - docker-compose : `EXEC_BACKEND=docker` (default) + container name
  - Kubernetes/kind: `EXEC_BACKEND=kubectl POD=centreon NAMESPACE=centreon`
"""
import os
import shutil
import subprocess

import pytest


BACKEND   = os.environ.get("EXEC_BACKEND", "docker")
POD       = os.environ.get("POD", "centreon")
NAMESPACE = os.environ.get("NAMESPACE", "centreon")
CONTAINER         = os.environ.get("ENGINE_CONTAINER",
                                   "centreon-native-docker-centreon-engine-1")
GORGONE_CONTAINER = os.environ.get("GORGONE_CONTAINER",
                                   "centreon-native-docker-centreon-gorgone-1")


def _exec(container_role: str, cmd: list[str]) -> subprocess.CompletedProcess:
    """Exec in the right container based on the backend."""
    if BACKEND == "kubectl":
        # On k8s : `container_role` is the container name inside the pod
        # (centreon-engine, centreon-gorgone, ...).
        if not shutil.which("kubectl"):
            pytest.skip("kubectl not available locally — set KUBECONFIG or use DOCKER_HOST")
        return subprocess.run(
            ["kubectl", "exec", POD, "-c", container_role, "-n", NAMESPACE, "--", *cmd],
            capture_output=True, text=True,
        )
    # docker-compose : container_role is mapped to the full container name
    name = CONTAINER if container_role == "centreon-engine" else GORGONE_CONTAINER
    if not shutil.which("docker"):
        pytest.skip("docker CLI not available")
    return subprocess.run(
        ["docker", "exec", name, *cmd],
        capture_output=True, text=True,
    )


def _docker_exec(cmd: list[str]) -> subprocess.CompletedProcess:
    return _exec("centreon-engine", cmd)


@pytest.mark.integration
def test_centengine_process_present():
    r = _docker_exec(["pgrep", "-x", "centengine"])
    assert r.returncode == 0, f"centengine not running:\n{r.stderr}"


@pytest.mark.integration
def test_command_file_exists():
    # 24.x : the FIFO is named `centengine.cmd_read` (with the `_read` suffix).
    r = _docker_exec(["sh", "-c",
        "ls /var/lib/centreon-engine/rw/centengine.cmd "
        "|| ls /var/lib/centreon-engine/rw/centengine.cmd_read"])
    assert r.returncode == 0, f"command file missing:\n{r.stderr}"


@pytest.mark.integration
def test_engine_config_directory_writable_from_gorgone():
    """The /etc/centreon-engine volume must be writable from gorgone."""
    r = _exec("centreon-gorgone", ["touch", "/etc/centreon-engine/.write-test"])
    assert r.returncode == 0, f"gorgone cannot write to /etc/centreon-engine:\n{r.stderr}"
    _exec("centreon-gorgone", ["rm", "-f", "/etc/centreon-engine/.write-test"])
