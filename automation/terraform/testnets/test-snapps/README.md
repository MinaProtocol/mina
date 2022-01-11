# Snapps QA-net deployment

The QA-net for snapps is called `test-snapps` and runs an image from `feature/snapps-protocol` which is the branch all snapps related PRs for the protocol are based off of. 

Setup for deploying the qa-net

1. Copy the `keys` folder from https://drive.google.com/drive/folders/1-WG6XMc56TIiyQrVgx8WLvgBZsGcCLx5?usp=sharing into `automation/`

2. create a baked image with a build from CI that you want to deploy
`automation/scripts/bake.sh --testnet=test-snapps --cloud=false --docker-tag=1.2.0beta5-feature-snapp-snarkworker-dee827f-stretch-devnet`
Note: The genesis ledger (genesis_ledger.json) for the network is in `automation/bake`. Update the genesis timestamp if it is older than 14 days.

3. In main.tf update `mina_image` to the baked image created in step 2 and `mina_archive_image` to the archive image from CI

4. The snapps qa net is configured to have 2 whale producers, 2 fish producers, 1 seed, 1 snark coordinator with 5 workers connected to it, and 3 archive processes writing to two postgres database (main.tf has these specifications). They keys in `automation/keys` are added accordingly.

5. If the qa-net is already running then destroy it by running `terraform destroy -auto-approve` from `automation/terraform/testnets/test-snapps/`. If running for the first time, then run `terraform init`
Note: You may have to set the env variable `KUBE_CONFIG=~/.kube/config `

6. Deploy the network by running `terraform apply -auto-approve` from `automation/terraform/testnets/test-snapps/`

7. Wait for all the nodes to come up and monitor the network on grafana https://o1testnet.grafana.net/