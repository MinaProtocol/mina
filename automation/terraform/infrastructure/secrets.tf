provider aws {
  region = "us-west-2"
}

# Prometheus

data "aws_secretsmanager_secret" "prometheus_remote_write_config" {
  name = "coda-services/prometheus/remote_write_config"
}

data "aws_secretsmanager_secret_version" "current_prometheus_remote_write_config" {
  secret_id = "${data.aws_secretsmanager_secret.prometheus_remote_write_config.id}"
}
