# Testnet Terraform Module (K8s/GKE)

## Providers

| Name | Version |
|------|---------|
| google | n/a |
| helm | n/a |
| kubernetes | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:-----:|
| additional\_seed\_peers | n/a | `list` | `[]` | no |
| block\_producer\_key\_pass | n/a | `string` | n/a | yes |
| block\_producer\_starting\_host\_port | n/a | `number` | `10000` | no |
| cluster\_name | n/a | `string` | n/a | yes |
| cluster\_region | n/a | `string` | n/a | yes |
| coda\_image | n/a | `string` | `"codaprotocol/coda-daemon:0.0.13-beta-master-99d1e1f"` | no |
| fish\_block\_producer\_label\_offset | n/a | `number` | `0` | no |
| num\_fish\_block\_producers | n/a | `number` | `5` | no |
| num\_whale\_block\_producers | n/a | `number` | `3` | no |
| seed\_discovery\_keypairs | n/a | `list` | <pre>[<br>  "CAESQNf7ldToowe604aFXdZ76GqW/XVlDmnXmBT+otorvIekBmBaDWu/6ZwYkZzqfr+3IrEh6FLbHQ3VSmubV9I9Kpc=,CAESIAZgWg1rv+mcGJGc6n6/tyKxIehS2x0N1Uprm1fSPSqX,12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr",<br>  "CAESQKtOnmYHQacRpNvBZDrGLFw/tVB7V4I14Y2xtGcp1sEsEyfcsNoFi7NnUX0T2lQDGQ31KvJRXJ+u/f9JQhJmLsI=,CAESIBMn3LDaBYuzZ1F9E9pUAxkN9SryUVyfrv3/SUISZi7C,12D3KooWB79AmjiywL1kMGeKHizFNQE9naThM2ooHgwFcUzt6Yt1"<br>]</pre> | no |
| seed\_region | n/a | `string` | `"us-west1"` | no |
| seed\_zone | n/a | `string` | `"us-west1-a"` | no |
| snark\_worker\_fee | n/a | `number` | `10` | no |
| snark\_worker\_host\_port | n/a | `number` | `10400` | no |
| snark\_worker\_public\_key | n/a | `string` | `"4vsRCVadXwWMSGA9q81reJRX3BZ5ZKRtgZU7PtGsNq11w2V9tUNf4urZAGncZLUiP4SfWqur7AZsyhJKD41Ke7rJJ8yDibL41ePBeATLUnwNtMTojPDeiBfvTfgHzbAVFktD65vzxMNCvvAJ"` | no |
| snark\_worker\_replicas | n/a | `number` | `1` | no |
| testnet\_name | n/a | `string` | `"coda-testnet"` | no |

## Outputs

| Name | Description |
|------|-------------|
| seed\_addresses | n/a |
| seed\_one\_ip | n/a |
| seed\_two\_ip | n/a |

