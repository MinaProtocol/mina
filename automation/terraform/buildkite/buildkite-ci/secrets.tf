provider "aws" {
  region = "us-west-2"
}

data "aws_secretsmanager_secret" "buildkite_agent_token_metadata" {
  name = "buildkite/agent/access-token"
}

data "aws_secretsmanager_secret_version" "buildkite_agent_token" {
  secret_id = "${data.aws_secretsmanager_secret.buildkite_agent_token_metadata.id}"
}

data "aws_secretsmanager_secret" "buildkite_agent_apitoken_metadata" {
  name = "buildkite/agent/api-token"
}

data "aws_secretsmanager_secret_version" "buildkite_agent_apitoken" {
  secret_id = "${data.aws_secretsmanager_secret.buildkite_agent_apitoken_metadata.id}"
}

data "aws_secretsmanager_secret" "prometheus_remote_write_config" {
  name = "coda-services/prometheus/remote_write_config"
}

data "aws_secretsmanager_secret_version" "current_prometheus_remote_write_config" {
  secret_id = "${data.aws_secretsmanager_secret.prometheus_remote_write_config.id}"
}
