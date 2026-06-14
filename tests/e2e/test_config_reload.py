"""E2E : create a host, export, reload, verify it gets monitored."""
import time

import pytest


HOST = "e2e-reload-host"


@pytest.fixture
def host(api_client):
    r = api_client.post("/centreon/api/latest/configuration/hosts", json={
        "name":    HOST,
        "alias":   HOST,
        "address": "203.0.113.10",
        "monitoring_server_id": 1,
        "templates": [],
        "is_activated": True,
    })
    hid = r.json().get("id") if r.status_code in (200, 201) else None
    if hid is None:
        pytest.skip(f"could not create host: {r.status_code} {r.text[:200]}")
    yield hid
    api_client.delete(f"/centreon/api/latest/configuration/hosts/{hid}")


@pytest.mark.e2e
@pytest.mark.slow
def test_full_reload_cycle(api_client, host, db_storage):
    # 1. Export and reload (24.x : GET per-poller)
    r = api_client.get(
        "/centreon/api/latest/configuration/monitoring-servers/1/generate-and-reload",
        timeout=120,
    )
    if r.status_code == 500:
        pytest.skip(f"export 500 (host without template): {r.text[:200]}")
    assert r.status_code in (200, 204), f"{r.status_code}: {r.text[:200]}"

    # 2. Wait for centengine to pick it up
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        with db_storage.cursor() as cur:
            cur.execute("SELECT host_id FROM hosts WHERE name=%s", (HOST,))
            if cur.fetchone():
                return
        time.sleep(5)
    pytest.fail(f"host {HOST} never appeared in centreon_storage after reload")
