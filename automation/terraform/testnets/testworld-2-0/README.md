# ITN-3 Testnet deployment

The QA-net for the ITN-3 (Incentivized Testnet 3) runs an image from `berkeley` which is the branch all zkapps related PRs for the protocol are based off of and merged to.

Setup for deploying the testnet

1. Firstly one needs to obtain the keys of all the nodes within the testnet, and place those keys within the testnet's directory, so for ITN-3 it should be in `automation/terraform/testnets/itn3-testnet/keys`.  This `keys` directory should be obtained from whoever has them - this is just a testnet so the keys don't control real money but they still are private keys. The seeds will have a libp2p key but no account key, any whales and fish will have account keys but no libp2p key.

2. With testnet using ledger sizes larger than 4mb (including ITN-3), the variable `use_embedded_runtime_config` is no longer supported and must be set to `true` due to file size limits within Terraform. Larger ledger files must be baked into the testnet Docker container to be used. Make sure that the timestamp within the ledger file is within the last 14 days before baking it into the container, if the timestamp is older than 14 days then manually edit the date to be any time within 14 days. Make sure the timestamp is in UTC format (hint: it should end with a `Z`). To manually create a baked Docker image, you can run `./automation/scripts/bake.sh --testnet=itn3 --cloud=false --docker-tag=<tag_of_existing_docker_image_to_use_as_base>`.

3. In main.tf update `mina_image` and `mina_archive_image` to be a recent image created by our CI from the relevant branch. If you prefer to use an image you baked in step #2 instead, then use that baked image for `mina_image`; note that this image needs to be uploaded somewhere, GCR or dockerhub, and cannot be simply a local image. Be sure to also update `mina_archive_schema_aux_files` if the archive schema has changed since the last deployment.

4. The ITN-3 testnet is configured by default to have 16 whales online (plus another 4 that we could bring online), 2 online fish, 3 seed, 1 snark coordinator with 5 workers connected to it, and 3 archive processes writing to two postgres database (main.tf has these specifications). As long as the keys for these nodes are in `automation/terraform/testnets/itn3-testnet/keys`, then the keys will be added and uploaded automatically by terraform.

5. If `itn3` is already running then destroy it by running `terraform destroy --auto-approve` from the directory `automation/terraform/testnets/itn3-testnet/`. If running for the first time, then run `terraform init`

Note: You may have to set the env variable `KUBE_CONFIG=~/.kube/config `

6. Deploy the network by running `terraform apply --auto-approve` from `automation/terraform/testnets/itn3-testnet/`.  If the `./keys` dir already exists in the `itn3-testnet` testnet dir, then those keys will be used.  If those folders and files do not exist, then terraform will run the script `automation/scripts/gen-keys-ledger.sh`, and new keys will be arbitrarily generated, along with a new genesis ledger-- this is probably not what you want to do if you need to use old pre-existing keys.

7. Wait for all the nodes to come up and monitor the network on grafana https://o1testnet.grafana.net/