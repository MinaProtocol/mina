A terraform module to launch a Seed Node on Google Compute Engine

## Providers

| Name | Version |
|------|---------|
| google | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:-----:|
| client\_email | Service account email address | `string` | `""` | no |
| coda\_image | The docker image to deploy. | `any` | n/a | yes |
| cos\_image\_name | The forced COS image to use instead of latest | `string` | `"cos-stable-77-12371-89-0"` | no |
| discovery\_keypair | The LibP2P Keypair to use when launching the seed node. | `any` | n/a | yes |
| instance\_name | The desired name to assign to the deployed instance | `string` | `"coda-seed-node"` | no |
| project\_id | The project ID to deploy resources into | `any` | n/a | yes |
| region | The GCP region to deploy addresses into | `string` | n/a | yes |
| seed\_peers | An Optional space-separated list of -peer <peer-string> arguments for the mina daemon | `string` | `""` | no |
| subnetwork | The name of the subnetwork to deploy instances into | `any` | n/a | yes |
| subnetwork\_project | The project ID where the desired subnetwork is provisioned | `any` | n/a | yes |
| zone | The GCP zone to deploy instances into | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| discovery\_keypair | n/a |
| instance\_external\_ip | n/a |

