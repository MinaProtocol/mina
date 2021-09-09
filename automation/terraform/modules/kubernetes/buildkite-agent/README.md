<p><img src="https://www.thepracticalsysadmin.com/wp-content/uploads/2020/03/terraform1.png" alt="Terraform logo" title="terraform" align="left" height="60" /></p>
<p><img src="https://buildkite.com/docs/assets/integrations/github_enterprise/buildkite-square-58030b96d33965fef1e4ea8c6d954f6422a2489e25b6b670b521421fcaa92088.png" alt="buildkite logo" title="buildkite" align="right" height="100" /></p>

# Buildkite Agent Terraform Module (K8s/GKE)

## Providers

| Name | Version |
|------|---------|
| google | n/a |
| helm | n/a |
| kubernetes | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:-----:|
| cluster\_name | Name of K8s Buildkite Agent cluster to provision | `string` | n/a | yes |
| agent\_topology | Buildkite agent system resource and metadata specification | `map` | `{}` | yes |
| agent\_vcs\_privkey | Agent SSH private key for access to (Github) version control system | `string` | n/a | no |
| agent\_version | Version of Buildkite agent to launch | `string` | 3 | no |
| agent\_config | Buildkite agent configuration options (see: https://github.com/buildkite/charts/blob/master/stable/agent/README.md#configuration) | `map(string)` | `{}` | no |
| helm\_chart | Identifier of Buildkite helm chart. | `string` | `buildkite/agent` | no |
| helm\_repo | Repository URL where to locate the requested Buildkite chart. | `string` | `https://buildkite.github.io/charts/` | no |
| chart\_version | Buildkite chart version to provision | `string` | `0.3.16` | no |
| gsutil\_download\_url | gsutil tool archive download URL | `string` | `https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-296.0.1-linux-x86_64.tar.gz` | no |
| summon\_download\_url | Summon secrets management binary download URL | `string` | `https://github.com/cyberark/summon/releases/download/v0.8.1/summon-linux-amd64.tar.gz` | no |
| secretsmanager\_download\_url | AWS secrets manager summon provider download URL | `string` | `https://github.com/cyberark/summon-aws-secrets/releases/download/v0.3.0/summon-aws-secrets-linux-amd64.tar.gz` | no |
| enable\_gcs\_access | Whether to grant the provisioned cluster with GCS access (for artifact uploading, etc) | `bool` | `true` | no |
| artifact\_upload\_bin | Path to agent artifact upload binary | `string` | `/usr/local/google-cloud-sdk/bin/gsutil` | no |
| artifact\_upload\_path | Path within GCS to upload agent job artifacts | `string` | `gs://buildkite_k8s/coda/shared` | no |
| image\_pullPolicy | Agent container image pull policy | `string` | `IfNotPresent` | no |
| dind\_enabled | Whether to enable a preset Docker-in-Docker(DinD) pod configuration | `bool` | `true` | no |
| k8s\_cluster\_name | Infrastructure Kubernetes cluster to provision Buildkite agents on | `string` | `coda-infra-east` | no |
| k8s\_cluster\_region | Kubernetes cluster region | `string` | `useast-1` | no |
| k8s\_provider | Kubernetes resource provider (currently supports `GKE` and `minikube`) | `string` | `minikube` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_svc_name | Buildkite cluster Google service account name  |
| cluster_svc_email | Buildkite cluster Google service account email identifier  |
