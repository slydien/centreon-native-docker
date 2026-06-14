{
  "centreonBroker": {
    "broker_id": 100,
    "broker_name": "central-module-master",
    "poller_id": 1,
    "poller_name": "${CENTREON_INSTANCE_NAME}",
    "module_directory": "/usr/share/centreon/lib/centreon-broker",
    "bbdo_version": "3.0.0",
    "log_timestamp": true,
    "command_file": "/var/lib/centreon-broker/command-module.sock",
    "cache_directory": "/var/lib/centreon-broker",

    "log": {
      "directory": "/var/log/centreon-broker",
      "filename":  "",
      "max_size": 0,
      "loggers": {
        "core": "info", "tcp": "info", "bbdo": "info",
        "config": "info", "processing": "info", "neb": "info"
      }
    },

    "output": [
      {
        "name": "central-module-master-output",
        "port": "${BROKER_BBDO_PORT}",
        "host": "${BROKER_SQL_HOST}",
        "protocol": "bbdo",
        "tls": "no",
        "negotiation": "yes",
        "one_peer_retention_mode": "no",
        "compression": "auto",
        "retry_interval": "60",
        "buffering_timeout": "0",
        "type": "ipv4"
      }
    ]
  }
}
