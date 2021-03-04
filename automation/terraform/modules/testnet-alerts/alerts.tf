# TODO: enable general loading and rendering of alert templates with custom input VARs

data "template_file" "testnet_alerts" {
  template = file("${path.module}/templates/testnet-alert-rules.yml.tpl")
  vars = {
    rule_namespace     = var.rule_namespace
    rule_filter        = var.rule_filter
    alerting_timeframe = var.rule_timeframe
  }
}

data "template_file" "testnet_alert_receivers" {
  template = file("${path.module}/templates/testnet-alert-receivers.yml.tpl")
  vars = {
    pagerduty_service_key  = data.aws_secretsmanager_secret_version.pagerduty_testnet_primary_key.secret_string
    pagerduty_alert_filter = var.pagerduty_alert_filter

    discord_alert_webhook = data.aws_secretsmanager_secret_version.discord_testnet_alerts_webhook.secret_string
  }
}

# Lint alerting config

resource "docker_container" "lint_rules_config" {
  name  = "cortex_lint"
  image = local.cortex_image
  command = [
    "rules",
    "lint",
    "--rule-files=/config/rules.yml"
  ]

  upload {
    content = data.template_file.testnet_alerts.rendered
    file    = "/config/rules.yml"
  }

  rm = true
}

resource "docker_container" "check_rules_config" {
  name  = "cortex_rules_check"
  image = local.cortex_image
  command = [
    "rules",
    "check",
    "--rule-files=/config/rules.yml",
  ]

  upload {
    content = data.template_file.testnet_alerts.rendered
    file    = "/config/rules.yml"
  }

  rm = true
}

resource "docker_container" "verify_alert_receivers" {
  name  = "cortex_verify_receivers"
  image = local.cortex_image
  command = [
    "alerts",
    "verify",
    "--address=${jsondecode(data.aws_secretsmanager_secret_version.alertmanager_api_auth.secret_string)["auth_url"]}",
    "--id=${jsondecode(data.aws_secretsmanager_secret_version.alertmanager_api_auth.secret_string)["id"]}",
    "--key=${jsondecode(data.aws_secretsmanager_secret_version.alertmanager_api_auth.secret_string)["password"]}"
  ]

  rm = true
}

# Deploy alert updates

resource "docker_container" "sync_alert_rules" {
  name  = "cortex_rules_sync"
  image = local.cortex_image
  command = [
    "rules",
    "sync",
    "--rule-files=/config/rules.yml",
    "--address=${jsondecode(data.aws_secretsmanager_secret_version.prometheus_api_auth.secret_string)["auth_url"]}",
    "--id=${jsondecode(data.aws_secretsmanager_secret_version.prometheus_api_auth.secret_string)["id"]}",
    "--key=${jsondecode(data.aws_secretsmanager_secret_version.prometheus_api_auth.secret_string)["password"]}"
  ]

  upload {
    content = data.template_file.testnet_alerts.rendered
    file    = "/config/rules.yml"
  }

  rm         = true
  depends_on = [docker_container.check_rules_config, docker_container.lint_rules_config]
}

resource "docker_container" "update_alert_receivers" {
  name  = "cortex_receivers_update"
  image = local.cortex_image
  command = [
    "alertmanager",
    "load",
    "/config/receivers.yml",
    "--address=${jsondecode(data.aws_secretsmanager_secret_version.alertmanager_api_auth.secret_string)["auth_url"]}",
    "--id=${jsondecode(data.aws_secretsmanager_secret_version.alertmanager_api_auth.secret_string)["id"]}",
    "--key=${jsondecode(data.aws_secretsmanager_secret_version.alertmanager_api_auth.secret_string)["password"]}"
  ]

  upload {
    content = data.template_file.testnet_alert_receivers.rendered
    file    = "/config/receivers.yml"
  }

  rm         = true
  depends_on = [docker_container.verify_alert_receivers]
}
