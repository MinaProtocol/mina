# Snapps QA-net deployment

The QA-net for snapps is called `test-snapps` and runs an image from `feature/snapps-protocol` which is the branch all snapps related PRs for the protocol are based off of. 

Setup for deploying the qa-net

1. Copy the `keys` folder from https://drive.google.com/drive/folders/1-WG6XMc56TIiyQrVgx8WLvgBZsGcCLx5?usp=sharing into `automation/`

2. Make sure there is a genesis_ledger.json file in `automation/terraform/testnets/test-snapps` (terraform apply will upload this genesis_ledger.json and automatically hook it up to the daemons).  Make sure that the timestamp within this file is within the last 14 days, if the timestamp is older than 14 days then manually edit the date to be any time within 14 days.  Make sure the timestamp is in UTC format (hint: it should end with a `Z`).  Note: it is not necessary to create a baked image based on an image from CI, but if you would like to do that then run `./automation/scripts/bake.sh --testnet=test-snapps --cloud=false --docker-tag=1.2.0beta5-feature-snapp-snarkworker-dee827f-stretch-devnet`

3. In main.tf update `mina_image` and `mina_archive_image` to be a recent image created by our CI from the relevant branch (in this case `feature/snapps-protocol`).  If you prefer to use an image you baked, then use the baked image for `mina_image`

4. The test-snapps testnet is currently configured to have 16 whales online (plus another 4 that we could bring online), 2 online fish, 3 seed, 1 snark coordinator with 5 workers connected to it, and 3 archive processes writing to two postgres database (main.tf has these specifications). As long as the keys for these nodes are in `automation/keys`, then the keys will be added and uploaded automatically by terraform.

5. If the `test-snapps` is already running then destroy it by running `terraform destroy --auto-approve` from the directory `automation/terraform/testnets/test-snapps/`. If running for the first time, then run `terraform init`
Note: You may have to set the env variable `KUBE_CONFIG=~/.kube/config `

6. Deploy the network by running `terraform apply --auto-approve` from `automation/terraform/testnets/test-snapps/`

7. Wait for all the nodes to come up and monitor the network on grafana https://o1testnet.grafana.net/