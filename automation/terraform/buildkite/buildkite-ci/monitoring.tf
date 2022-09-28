locals {
  exporter_vars = {
    exporter = {
        buildkiteApiKey = data.aws_secretsmanager_secret_version.buildkite_agent_apitoken.secret_string
    }
  }
}

provider helm {
  alias = "bk_monitoring"
  kubernetes {
    config_context  = var.k8s_monitoring_ctx
  }
}

resource "helm_release" "buildkite_graphql_exporter" {
  provider  = helm.bk_monitoring

  name          = "buildkite-coda-exporter"
  chart         = "buildkite-exporter"
  version       = "0.1.4"
  repository    = "https://coda-charts.storage.googleapis.com"

  namespace = "default"
  values = [
    yamlencode(local.exporter_vars)
  ]

  force_update  = true
}
