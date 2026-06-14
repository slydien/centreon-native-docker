"""envsubst templating tests : every template must render valid content."""
from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

import pytest
import yaml


@pytest.fixture
def env(monkeypatch):
    """Minimal env required to render the templates."""
    env = {
        # Engine
        "CENTREON_ENGINE_CFGDIR": "/etc/centreon-engine",
        "CENTREON_ENGINE_VARDIR": "/var/lib/centreon-engine",
        "CENTREON_ENGINE_LOGDIR": "/var/log/centreon-engine",
        # Broker
        "BROKER_DB_HOST": "127.0.0.1",
        "BROKER_DB_PORT": "3306",
        "BROKER_DB_USER": "centreon",
        "BROKER_DB_PASS": "secret",
        "BROKER_DB_NAME": "centreon",
        "BROKER_STORAGE_DB_NAME": "centreon_storage",
        "BROKER_BBDO_PORT": "5669",
        "BROKER_RRD_HOST": "127.0.0.1",
        "BROKER_RRD_PORT": "5670",
        "BROKER_LOGDIR": "/var/log/centreon-broker",
        "BROKER_VARDIR": "/var/lib/centreon-broker",
        "RRD_METRICS_DIR": "/var/lib/centreon/metrics",
        "RRD_STATUS_DIR": "/var/lib/centreon/status",
        # Gorgone
        "CENTREON_DB_HOST": "127.0.0.1",
        "CENTREON_DB_PORT": "3306",
        "CENTREON_DB_USER": "centreon",
        "CENTREON_DB_PASS": "secret",
        "CENTREON_DB_NAME": "centreon",
        "CENTREON_STORAGE_DB_NAME": "centreon_storage",
        "GORGONE_HTTP_PORT": "8085",
        "GORGONE_ZMQ_PORT": "5556",
        "GORGONE_ID": "1",
        "GORGONE_VARDIR": "/var/lib/centreon-gorgone",
        "GORGONE_LOGDIR": "/var/log/centreon-gorgone",
        "ENGINE_CMDFILE": "/var/lib/centreon-engine/rw/centengine.cmd",
        "ENGINE_CFGDIR":  "/etc/centreon-engine",
        # Web
        "CENTREON_ADMIN_USER": "admin",
        "CENTREON_ADMIN_PASS": "admin",
        "CENTREON_INSTANCE_NAME": "Central",
        "GORGONE_HOST": "127.0.0.1",
    }
    for k, v in env.items():
        monkeypatch.setenv(k, v)
    return env


def _envsubst(tpl: Path) -> str:
    return subprocess.check_output(["envsubst"], stdin=open(tpl), text=True)


@pytest.mark.unit
def test_broker_sql_template_is_valid_json(env, project_root: Path):
    tpl = project_root / "images/centreon-broker-sql/templates/central-broker.json.tpl"
    out = _envsubst(tpl)
    data = json.loads(out)
    assert data["centreonBroker"]["broker_name"] == "central-broker-sql"
    assert data["centreonBroker"]["bbdo_version"] == "3.0.0"
    # Substitutions applied
    assert "${BROKER_DB_HOST}" not in out
    # BBDO 3.0 : single `unified_sql` output (replaces legacy `sql` + `storage`)
    sql_output = next(o for o in data["centreonBroker"]["output"] if o["type"] == "unified_sql")
    assert sql_output["db_host"] == "127.0.0.1"
    # Input listener : no `host` field (cbd treats absence as "listen mode")
    assert "host" not in data["centreonBroker"]["input"][0]


@pytest.mark.unit
def test_broker_rrd_template_is_valid_json(env, project_root: Path):
    tpl = project_root / "images/centreon-broker-rrd/templates/central-rrd.json.tpl"
    data = json.loads(_envsubst(tpl))
    rrd_out = next(o for o in data["centreonBroker"]["output"] if o["type"] == "rrd")
    assert rrd_out["metrics_path"] == "/var/lib/centreon/metrics"


@pytest.mark.unit
def test_gorgone_template_is_valid_yaml(env, project_root: Path):
    tpl = project_root / "images/centreon-gorgone/templates/config.yaml.tpl"
    out = _envsubst(tpl)
    data = yaml.safe_load(out)
    # The template is a fragment dropped into /etc/centreon-gorgone/config.d/
    # (top-level keys : `centreon` and `gorgone`).
    assert "centreon" in data and "gorgone" in data
    mods = {m["name"] for m in data["gorgone"]["modules"]}
    assert {"httpserver", "engine", "legacycmd", "cron"} <= mods


@pytest.mark.unit
def test_engine_template_renders(env, project_root: Path):
    tpl = project_root / "images/centreon-engine/templates/centengine.cfg.tpl"
    out = _envsubst(tpl)
    assert "command_file=/var/lib/centreon-engine/rw/centengine.cmd" in out
    assert "${" not in out  # every variable substituted


@pytest.mark.unit
def test_web_php_template_renders(env, project_root: Path):
    tpl = project_root / "images/centreon-web/templates/centreon.conf.php.tpl"
    out = _envsubst(tpl)
    assert "127.0.0.1" in out
    assert "centreon" in out
    assert "${" not in out


@pytest.mark.unit
def test_envsubst_available():
    """envsubst must be available (it's used by every entrypoint)."""
    assert subprocess.run(["envsubst", "--version"], capture_output=True).returncode == 0
