{
  "centreonBroker": {
    "broker_id": 1,
    "broker_name": "central-broker-sql",
    "poller_id": 1,
    "poller_name": "Central",
    "module_directory": "/usr/share/centreon/lib/centreon-broker",
    "bbdo_version": "3.0.0",
    "log_timestamp": true,
    "log_thread_id": false,
    "event_queue_max_size": 100000,
    "command_file": "${BROKER_VARDIR}/command.sock",
    "cache_directory": "${BROKER_VARDIR}",

    "log": {
      "directory": "${BROKER_LOGDIR}",
      "filename": "",
      "max_size": 0,
      "loggers": {
        "core":       "info",
        "config":     "info",
        "sql":        "info",
        "tcp":        "info",
        "bbdo":       "info",
        "processing": "info",
        "perfdata":   "info",
        "tls":        "error",
        "lua":        "error",
        "bam":        "error",
        "neb":        "info"
      }
    },

    "input": [
      {
        "name": "central-broker-master-input",
        "port": "${BROKER_BBDO_PORT}",
        "protocol": "bbdo",
        "tls": "no",
        "negotiation": "yes",
        "one_peer_retention_mode": "no",
        "compression": "no",
        "retry_interval": "10",
        "buffering_timeout": "0",
        "type": "ipv4"
      }
    ],

    "output": [
      {
        "name": "central-broker-master-unified-sql",
        "db_type": "mysql",
        "db_host": "${BROKER_DB_HOST}",
        "db_port": "${BROKER_DB_PORT}",
        "db_user": "${BROKER_DB_USER}",
        "db_password": "${BROKER_DB_PASS}",
        "db_name": "${BROKER_STORAGE_DB_NAME}",
        "queries_per_transaction": "1000",
        "connections_count": "3",
        "read_timeout": "1",
        "buffering_timeout": "0",
        "retry_interval": "60",
        "interval": "60",
        "length": "15552000",
        "store_in_resources": "yes",
        "store_in_hosts_services": "yes",
        "check_replication": "no",
        "type": "unified_sql"
      },
      {
        "name": "centreon-broker-master-rrd",
        "port": "${BROKER_RRD_PORT}",
        "host": "${BROKER_RRD_HOST}",
        "protocol": "bbdo",
        "tls": "no",
        "negotiation": "yes",
        "one_peer_retention_mode": "no",
        "compression": "auto",
        "retry_interval": "60",
        "buffering_timeout": "0",
        "type": "ipv4"
      }
    ],

    "grpc": {
      "port": 51001
    }
  }
}
