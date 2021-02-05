locals {
  service_name  = "daemon-${var.environment}-${var.testnet}-${var.daemon_name}"
}


resource "aws_cloudwatch_log_group" "daemon" {
  name              = local.service_name
  retention_in_days = 1
}

data "template_file" "container_definition" {
  template = "${file("${path.module}/templates/container-definition.json.tpl")}"

  vars = {
      log_group = local.service_name
      region = "us-west-2"
      mina_container_version=var.mina_container_version
      mina_wallet_keys = var.mina_wallet_keys
      aws_access_key = var.aws_access_key
      aws_secret_key = var.aws_secret_key
      aws_default_region = var.aws_default_region
      daemon_peer = var.mina_peer
      daemon_rest_port = var.mina_rest_port
      daemon_external_port = var.mina_external_port
      daemon_discovery_port = var.mina_discovery_port
      daemon_metrics_port = var.mina_metrics_port
      mina_privkey_pass = var.mina_privkey_pass
      mina_snark_key = var.mina_snark_key
      mina_propose_key = var.mina_propose_key
  }
}

resource "aws_ecs_task_definition" "daemon" {
  family = local.service_name
  network_mode = "host"
  container_definitions = data.template_file.container_definition.rendered
}

resource "aws_ecs_service" "daemon" {
  name = local.service_name
  cluster = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.daemon.arn

  desired_count = 1

  deployment_maximum_percent = 100
  deployment_minimum_healthy_percent = 0
}