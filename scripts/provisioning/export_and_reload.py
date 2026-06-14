#!/usr/bin/env python3
"""
Export configuration to the pollers + reload centengine.

Two code paths :
  - via the centreon-web REST API v2 :
        GET /configuration/monitoring-servers/{id}/generate-and-reload
  - via Gorgone directly (fallback or test) :
        POST http://gorgone:8085/api/centreon/engine/command  RESTART

Usage :
    python export_and_reload.py --poller 1
    python export_and_reload.py --poller 1 --via gorgone
"""
from __future__ import annotations

import argparse
import os
import sys
import time

import httpx


def via_web_api(base_url: str, user: str, password: str, poller_id: int, timeout: float) -> int:
    # 1) auth
    r = httpx.post(
        f"{base_url}/centreon/api/latest/login",
        json={"security": {"credentials": {"login": user, "password": password}}},
        timeout=timeout,
    )
    r.raise_for_status()
    token = r.json()["security"]["token"]
    headers = {"X-AUTH-TOKEN": token, "Content-Type": "application/json"}

    # 2) generate-and-reload (Centreon 24.10 : GET on the per-poller path)
    print(f"[web-api] generate-and-reload poller {poller_id}")
    r = httpx.get(
        f"{base_url}/centreon/api/latest/configuration/monitoring-servers/{poller_id}/generate-and-reload",
        headers=headers,
        timeout=timeout,
    )
    r.raise_for_status()
    print(f"[web-api] OK (HTTP {r.status_code})")
    return 0


def via_gorgone(gorgone_url: str, poller_id: int, timeout: float) -> int:
    # Step 1 : export
    print(f"[gorgone] export configuration poller={poller_id}")
    r = httpx.post(
        f"{gorgone_url}/api/centreon/engine/command",
        json={"command": "EXPORTCONFIGURATION", "parameters": {"poller_id": poller_id}},
        timeout=timeout,
    )
    r.raise_for_status()
    token = r.json().get("token")
    print(f"[gorgone] export token={token}")

    # Step 2 : wait until completion via /api/log/<token>
    for _ in range(30):
        time.sleep(2)
        status = httpx.get(f"{gorgone_url}/api/log/{token}", timeout=timeout).json()
        data = status.get("data") or []
        if data and data[-1].get("code") == 0:
            print(f"[gorgone] export finished")
            break
    else:
        print("[gorgone] export timeout", file=sys.stderr)
        return 1

    # Step 3 : reload
    print(f"[gorgone] reload engine on poller {poller_id}")
    r = httpx.post(
        f"{gorgone_url}/api/centreon/engine/command",
        json={"command": "RELOAD", "parameters": {"poller_id": poller_id}},
        timeout=timeout,
    )
    r.raise_for_status()
    print("[gorgone] reload triggered")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description="Export + reload Centreon configuration")
    p.add_argument("--via", choices=["web", "gorgone"], default="web")
    p.add_argument("--base-url",    default=os.environ.get("CENTREON_URL", "http://localhost:8080"))
    p.add_argument("--gorgone-url", default=os.environ.get("GORGONE_URL", "http://localhost:8085"))
    p.add_argument("--user",        default=os.environ.get("CENTREON_ADMIN_USER", "admin"))
    p.add_argument("--password",    default=os.environ.get("CENTREON_ADMIN_PASS", "admin"))
    p.add_argument("--poller",      type=int, default=1)
    p.add_argument("--timeout",     type=float, default=60.0)
    args = p.parse_args()

    if args.via == "web":
        return via_web_api(args.base_url.rstrip("/"), args.user, args.password,
                           args.poller, args.timeout)
    return via_gorgone(args.gorgone_url.rstrip("/"), args.poller, args.timeout)


if __name__ == "__main__":
    sys.exit(main())
