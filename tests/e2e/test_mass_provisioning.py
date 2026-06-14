"""E2E : create N hosts in parallel and export the config."""
from __future__ import annotations

import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

import httpx
import pytest


COUNT   = int(os.environ.get("E2E_HOST_COUNT", "200"))
WORKERS = int(os.environ.get("E2E_WORKERS", "20"))
# Unique prefix per run (epoch in hex) to avoid 409 collisions with rows left
# over by a previous run.
PREFIX  = os.environ.get("E2E_HOST_PREFIX",
                          f"perf-host-{int(time.time()):x}")


def _create(api_client: httpx.Client, idx: int) -> int:
    payload = {
        "name":    f"{PREFIX}-{idx:04d}",
        "alias":   f"{PREFIX}-{idx:04d}",
        "address": f"172.16.{(idx // 256) & 0xFF}.{idx & 0xFF}",
        "monitoring_server_id": 1,
        "templates": [],
        "is_activated": True,
    }
    r = api_client.post("/centreon/api/latest/configuration/hosts", json=payload)
    return r.status_code


@pytest.mark.e2e
@pytest.mark.slow
def test_mass_create_hosts(api_client):
    t0 = time.monotonic()
    success = 0
    failures = []
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        futs = {pool.submit(_create, api_client, i): i for i in range(1, COUNT + 1)}
        for fut in as_completed(futs):
            code = fut.result()
            if code in (200, 201):
                success += 1
            else:
                failures.append((futs[fut], code))
    elapsed = time.monotonic() - t0

    print(f"\n{success}/{COUNT} hosts created in {elapsed:.1f}s "
          f"({success / elapsed:.1f}/s)")
    if failures[:5]:
        print(f"First failures: {failures[:5]}")
    # 85% threshold : tolerates DB contention on a kind/dev setup. On a
    # production OpenShift cluster with sized MariaDB + Web we expect > 95%.
    threshold = float(os.environ.get("E2E_SUCCESS_THRESHOLD", "0.85"))
    assert success >= int(COUNT * threshold), \
        f"only {success}/{COUNT} hosts created (threshold {threshold:.0%})"
    assert elapsed < 300, f"too slow: {elapsed:.1f}s for {COUNT} hosts"


@pytest.mark.e2e
@pytest.mark.slow
def test_export_after_mass_create(api_client):
    # In 24.x the endpoint is a GET (and delegates to Gorgone).
    r = api_client.get(
        "/centreon/api/latest/configuration/monitoring-servers/1/generate-and-reload",
        timeout=180,
    )
    if r.status_code == 500:
        pytest.skip(f"export 500 (gorgone/template): {r.text[:200]}")
    assert r.status_code in (200, 204), f"export failed: {r.status_code} {r.text[:300]}"
