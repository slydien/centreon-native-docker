{
  "centreonBroker": {
    "broker_id": 2,
    "broker_name": "central-rrd-master",
    "poller_id": 1,
    "poller_name": "Central",
    "module_directory": "/usr/share/centreon/lib/centreon-broker",
    "bbdo_version": "3.0.0",
    "log_timestamp": true,
    "event_queue_max_size": 100000,
    "command_file": "${BROKER_VARDIR}/command-rrd.sock",
    "cache_directory": "${BROKER_VARDIR}",

    "log": {
      "directory": "${BROKER_LOGDIR}",
      "filename": "",
      "max_size": 0,
      "loggers": {
        "core":   "info",
        "config": "info",
        "tcp":    "info",
        "bbdo":   "info",
        "rrd":    "info"
      }
    },

    "input": [
      {
        "name": "central-rrd-master-input",
        "port": "${BROKER_RRD_PORT}",
        "protocol": "bbdo",
        "tls": "no",
        "negotiation": "yes",
        "one_peer_retention_mode": "no",
        "compression": "auto",
        "retry_interval": "10",
        "buffering_timeout": "0",
        "type": "ipv4"
      }
    ],

    "output": [
      {
        "name": "central-rrd-master-output",
        "metrics_path": "${RRD_METRICS_DIR}",
        "status_path":  "${RRD_STATUS_DIR}",
        "write_metrics": "yes",
        "write_status":  "yes",
        "store_in_data_bin": false,
        "insert_in_index_data": 0,
        "type": "rrd"
      }
    ],

    "grpc": {
      "port": 51002
    }
  }
}
