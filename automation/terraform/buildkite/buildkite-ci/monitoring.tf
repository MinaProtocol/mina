locals {
  prometheus_helm_values = {
    alertmanager = {
      enabled = false
    }
    kubeStateMetrics = {
      enabled = false
    }
    pushgateway = {
      enabled = false
    }
    nodeExporter = {
      service = {
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port" = "9100"
        }
      }
    }
    server = {
      global = {
        external_labels = {
          origin_prometheus = "${local.project_namespace}-prometheus"
        }
      }
      persistentVolume = {
        size = "25Gi"
      }
      remoteWrite = [
        {
          url = jsondecode(data.aws_secretsmanager_secret_version.current_prometheus_remote_write_config.secret_string)["remote_write_uri"]
          basic_auth = {
            username = jsondecode(data.aws_secretsmanager_secret_version.current_prometheus_remote_write_config.secret_string)["remote_write_username"]
            password = jsondecode(data.aws_secretsmanager_secret_version.current_prometheus_remote_write_config.secret_string)["remote_write_password"]
          }
          write_relabel_configs = [
            {
              source_labels: ["__name__"]
              regex: "(container.*)"
              action: "keep"
            }
          ]
        }
      ]
    }
  }

  exporter_vars = {
    exporter = {
        buildkiteApiKey = data.aws_secretsmanager_secret_version.buildkite_agent_apitoken.secret_string
    }
  }
}

provider helm {
  alias = "bk_monitoring"
  kubernetes {
    config_path = "~/.kube/config"
    config_context  = var.k8s_monitoring_ctx
  }
}

resource "helm_release" "buildkite_graphql_exporter" {
  provider  = helm.bk_monitoring

  name      = "buildkite-coda-exporter"
  chart     = "../../../helm/buildkite-exporter"
  namespace = local.project_namespace
  values = [
    yamlencode(local.exporter_vars)
  ]

  wait       = true
  force_update  = true

  depends_on = [helm_release.buildkite_prometheus]
}

resource "helm_release" "buildkite_prometheus" {
  provider  = helm.bk_monitoring

  name      = "${local.project_namespace}-prometheus"
  chart     = "stable/prometheus"
  namespace = local.project_namespace

  values = [
    yamlencode(local.prometheus_helm_values)
  ]

  wait       = true
}
