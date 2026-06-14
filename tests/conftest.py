"""
Shared fixtures for the unit / integration / e2e test tiers.
"""
from __future__ import annotations

import os
import time
from pathlib import Path

import httpx
import pymysql
import pytest


ROOT = Path(__file__).resolve().parent.parent


# ---------------------------------------------------------------------------
# Central config (env-driven)
# ---------------------------------------------------------------------------
@pytest.fixture(scope="session")
def cfg() -> dict:
    return {
        "base_url":    os.environ.get("CENTREON_URL",        "http://localhost:8080"),
        "gorgone_url": os.environ.get("GORGONE_URL",         "http://localhost:8085"),
        "user":        os.environ.get("CENTREON_ADMIN_USER", "admin"),
        "password":    os.environ.get("CENTREON_ADMIN_PASS", "admin"),
        "db_host":     os.environ.get("MARIADB_HOST",        "127.0.0.1"),
        "db_port":     int(os.environ.get("MARIADB_PORT",    "3306")),
        "db_user":     os.environ.get("CENTREON_DB_USER",    "centreon"),
        "db_pass":     os.environ.get("CENTREON_DB_PASS",    "centreon"),
        "db_centreon":         os.environ.get("CENTREON_DB_NAME",         "centreon"),
        "db_centreon_storage": os.environ.get("CENTREON_STORAGE_DB_NAME", "centreon_storage"),
    }


# ---------------------------------------------------------------------------
# Centreon auth token (session-scoped)
# ---------------------------------------------------------------------------
@pytest.fixture(scope="session")
def auth_token(cfg) -> str:
    base = cfg["base_url"].rstrip("/")
    for attempt in range(60):
        try:
            r = httpx.post(
                f"{base}/centreon/api/latest/login",
                json={"security": {"credentials": {
                    "login":    cfg["user"],
                    "password": cfg["password"],
                }}},
                timeout=10,
            )
            if r.status_code == 200:
                return r.json()["security"]["token"]
        except httpx.HTTPError:
            pass
        time.sleep(5)
    pytest.skip("centreon-web not reachable after 5 minutes")


@pytest.fixture(scope="session")
def api_client(cfg, auth_token) -> httpx.Client:
    return httpx.Client(
        base_url=cfg["base_url"].rstrip("/"),
        headers={"X-AUTH-TOKEN": auth_token, "Content-Type": "application/json"},
        timeout=15,
    )


# ---------------------------------------------------------------------------
# MariaDB connections
# ---------------------------------------------------------------------------
@pytest.fixture(scope="session")
def db_centreon(cfg):
    conn = pymysql.connect(
        host=cfg["db_host"], port=cfg["db_port"],
        user=cfg["db_user"], password=cfg["db_pass"],
        database=cfg["db_centreon"], autocommit=True,
    )
    yield conn
    conn.close()


@pytest.fixture(scope="session")
def db_storage(cfg):
    conn = pymysql.connect(
        host=cfg["db_host"], port=cfg["db_port"],
        user=cfg["db_user"], password=cfg["db_pass"],
        database=cfg["db_centreon_storage"], autocommit=True,
    )
    yield conn
    conn.close()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
@pytest.fixture(scope="session")
def project_root() -> Path:
    return ROOT
