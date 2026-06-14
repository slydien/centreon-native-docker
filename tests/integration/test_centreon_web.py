"""centreon-web : login + API endpoints return 200."""
import httpx
import pytest


@pytest.mark.integration
def test_installation_status(cfg):
    """Public endpoint : confirms Symfony + DB bootstrap cleanly."""
    base = cfg["base_url"].rstrip("/")
    r = httpx.get(f"{base}/centreon/api/latest/platform/installation/status", timeout=10)
    assert r.status_code == 200, f"{r.status_code}: {r.text[:200]}"
    assert r.json()["is_installed"] is True


@pytest.mark.integration
def test_login_returns_token(auth_token):
    assert auth_token
    assert isinstance(auth_token, str)
    assert len(auth_token) > 10


@pytest.mark.integration
def test_authenticated_api_call(api_client):
    """Once logged in, we can call an auth-protected endpoint."""
    r = api_client.get("/centreon/api/latest/configuration/hosts")
    assert r.status_code == 200, f"{r.status_code}: {r.text[:200]}"
    body = r.json()
    assert "result" in body and "meta" in body
