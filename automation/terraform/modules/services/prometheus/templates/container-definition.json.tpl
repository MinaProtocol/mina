[
  {
    "name": "prometheus",
    "image": "codaprotocol/prometheus:v2.11.1",
    "cpu": 0,
    "memory": 512,
    "portMappings": [
      {
        "containerPort": 9090,
        "hostPort": 9090
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
        { "name" : "REMOTE_WRITE_URI", "value" : "${remote_write_uri}" },
        { "name" : "REMOTE_WRITE_USERNAME", "value" : "${remote_write_username}" },
        { "name" : "REMOTE_WRITE_PASSWORD", "value" : "${remote_write_password}" },
        { "name" : "AWS_ACCESS_KEY", "value" : "${aws_access_key}" },
        { "name" : "AWS_SECRET_KEY", "value" : "${aws_secret_key}" }
    ]
  }
]