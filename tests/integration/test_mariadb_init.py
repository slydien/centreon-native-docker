"""The MariaDB container must have created the schemas and the centreon user."""
import pytest


@pytest.mark.integration
def test_centreon_database_exists(db_centreon):
    with db_centreon.cursor() as cur:
        cur.execute("SELECT DATABASE()")
        assert cur.fetchone()[0] == "centreon"


@pytest.mark.integration
def test_storage_database_exists(db_storage):
    with db_storage.cursor() as cur:
        cur.execute("SELECT DATABASE()")
        assert cur.fetchone()[0] == "centreon_storage"


@pytest.mark.integration
def test_centreon_schema_imported(db_centreon):
    """centreon.contact and centreon.host must exist (schema imported either
    by initdb or by the web entrypoint)."""
    with db_centreon.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) FROM information_schema.tables "
            "WHERE table_schema='centreon' "
            "  AND table_name IN ('contact','host','service','nagios_server')"
        )
        count = cur.fetchone()[0]
        assert count >= 3, f"expected >= 3 core Centreon tables, found {count}"


@pytest.mark.integration
def test_admin_user_exists(db_centreon):
    with db_centreon.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM contact WHERE contact_alias='admin'")
        assert cur.fetchone()[0] == 1
