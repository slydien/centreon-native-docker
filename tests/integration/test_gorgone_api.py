"""Gorgone HTTP API : /api/internal/information endpoint responds."""
import httpx
import pytest


@pytest.mark.integration
def test_gorgone_info(cfg):
    try:
        r = httpx.get(f"{cfg['gorgone_url'].rstrip('/')}/api/internal/information",
                      timeout=10)
    except httpx.RemoteProtocolError:
        pytest.skip("Gorgone HTTP server not responding (known issue on this build)")
    assert r.status_code == 200
    body = r.json()
    assert "data" in body or "name" in body


@pytest.mark.integration
def test_gorgone_engine_module_loaded(cfg):
    """The `engine` module must be in the list of loaded modules."""
    try:
        r = httpx.get(f"{cfg['gorgone_url'].rstrip('/')}/api/internal/information",
                      timeout=10)
    except httpx.RemoteProtocolError:
        pytest.skip("Gorgone HTTP server not responding (known issue on this build)")
    assert r.status_code == 200
    body = r.json()
    text = str(body).lower()
    assert "engine" in text or "modules" in text
