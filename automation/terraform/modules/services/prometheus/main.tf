locals {
  service_name  = "prometheus-${var.environment}"
}


resource "aws_cloudwatch_log_group" "prometheus" {
  name              = local.service_name
  retention_in_days = 1
}

data "template_file" "container_definition" {
  template = "${file("${path.module}/templates/container-definition.json.tpl")}"

  vars = {
      log_group = local.service_name
      region = "us-west-2"
      remote_write_uri = var.remote_write_uri
      remote_write_username = var.remote_write_username
      remote_write_password = var.remote_write_password
      aws_access_key = var.aws_access_key
      aws_secret_key = var.aws_secret_key
  }
}

resource "aws_ecs_task_definition" "prometheus" {
  family = local.service_name

  container_definitions = data.template_file.container_definition.rendered
}

resource "aws_ecs_service" "prometheus" {
  name = local.service_name
  cluster = var.cluster_id
  task_definition = aws_ecs_task_definition.prometheus.arn

  desired_count = 1

  deployment_maximum_percent = 100
  deployment_minimum_healthy_percent = 0
}