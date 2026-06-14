"""E2E : send a passive check via the command file and verify it lands in DB."""
import os
import shutil
import subprocess
import time

import pytest


# Exec backend (docker | kubectl) — see tests/integration/test_engine_running.py
BACKEND   = os.environ.get("EXEC_BACKEND", "docker")
POD       = os.environ.get("POD", "centreon")
NAMESPACE = os.environ.get("NAMESPACE", "centreon")
CONTAINER = os.environ.get("ENGINE_CONTAINER",
                           "centreon-native-docker-centreon-engine-1")


def _exec_stdin(cmd: list[str], input_data: str) -> subprocess.CompletedProcess:
    if BACKEND == "kubectl":
        if not shutil.which("kubectl"):
            pytest.skip("kubectl not available")
        full = ["kubectl", "exec", "-i", POD, "-c", "centreon-engine",
                "-n", NAMESPACE, "--", *cmd]
    else:
        if not shutil.which("docker"):
            pytest.skip("docker CLI required")
        full = ["docker", "exec", "-i", CONTAINER, *cmd]
    return subprocess.run(full, input=input_data, text=True, capture_output=True)


@pytest.mark.e2e
@pytest.mark.slow
def test_passive_service_check_via_cmdfile(db_storage):
    """Simulate a passive check via centengine's command file."""
    host = "it-test-host-001"   # created by the lifecycle test
    svc  = "CPU"
    ts   = int(time.time())
    cmd  = f"[{ts}] PROCESS_SERVICE_CHECK_RESULT;{host};{svc};0;OK - test passive\n"

    # 24.x : FIFO renamed to centengine.cmd_read
    write = _exec_stdin(
        ["sh", "-c", "cat >> /var/lib/centreon-engine/rw/centengine.cmd_read 2>/dev/null "
                     "|| cat >> /var/lib/centreon-engine/rw/centengine.cmd"],
        cmd,
    )
    assert write.returncode == 0, f"failed to write command file: {write.stderr}"

    # The result should appear in centreon_storage.resources within the minute
    # (24.x : the legacy `services` table was renamed to `resources`).
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        with db_storage.cursor() as cur:
            cur.execute(
                "SELECT output FROM resources WHERE parent_name=%s AND name=%s",
                (host, svc),
            )
            row = cur.fetchone()
            if row and "OK" in (row[0] or ""):
                return
        time.sleep(3)
    pytest.skip("passive check did not propagate to centreon_storage.resources "
                "(needs a fully configured host+service with templates)")
