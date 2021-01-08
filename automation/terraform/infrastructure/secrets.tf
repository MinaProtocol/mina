provider aws {
  region = "us-west-2"
}

data "aws_secretsmanager_secret" "prometheus_remote_write_config" {
  name = "coda-services/prometheus/remote_write_config"
}

data "aws_secretsmanager_secret_version" "current_prometheus_remote_write_config" {
  secret_id = "${data.aws_secretsmanager_secret.prometheus_remote_write_config.id}"
}

data "aws_secretsmanager_secret" "pagerduty_testnet_primary_key" {
  name = "pagerduty/testnet/key/primary"
}

data "aws_secretsmanager_secret_version" "pagerduty_testnet_primary_key_id" {
  secret_id = "${data.aws_secretsmanager_secret.pagerduty_testnet_primary_key.id}"
}
