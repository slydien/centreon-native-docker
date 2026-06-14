#!/usr/bin/env python3
"""
Mass provisioning via CLAPI (Centreon Legacy API).

Runs the `centreon` CLI inside the centreon-web container to create N hosts
+ their services. Slower than the REST API v2 but does not depend on the
new API (useful for older versions or when the API is down).

Usage:
    python mass_create_clapi.py --count 500 --start 1 --template generic-host
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from typing import Iterable


def run_clapi(user: str, password: str, args: list[str]) -> None:
    cmd = ["centreon", "-u", user, "-p", password, *args]
    subprocess.run(cmd, check=True, capture_output=True, text=True)


def create_host(user: str, pwd: str, name: str, ip: str, template: str, instance: str) -> None:
    run_clapi(user, pwd, [
        "-o", "HOST", "-a", "ADD",
        "-v", f"{name};{name};{ip};{template};{instance};Linux",
    ])


def create_service(user: str, pwd: str, host: str, svc: str, template: str) -> None:
    run_clapi(user, pwd, [
        "-o", "SERVICE", "-a", "ADD",
        "-v", f"{host};{svc};{template}",
    ])


def iter_targets(start: int, count: int) -> Iterable[tuple[str, str]]:
    for i in range(start, start + count):
        yield f"host-{i:04d}", f"192.168.{i // 256}.{i % 256}"


def main() -> int:
    p = argparse.ArgumentParser(description="Mass create hosts/services via CLAPI")
    p.add_argument("--user",     default="admin")
    p.add_argument("--password", default="admin")
    p.add_argument("--count",    type=int, default=500)
    p.add_argument("--start",    type=int, default=1)
    p.add_argument("--host-template",    default="generic-host")
    p.add_argument("--service-template", default="generic-service")
    p.add_argument("--instance",         default="Central")
    p.add_argument("--services", nargs="*", default=["CPU", "Memory", "Disk"])
    args = p.parse_args()

    created = failed = 0
    for name, ip in iter_targets(args.start, args.count):
        try:
            create_host(args.user, args.password, name, ip, args.host_template, args.instance)
            for svc in args.services:
                create_service(args.user, args.password, name, svc, args.service_template)
            created += 1
            if created % 50 == 0:
                print(f"  progress: {created}/{args.count} hosts")
        except subprocess.CalledProcessError as exc:
            failed += 1
            print(f"  FAIL {name}: {exc.stderr.strip()}", file=sys.stderr)

    print(f"\nDone: {created} hosts created, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
