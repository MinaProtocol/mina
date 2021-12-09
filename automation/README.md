<a href="https://minaprotocol.com">
	<img width="200" src="https://minaprotocol.com/static/Mina_Wordmark_Github.png" alt="Mina Logo" />
</a>
<hr/>

# Repository Purpose

This repository is designed to show an opinionated example on how to operate a network of Mina Daemons. It implements the entire node lifecycle using a modern Infrastructure as Code toolset. Community contributions are warmly encouraged, please see the [contribution guidelines](../CONTRIBUTING.md) for more details. The code is designed to be as modular as possible, allowing the end-user to "pick and choose" the parts they would like to incorporate into their own infrastructure stack.

If you have any issues setting up your testnet or have any other questions about this repository, join the public [Discord Server](https://discord.gg/ShKhA7J) and get help from the Coda community.

# Code Structure

```
automation
├── helm
│   ├── block-producer
│   └── snark-worker
├── scripts
├── services
└── terraform
    ├── infrastructure
    ├── modules
    └── testnets
```

**Helm:** Contains Helm Charts for various components of a Mina Testnet

- _block-producer:_ One or more block producers consisting of unique `deployments`
- _snark-worker:_ Deploys a "SNARK Coordinator" consisting of one or more worker process containers

**Terraform:** Contains resource modules and live code to deploy a Mina Testnet.

- Note: Currently most modules are written against Google Kubernetes Engine, multi-cloud support is on the roadmap.
- _infrastructure:_ The root module for infrastructure like K8s Clusters and Prometheus.
- _kubernetes/testnet:_ A Terraform module that encapsulates a Mina Testnet, including Seed Nodes, Block Producers and SNARK Workers.
  _Scripts:_ Testnet utilities for key generation & storage, redelegation, etc.

# Prerequisites

For the purposes of this README we are assuming the following:

- You have a configured AWS Account with credentials on your machine: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html
- You have a configured Google Cloud Project with credentials on your machine: https://cloud.google.com/sdk/gcloud/reference/auth/login
- You have Terraform `0.12.28` installed on your machine

  MacOS:
  `brew install terraform@v0.12.28`

  Other Platforms: https://www.terraform.io/downloads.html

- You have Kubectl configured for the GKE cluster of your choice: https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl
  TL;DR: `gcloud container clusters get-credentials -region us-east1 coda-infra-east`

# What is a Testnet

A Testnet (a.k.a. Test Network) is a tool that is used to "test" Mina's distributed software. Our testnets are designed to simulate a "Mainnet" environment in order to identify bugs and test new functionality. Along with the network itself, there are several bots and services that are additionally deployed to facilitate a baseline of activity and access to the network.

# Components of a Testnet

### Whale and Fish Block Producers

In order to simulate a differentiation between O(1) Stake (Whales) and end-user stake (Fish), the testnets adhere to a simple naming scheme to differentiate between the two. In order to facilitate this, additional configuration must be made in the ledger, allocating a large amount of stake to "Whale Block Producers" and a lesser amount to "Fish Block Producers".

### Bots

Bots are often used to automate transactions being sent around the network. Often, these require special consideration in the genesis ledger, so it's worth keeping them in mind when setting up a new network. For example, the O(1) Discord Faucet is a simple sidecar bot that runs against a Mina Daemon's GraphQL Port and responds to requests for funds in the Mina Protocol Discord server.

### Services

Like bots, there are other blockchain-aware services that are deployed but might not need special consideration or stake. Two good examples of this are the Archive Node and the GraphQL Proxy.

### Ledger

The ledger is arguably the most important thing to get right, because this single point of failure can bork an entire deployment. There are several key points that have to be configured correctly for a network to bootstrap as expected:

- Offline keys delegated to online keys
- Proper balances and currency encoding
- Proper formatting of ledger itself

## QA Testnet

QA Testnets are designed to be run internally to support feature development and bug triage. Seed nodes are launched in Kubernetes with cluster-local DNS.

## Public Testnet

Public Testnets are functionally similar to QA Testnets but have the addition of "public" seed nodes with static IP addresses. This is required due to the necessarily dynamic nature of Kubernetes, so these public seeds are launched via Google Compute Engine VMs.

# Deploy a QA Testnet

Deploying a testnet is a relatively straightforward process once you have ironed out the configuration. At a high level, there are several pieces of configuration it's important to keep in mind or else your deployment might fail:

- Mina Keypairs
- Genesis Ledger
- Runtime Constants

### Clone the Repository

(If you are reading this locally, good job!)

### Apply the Infrastructure Module (If deploying infrastructure completely from scratch)

Most developers shouldn't have to worry about this, however it's worth noting that the entire infrastructure can be deployed from scratch by running `terraform init && terraform apply` in `terraform/infrastructure`.

If you don't know if you _should_ do this, you probably shouldn't!

### Create a Testnet

### Quick steps to launch a small network

1) make a new `terraform/testnets/<testnet>`
2) if necessary, modify the `main.tf` file in order to change the number of fish or whales
3) run the generate keys and ledger script to generate the genesis ledger with all the necessary libp2p and account keys.  make sure the argument you pass to --wc and --fc matches the number of whales and fish you specified in the main.tf  `./scripts/generate-keys-and-ledger.sh --testnet=<testnet> --wc=10 --fc=10`
4) optionally, run `./scripts/bake.sh --testnet=<testnet> --docker-tag=<tag, ex. 0.0.17-beta6-develop> --automation-commit=$(git log -1 --pretty=format:%H) --cloud=true`.  in our current system, baking a new image (which would put the newly generated genesis ledger and onto the image itself) is not necessary because when running terraform apply in a later step, terraform will run `./scripts/upload-keys-k8s.sh <testnet>` which uploads the ledger and mounts it on a volume which will override anything baked into the image.
4.1) copy the image tag from the output of bake.sh to `mina_image` in `terraform/testnets/<testnet>/main.tf`
4.2) set the archive image tag to the corresponding tag name - for example, if the image is `0.0.17-beta10-880882e`, use  `gcr.io/o1labs-192920/coda-archive:0.0.17-beta10-880882e`
5) run `terraform apply`

