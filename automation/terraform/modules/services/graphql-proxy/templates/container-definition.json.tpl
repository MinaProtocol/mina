[
  {
    "name": "graphql-proxy",
    "image": "codaprotocol/graphql-public-proxy:${proxy_container_version}",
    "cpu": 0,
    "memory": 512,
    "portMappings": [
      {
        "containerPort": ${proxy_external_port},
        "hostPort": ${proxy_external_port}
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-region": "${region}",
        "awslogs-group": "${log_group}",
        "awslogs-stream-prefix": "${log_group}"
      }
    },
    "environment" : [
        { "name" : "MINA_GRAPHQL_HOST", "value" : "${coda_graphql_host}" },
        { "name" : "MINA_GRAPHQL_PORT", "value" : "${coda_graphql_port}" },
        { "name" : "EXTERNAL_PORT", "value" : "${proxy_external_port}" }
    ]
  },
  {
    "name": "coda-daemon",
    "image": "codaprotocol/daemon:${coda_container_version}",
    "cpu": 0,
    "memory": 6500,
    "mountPoints" : [
      {
          "containerPath" : "/mina-config",
          "sourceVolume" : "archive-node-storage"
      }
    ],
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
        { "name" : "DAEMON_PEER", "value" : "${coda_peer}" },
        { "name" : "DAEMON_REST_PORT", "value" : "${coda_graphql_port}" },
        { "name" : "DAEMON_EXTERNAL_PORT", "value" : "${coda_external_port}" },
        { "name" : "DAEMON_DISCOVERY_PORT", "value" : "${coda_discovery_port}" },
        { "name" : "DAEMON_METRICS_PORT", "value" : "${coda_metrics_port}" },
        { "name" : "DAEMON_CLIENT_PORT", "value" : "${coda_client_port}" },
        { "name" : "MINA_PRIVKEY_PASS", "value" : "${coda_privkey_pass}" },
        { "name" : "CODA_TESTNET", "value" : "${coda_testnet}" },
        { "name" : "CODA_ARCHIVE_NODE", "value" : "${coda_archive_node}" }
    ]
  }
]