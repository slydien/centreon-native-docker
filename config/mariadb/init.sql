-- Bitnami's entrypoint creates the `centreon` DB and user from
-- MARIADB_DATABASE / MARIADB_USER / MARIADB_PASSWORD. We only need to
-- add the second Centreon DB (`centreon_storage`) and grant the same
-- user access to it.
CREATE DATABASE IF NOT EXISTS centreon_storage
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON centreon_storage.* TO 'centreon'@'%';
FLUSH PRIVILEGES;
