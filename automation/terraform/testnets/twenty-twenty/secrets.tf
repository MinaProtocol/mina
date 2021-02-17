data "aws_secretsmanager_secret" "testnet_coda_privkey_pass" {
  name = "testnet/keys/coda_privkey_pass"
}

data "aws_secretsmanager_secret_version" "current_testnet_coda_privkey_pass" {
  secret_id = "${data.aws_secretsmanager_secret.testnet_coda_privkey_pass.id}"
}

data "aws_secretsmanager_secret" "discord_api_key" {
  name = "coda-services/faucet/discord_api_key/production"
}

data "aws_secretsmanager_secret_version" "current_discord_api_key" {
  secret_id = "${data.aws_secretsmanager_secret.discord_api_key.id}"
}

data "aws_secretsmanager_secret" "daemon_aws_access_keys" {
  name = "coda-services/daemon/daemon_aws_access_keys"
}

data "aws_secretsmanager_secret_version" "current_daemon_aws_access_keys" {
  secret_id = "${data.aws_secretsmanager_secret.daemon_aws_access_keys.id}"
}

data "aws_secretsmanager_secret" "service_daemon_privkey_pass" {
  name = "coda-services/daemon/service_daemon_privkey_pass"
}

data "aws_secretsmanager_secret_version" "current_service_daemon_privkey_pass" {
  secret_id = "${data.aws_secretsmanager_secret.service_daemon_privkey_pass.id}"
}