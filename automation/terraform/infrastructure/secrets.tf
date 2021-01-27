provider aws {
  region = "us-west-2"
}

# Prometheus/Alertmanager

data "aws_secretsmanager_secret" "prometheus_remote_write_config" {
  name = "coda-services/prometheus/remote_write_config"
}

data "aws_secretsmanager_secret_version" "current_prometheus_remote_write_config" {
  secret_id = "${data.aws_secretsmanager_secret.prometheus_remote_write_config.id}"
}

data "aws_secretsmanager_secret" "alertmanager_api_auth_metadata" {
  name = "mina-services/alertmanager/api_auth"
}

data "aws_secretsmanager_secret_version" "alertmanager_api_auth" {
  secret_id = "${data.aws_secretsmanager_secret.alertmanager_api_auth_metadata.id}"
}

# Pagerduty

data "aws_secretsmanager_secret" "pagerduty_testnet_primary_key_metadata" {
  name = "pagerduty/testnet/key/primary"
}

data "aws_secretsmanager_secret_version" "pagerduty_testnet_primary_key" {
  secret_id = "${data.aws_secretsmanager_secret.pagerduty_testnet_primary_key_metadata.id}"
}

# Discord

data "aws_secretsmanager_secret" "discord_testnet_alerts_webhook_metadata" {
  name = "discord/testnet/alerts/webhook"
}

data "aws_secretsmanager_secret_version" "discord_testnet_alerts_webhook" {
  secret_id = "${data.aws_secretsmanager_secret.discord_testnet_alerts_webhook_metadata.id}"
}
