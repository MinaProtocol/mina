# Berkeley Testnet deployment

The QA-net for zkapps is called `berkeley`, by decision of the Node Working Group, and runs an image from `develop` which is the branch all zkapps related PRs for the protocol are based off of and merged to

Setup for deploying the testnet

1. Firstly one needs to obtain the keys of all the nodes within the testnet, and place those keys within the testnet's directory, so for berkley it should be in `automation/terraform/testnets/berkeley/keys`.  This `keys` directory should be obtained from whoever has them- this is just a testnet so the keys don't control real money but they still are private keys.  the seeds will have a libp2p key but no account key, the whales and fish will have account keys but no libp2p key.

2. IF in `main.tf` the variable `use_embedded_runtime_config` is set to false, THEN make sure there is a genesis_ledger.json file in `automation/terraform/testnets/berkeley` (terraform apply will upload this genesis_ledger.json as a config-map and automatically hook it up to the daemons).  Make sure that the timestamp within this file is within the last 14 days, if the timestamp is older than 14 days then manually edit the date to be any time within 14 days.  Make sure the timestamp is in UTC format (hint: it should end with a `Z`).  On the other hand, if `use_embedded_runtime_config` is set to true, then the nodes will use whatever genesis ledger is baked into the docker image that you specify in step #3, and therefore no config-map upload of any genesis ledger json file is necessary.  As of 2022/03, buildkite CI will automatically build berkeley docker images, simply select one off of a good branch.  If you would like to manually create your own image, you can run `./automation/scripts/bake.sh --testnet=berkeley --cloud=false --docker-tag=<tag_of_existing_docker_image_to_use_as_base>`

3. In main.tf update `mina_image` and `mina_archive_image` to be a recent image created by our CI from the relevant branch.  If you prefer to use an image you baked in step #2 instead, then use that baked image for `mina_image`; note that this image needs to be uploaded somewhere, GCR or dockerhub, and cannot be simply a local image.

4. The berkeley testnet is currently configured to have 16 whales online (plus another 4 that we could bring online), 2 online fish, 3 seed, 1 snark coordinator with 5 workers connected to it, and 3 archive processes writing to two postgres database (main.tf has these specifications). As long as the keys for these nodes are in `automation/keys`, then the keys will be added and uploaded automatically by terraform.

5. If `berkeley` is already running then destroy it by running `terraform destroy --auto-approve` from the directory `automation/terraform/testnets/berkeley/`. If running for the first time, then run `terraform init`
Note: You may have to set the env variable `KUBE_CONFIG=~/.kube/config `

6. Deploy the network by running `terraform apply --auto-approve` from `automation/terraform/testnets/berkeley/`.  If the `./keys` dir already exists in the `berkeley` testnet dir, then those keys will be used.  If those folders and files do not exist, then terraform will run the script `automation/scripts/gen-keys-ledger.sh`, and arbitrary completely new keys will be generated, along with a new genesis ledger-- this is probably not what you want to do if you need to use old pre-existing keys.

7. Wait for all the nodes to come up and monitor the network on grafana https://o1testnet.grafana.net/