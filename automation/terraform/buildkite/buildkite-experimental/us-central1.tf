data "aws_secretsmanager_secret" "buildkite_agent_token_metadata" {
  name = "buildkite/agent/access-token"
}

data "aws_secretsmanager_secret_version" "buildkite_agent_token" {
  secret_id = "${data.aws_secretsmanager_secret.buildkite_agent_token_metadata.id}"
}

locals {
  experimental_topology = {
    experimental = {
      agent = {
        tags  = "size=experimental"
        token = data.aws_secretsmanager_secret_version.buildkite_agent_token.secret_string
      }
      resources = {
        limits = {
          cpu    = "32"
          memory = "20G"
        }
      }
      replicaCount = 3
    }
  }
}

module "buildkite-ci-compute" {
  source = "../../modules/kubernetes/buildkite-agent"

  k8s_context             = "gke_o1labs-192920_us-central1_buildkite-infra-central"
  cluster_name            = "gke-benchmark"

  google_app_credentials  = var.google_credentials

  agent_vcs_privkey       = var.agent_vcs_privkey
  agent_topology          = local.experimental_topology
}
