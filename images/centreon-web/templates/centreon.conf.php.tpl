<?php
//
// /etc/centreon/centreon.conf.php — rendered by the entrypoint from the environment
//
$conf_centreon = array();
$conf_centreon['hostCentreon']        = '${CENTREON_DB_HOST}';
$conf_centreon['hostCentstorage']     = '${CENTREON_DB_HOST}';
$conf_centreon['port']                = '${CENTREON_DB_PORT}';
$conf_centreon['user']                = '${CENTREON_DB_USER}';
$conf_centreon['password']            = '${CENTREON_DB_PASS}';
$conf_centreon['db']                  = '${CENTREON_DB_NAME}';
$conf_centreon['dbcstg']              = '${CENTREON_STORAGE_DB_NAME}';
$conf_centreon['type']                = 'mysql';

// Paths (match the Centreon RPMs)
$centreon_path                        = '/usr/share/centreon/';

// Gorgone — local HTTP API
$conf_centreon['gorgone_endpoint']    = 'http://${GORGONE_HOST}:${GORGONE_HTTP_PORT}';
