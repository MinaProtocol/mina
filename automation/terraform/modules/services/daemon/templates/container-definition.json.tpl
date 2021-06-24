[
  {
    "name": "coda-daemon",
    "image": "codaprotocol/daemon:${coda_container_version}",
    "cpu": 0,
    "memory": 8000,
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-region": "${region}",
        "awslogs-group": "${log_group}",
        "awslogs-stream-prefix": "${log_group}"
      }
    },
    "environment" : [
        { "name" : "CODA_WALLET_KEYS", "value" : "${coda_wallet_keys}" },
        { "name" : "AWS_ACCESS_KEY_ID", "value" : "${aws_access_key}" },
        { "name" : "AWS_SECRET_ACCESS_KEY", "value" : "${aws_secret_key}" },
        { "name" : "AWS_DEFAULT_REGION", "value" : "${aws_default_region}" },
        { "name" : "DAEMON_PEER", "value" : "${daemon_peer}" },
        { "name" : "DAEMON_REST_PORT", "value" : "${daemon_rest_port}" },
        { "name" : "DAEMON_EXTERNAL_PORT", "value" : "${daemon_external_port}" },
        { "name" : "DAEMON_DISCOVERY_PORT", "value" : "${daemon_discovery_port}" },
        { "name" : "DAEMON_METRICS_PORT", "value" : "${daemon_metrics_port}" },
        { "name" : "MINA_PRIVKEY_PASS", "value" : "${coda_privkey_pass}" },
        { "name" : "CODA_SNARK_KEY", "value" : "${coda_snark_key}" },
        { "name" : "CODA_PROPOSE_KEY", "value" : "${coda_propose_key}" }
    ]
  }
]