#!/usr/bin/env python3
"""
Mass provisioning via the REST API v2 (Centreon >= 22.10).

Creates N hosts + services in parallel via httpx.

Usage :
    python mass_create_api.py --count 500 --workers 20
    python mass_create_api.py --count 500 --workers 20 \
        --base-url http://centreon.apps.example.com
"""
from __future__ import annotations

import argparse
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass

import httpx


@dataclass
class Config:
    base_url:    str
    user:        str
    password:    str
    host_tpl_id: int
    svc_tpls:    list[tuple[str, int]]   # (service name, template_id)
    poller_id:   int
    count:       int
    start:       int
    workers:     int
    timeout:     float


def auth(cfg: Config) -> str:
    r = httpx.post(
        f"{cfg.base_url}/centreon/api/latest/login",
        json={"security": {"credentials": {"login": cfg.user, "password": cfg.password}}},
        timeout=cfg.timeout,
    )
    r.raise_for_status()
    return r.json()["security"]["token"]


def create_host(client: httpx.Client, cfg: Config, idx: int) -> tuple[int, str | None]:
    name = f"host-{idx:04d}"
    address = f"10.{(idx // 65536) & 0xFF}.{(idx // 256) & 0xFF}.{idx & 0xFF}"
    payload = {
        "name": name,
        "alias": name,
        "address": address,
        "monitoring_server_id": cfg.poller_id,
        "templates": [cfg.host_tpl_id],
        "is_activated": True,
    }
    r = client.post("/centreon/api/latest/configuration/hosts", json=payload)
    if r.status_code in (200, 201):
        host_id = r.json().get("id")
        for svc_name, tpl_id in cfg.svc_tpls:
            svc_payload = {
                "host_id":             host_id,
                "name":                svc_name,
                "service_template_id": tpl_id,
            }
            client.post("/centreon/api/latest/configuration/services", json=svc_payload)
        return idx, None
    return idx, f"HTTP {r.status_code}: {r.text[:200]}"


def main() -> int:
    p = argparse.ArgumentParser(description="Mass create hosts/services via REST API")
    p.add_argument("--base-url", default=os.environ.get("CENTREON_URL", "http://localhost:8080"))
    p.add_argument("--user",     default=os.environ.get("CENTREON_ADMIN_USER", "admin"))
    p.add_argument("--password", default=os.environ.get("CENTREON_ADMIN_PASS", "admin"))
    p.add_argument("--count",    type=int, default=500)
    p.add_argument("--start",    type=int, default=1)
    p.add_argument("--workers",  type=int, default=20)
    p.add_argument("--host-template-id",    type=int, default=2)
    p.add_argument("--service-template-id", type=int, default=1)
    p.add_argument("--service-names", nargs="*", default=["CPU", "Memory", "Disk"])
    p.add_argument("--poller-id", type=int, default=1)
    p.add_argument("--timeout",   type=float, default=15.0)
    args = p.parse_args()

    cfg = Config(
        base_url=args.base_url.rstrip("/"),
        user=args.user,
        password=args.password,
        host_tpl_id=args.host_template_id,
        svc_tpls=[(n, args.service_template_id) for n in args.service_names],
        poller_id=args.poller_id,
        count=args.count,
        start=args.start,
        workers=args.workers,
        timeout=args.timeout,
    )

    print(f"Authenticating against {cfg.base_url}")
    token = auth(cfg)

    headers = {"X-AUTH-TOKEN": token, "Content-Type": "application/json"}
    indices = list(range(cfg.start, cfg.start + cfg.count))
    succ = err = 0
    failures: list[tuple[int, str]] = []
    t0 = time.monotonic()

    with httpx.Client(base_url=cfg.base_url, headers=headers, timeout=cfg.timeout) as client:
        with ThreadPoolExecutor(max_workers=cfg.workers) as pool:
            futures = {pool.submit(create_host, client, cfg, i): i for i in indices}
            for fut in as_completed(futures):
                idx, err_msg = fut.result()
                if err_msg is None:
                    succ += 1
                else:
                    err += 1
                    failures.append((idx, err_msg))
                if (succ + err) % 50 == 0:
                    print(f"  progress: {succ + err}/{cfg.count} ({succ} ok, {err} err)")

    elapsed = time.monotonic() - t0
    print(f"\nDone in {elapsed:.1f}s — {succ} ok, {err} err "
          f"({succ / elapsed:.1f} hosts/s)")
    if failures:
        print("First 10 failures:")
        for idx, msg in failures[:10]:
            print(f"  host-{idx:04d}: {msg}")
    return 0 if err == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