For a public network, the bake script is required, and also add the following steps

6) run `python3 scripts/get_peers.py <testnet>`
7) run `scripts/upload_cloud_bake_to_docker.sh --testnet=<TESTNET> --docker-tag=<tag> --automation-commit=<automation commit>`

### Creating the Testnet directory

Next, you must create a new testnet in `terraform/testnets/`. For ease of use, you can copy-paste an existing one, however it's important to go through the terraform and change the following things:

- location of Terraform state file
- Name of testnet
- number of nodes to deploy
- Location of the Genesis Ledger
- Kubernetes context for indicating which managed *k8s* cluster to deploy to

### Manage *k8s* Cluster for Deployment

Prior to deploying, reference your Kubernetes cloud provider for proper configuration of a Kubernetes cluster/context or reach out to #reliability-engineering within the `Mina Protocol` Discord server for guidance on internal engineering deployments.

The following *Kubernetes* cluster contexts are maintained by O(1) Lab's infrastructure team:

Cluster Name | Cluster Context | GCP/GKE *Kubernetes* Provider Region
--- | --- | ---
coda-infra-east | gke_o1labs-192920_us-east1_coda-infra-east | `us-east1` 
coda-infra-east4 | gke_o1labs-192920_us-east4_coda-infra-east4 | `us-east4` 
coda-infra-central1 | gke_o1labs-192920_us-central1_coda-infra-central1 | `us-central1` 
mina-integration-west1 | gke_o1labs-192920_us-west1_mina-integration-west1 | `us-west1` 

#### Obtain credentials for a Kubernetes context

Once decided on a cluster/context to deploy, use the following command to retrieve the appropriate cluster credentials:

`gcloud container clusters get-credentials <cluster-name> --region <cluster-region> --project o1labs-192920`

#### Set active cluster/context within deploy environment

`kubectl config use-context <cluster-context>`

#### Configure testnet module `k8s_context`

There is a testnet module variable which determines the *Kubernetes* context to deploy to. Reference the module's [variable definitions](./terraform/modules/kubernetes/testnet/variables.tf) for more details on how to properly configure.

```variable "k8s_context" {
  type = string

  description = "K8s resource provider context"
  default     = "gke_o1labs-192920_us-east1_coda-infra-east"
}```

#### Set Terraform Kubernetes provider configuration path

In order for Terraform to locate and identify the configured Kubernetes contexts, it is expected that the `KUBE_CONFIG_PATH` environment variable is set to the operator's Kubernetes configuration file (generally found at *~/.kube/config*). Be sure to run this step prior to attempting to execute any `terraform` commands on a testnet. See [here](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs#config_paths) for more details.

```
export KUBE_CONFIG_PATH=~/.kube/config
}```

### Generate Keys and Genesis Ledger

The script `scripts/generate-keys-and-ledger.sh` handles key and genesis ledger generation. This script will build keysets and public/private key files to the output path in `./keys/keysets` and `keys/testnet-keys`.
It is necessary to set the number of whales, fish, and extra-fish. The testnet name will specify the genesis ledger output folder for daemon consumption. `terraform/tests/TESTNET/`

```
./scripts/generate-keys-and-ledger.sh --testnet=beans --wc=5 --fc=1 --efc=2

Options:
  --testnet=STRING     Name of the testnet which keys are being generated for.
  --wc=INTEGER         Number of Whale Account keys to generate.
  --fc=INTEGER         Number of Fish Account keys to generate.
  --efc=INTEGER        Number of extra Fish keys to generate.
  --reset=true|false   Boolean to force regeneration of keys. Default is false
```

