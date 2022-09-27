# locals {
#   west_topology = {
#     small = {
#       agent = {
#         tags  = "size=small"
#         token = data.aws_secretsmanager_secret_version.buildkite_agent_token.secret_string
#       }
#       resources = {
#         limits = {
#           cpu    = "2"
#           memory = "2G"
#         }
#       }
#       replicaCount = 12
#     }
#     large = {
#       agent = {
#         tags  = "size=large"
#         token = data.aws_secretsmanager_secret_version.buildkite_agent_token.secret_string
#       }
#       resources = {
#         limits = {
#           cpu    = "8"
#           memory = "8G"
#         }
#       }
#       replicaCount = 12
#     }
#   }
# }

# module "buildkite-west" {
#   source = "../../modules/kubernetes/buildkite-agent"

#   k8s_context             = "gke_o1labs-192920_us-west1_buildkite-infra-west"
#   cluster_name            = "gke-west1"
#   cluster_namespace       = local.project_namespace

#   google_app_credentials  = var.google_credentials

#   agent_vcs_privkey       = var.agent_vcs_privkey
#   agent_topology          = local.west_topology
# }
