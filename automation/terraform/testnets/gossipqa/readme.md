Run Instructions

0: Before starting, make sure that no pre-existing gossipqa deployment exists, and also make sure one is working within us-central-1 by running 

`gcloud container clusters get-credentials --region us-central1 coda-infra-central1`

1: Firstly figure out how many unique and total fish, whales, plain nodes, snark coordinators, and how many snark workers per coordinator.  All these must be written out in `automation/terraform/testnets/gossipqa/main.tf`.  use the terraform for-loops to make this process less copy-pasty

2: Generate the keys and genesis ledger.  If you want there to be thousands and thousands of extra random keys in the genesis ledger, use the efc (extra fish count) flag.  From the /mina base directory, run:

`./automation/scripts/generate-keys-and-ledger.sh --testnet="gossipqa" --wu=<unique whales> --wt=<total whales> --fu=<unique fish> --ft=<total fish> --sc=<seed count> --efc=<extra fish count>`

3: Ideally, in the newly generated genesis ledger, grab any bunch of public keys and use those keys for the `snark_worker_public_key` in a snark worker/coordinator set.  You will have to modify the `snark_coordinators` list within `automation/terraform/testnets/gossipqa/main.tf`.  Because each key is different and we haven't written auto selection logic, this bit is unfortunately a process of "copy -> paste -> manual change".

4: The above steps only have to be done once.  When all that is done, run `terraform apply` in `./automation/terraform/testnets/gossipqa`

5: When the network is fully deployed, you can deploy the txn burst cronjob.  make whatever modifications to `helm/cron_jobs/gossipqa-txn-burst-cronjob.yaml` as you like, then deploy it with `kubectl apply -f helm/cron_jobs/<your new file>.yaml`.  you may need to modify the cronjob scheduling, as well as the arguments to `batch_txn_tool.exe`.  Also each time you generate keys, the seed urls will be different.  these need to be manually hardcoded into the script inside the cronjob.


when you're all done, clean up with either `terraform destroy`, or `kubectl delete namespace gossipqa`