### Bake Script

The bake script allows you to bundle keys and genesis ledger pre baked into the container with the latest mina daemon. It does this by pulling the genesis ledger from github specified by the automation commit and the testnet name. Therefore to use the script the genesis ledger must be pushed to github at the correct commit. The cloud flag can be set to true to build via GCP's cloud build functionality.

```
./scripts/bake.sh --testnet=nightly --docker-tag=0.0.17-beta6-develop --automation-commit=$(git log -1 --pretty=format:%H) --cloud=true

Options:
  --testnet=STRING            Name of the testnet.
  --docker-tag=STRING         Docker tag for the mina daemon repository.
  --automation-commit=STRING  Specifying commit for mina/automation.
  --cloud=true|false          Should docker be built in cloud or locally.
```

### Upload Secrets script
`scripts/upload-keys-k8s.sh` is responsible for uploading the whale, fish, bots, and discord keys as secrets to kubernetes for a given testnet name. It assumes that the keys are specified at `keys/testnet-keys`. If the keys were generated with `generate-keys-and-ledger.sh` and not changed or moved you can leave `$KEYS_PREFIX` blank

```
  scripts/upload-keys-k8s.sh $TESTNET_NAME $KEYS_PREFIX
```

### Is it Working?

#### Logs

Logs will be persisted in StackDriver for any container deployment.

**Example Queries:**

Get all logs from `fish-block-producer-1` in the `<testnet>` namespace.

```
resource.type="k8s_container"
resource.labels.project_id="o1labs-192920"
resource.labels.location="us-east1"
resource.labels.cluster_name="coda-infra-east"
resource.labels.namespace_name="<testnet>"
labels.k8s-pod/app="fish-block-producer-1"
```

Get all logs from any Block Producer (note the `:` instead of `=` in `labels.k8s-pod/app:"block-producer"`!):

```
resource.type="k8s_container"
resource.labels.project_id="o1labs-192920"
resource.labels.location="us-east1"
resource.labels.cluster_name="coda-infra-east"
resource.labels.namespace_name="<testnet>"
labels.k8s-pod/app:"block-producer"
```

#### Dashboards

There are several public Grafana dashboards available here:

- [Network Overview](https://o1testnet.grafana.net/d/qx4y6dfWz/network-overview?orgId=1)
- [Block Producer](https://o1testnet.grafana.net/d/Rgo87HhWz/block-producer-dashboard?orgId=1&refresh=1m)
- [SNARK Worker](https://o1testnet.grafana.net/d/scQUGOhWk/snark-worker-dashboard?orgId=1&refresh=1m)

# Deploy a Public Testnet

### Collect User Key Submissions

The purpose of a public testnet is to allow end-users to try out the software and learn how to operate it. Thus, we accept sign-ups for stake to be allocated in the genesis, and commit those keys to the compiled genesis ledger.

For context, these keys correspond to the "Fish Keys" in the QA Net deployments, and Online Fish Keys are ommitted in a Public Testnet deployment and "Offline Fish Keys" are instead delegated to the submitted User Keys.

### Generate Genesis Ledger

Once you have the keys for your deploymenet created, and the Staker Keys saved to a CSV, you can use them to generate a genesis ledger with the following command.

```
scripts/generate-keys-and-ledger.sh
```

Read the source for more about what it is doing and how.

### Create a Testnet

Next, you must create a new testnet in `terraform/testnets/`. For ease of use, you can copy-paste an existing one, however it's important to go through the terraform and change the following things:

- location of Terraform state file
- Name of testnet (Note: Prefix it with `test-` for testnets that don't require alerting. For example, private testnets for testing specific features)
- number of nodes to deploy
- Location of the Genesis Ledger

In addition, you must include one or more public seed nodes for users to bootstrap with:

```
module "network" {
  source         = "../../modules/google-cloud/vpc-network"
  network_name   = "${local.netname}-testnet-network"
  network_region = "us-west1"
  subnet_name    = "${local.netname}-testnet-subnet"
}

# Seed DNS
data "aws_route53_zone" "selected" {
  name = "o1test.net."
}

resource "aws_route53_record" "seed_one" {
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
  name    = "seed-one.${local.netname}.${data.aws_route53_zone.selected.name}"
  type    = "A"
  ttl     = "300"
  records = [module.seed_one.instance_external_ip]
}

resource "aws_route53_record" "seed_two" {
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
  name    = "seed-two.${local.netname}.${data.aws_route53_zone.selected.name}"
  type    = "A"
  ttl     = "300"
  records = [module.seed_two.instance_external_ip]
}
```
