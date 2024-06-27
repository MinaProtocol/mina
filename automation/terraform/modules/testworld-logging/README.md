# Mina Incentivized Testnet: Log Infra Stack

This Terraform code deploys the logging stack used for the `testworld-2-0` testnet (also known as `ITN3`).

The initial version of this deployment uses a static virtual machine running Docker compose to deploy the following containers:

- postgres database
- logging front-end (GUI)
- logging backend (Log Consumer)

## Hardware Requirements

The most resource heavy portion of the deployment is the logging backend container. Sizing this container is determined by how much log traffic needs to be consumed. For an initial use, paired to the `testworld-2-0` testnet. The VM that hold the Docker Compose deployment is sized at `64vCPU` and `128Gi` RAM.

## VM configuration with Terraform templates

This deployment relies on Terraform templates to configure the final state on top of a VM running a vanilla Debian OS image. This is done because at the time of writing, Google Cloud does not offer a machine image with Docker preinstalled. A custom machine image can be created using a tool such as _Packer_ from Hashicorp, but Terraform templates have been chosen in this case to limit the number of tools and build steps in the deployment flow.

> [!NOTE]
> More information about using Terraform templates can be found on the [Terraform website](https://registry.terraform.io/providers/hashicorp/template/latest/docs).

Additional configuration can be layered on top of the VM OS by adding a new template to the `./templates` directory, declaring it as a `data` source within `vars.tf` file, and finally adding it to the `metadata` section of the VM configuration within the `main.tf` file.

## Handling Secrets

This deployment uses Google Secrets Manager to handle secrets. Secret values are not stored within the source code. If secrets are modified in Google Secrets Manager, note that the new values due not sync automatically and that a redeploy may be required to pull in the new values.

## Terraform Outputs

After deployment, the `output.tf` file is configured to print the public IP address that is assigned to the deployed virtual machine. This IP can be used to `ssh` to the machine.

```
Outputs:

docker_vm_ip = "35.35.35.35" <--- example IP
```
