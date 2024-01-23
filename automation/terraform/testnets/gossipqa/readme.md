GossipQA testnet deployment Instructions

0: Before starting, make sure that no pre-existing gossipqa deployment exists, and also make sure one is working within us-central-1 by running 

`gcloud container clusters get-credentials --region northamerica-northeast1 mina-infra-canada`

1: Firstly figure out how many unique and total fish, whales, plain nodes, snark coordinators, and how many snark workers per coordinator.  All these must be written out in `automation/terraform/testnets/gossipqa/main.tf`.  use the terraform for-loops to make this process less copy-pasty.  Non unique block producers are separate nodes on the network, but use the same key for block production.

2: Generate the keys and genesis ledger.  If you want there to be thousands and thousands of extra random keys in the genesis ledger, use the efc (extra fish count) flag.  From the /mina base directory, run:

`./automation/scripts/gen-keys-ledger.sh --testnet="gossipqa" --whales=<unique whales> --fish=<unique fish> --seeds=<seed count> --privkey-pass <password to the keys generated>`

these keys get generated in ./gossipqa/keys.  the seeds will have a libp2p key but no account key, the whales and fish will have account keys but no libp2p key.  A genesis ledger will also be generated which includes all the whales and fish.

3: Ideally, in the newly generated genesis ledger, grab any bunch of public keys and use those keys for the `snark_worker_public_key` in a snark worker/coordinator set.  You will have to modify the `snark_coordinators` list within `automation/terraform/testnets/gossipqa/main.tf`.  Because each key is different and we haven't written auto selection logic, this bit is unfortunately a process of "copy -> paste -> manual change".

4: The above steps only have to be done once.  When all that is done, run `terraform apply` in `./automation/terraform/testnets/gossipqa`

5: When the network is fully deployed, you can deploy the txn burst cronjob.  make whatever modifications to `helm/cron_jobs/gossipqa-txn-burst-cronjob.yaml` as you like, then deploy it with `kubectl apply -f helm/cron_jobs/<your new file>.yaml`.  you may need to modify the cronjob scheduling, as well as the arguments to `batch_txn_tool.exe`.  Also each time you generate keys, the seed urls will be different.  these need to be manually hardcoded into the script inside the cronjob.


when you're all done, clean up with either `terraform destroy`, or `kubectl delete namespace gossipqa`

------------------------------------------------

Metrics Deployment Instructions

1: create a separate namspace so that all the metrics stuff is isolated in one place.  technically it doesn't matter what namespace this is deployed in.

kubectl create namespace gossipqa-metrics
kubectl config set-context --current --namespace=gossipqa-metrics

2: create prometheus with helm

2.1: make the permanent volume claim.  if you don't do this then you'll lose all of the data that prometheus gathers when promtheus goes down.  

```
# make the permanent volume claim
kubectl apply -f automation/terraform/testnets/gossipqa/gossipqa-prom-pvc.yaml
```

2.2: use helm to install prometheus
```
helm install gossipqa-prom prometheus-community/prometheus -f automation/terraform/testnets/gossipqa/values.yaml
```

3: create grafana using helm

3.1: make a config map with all the configs which create for us a useful dashboard on grafana.

```
# upload the config map which gives us a useful dashboard in grafana.  the label is necessary for the grafana sidecar that monitors the config maps and installs them.
kubectl create configmap simplified-mainnet-dashboard --namespace gossipqa-metrics --from-file automation/terraform/testnets/gossipqa/Grafana_Export_Simplified_Mainnet_Overview-1634935128244.json
kubectl label configmap simplified-mainnet-dashboard grafana_dashboard=1
```

3.2: install grafana using a the stack deployer `kube-prometheus-stack`.  this stack theoretically could give us both prometheus and grafana, but we've turned off prometheus and are only deploying grafana since we are deploying prometheus separately

```
#install grafana
helm install gossipqa-metrics-stack prometheus-community/kube-prometheus-stack -f automation/terraform/testnets/gossipqa/values-stack.yaml
```

3: In order access grafana

#get the login credentials if you don't already have it.  the username is "admin"
kubectl get secret gossipqa-metrics-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

#run kubectl get pods and find the grafana pod, then do a port forward
kubectl port-forward pod/gossipqa-metrics-stack-grafana-7f6df7b44d-lcstl 3000:3000

3.1: you may have to manually configure graphana to use the datasource deployed in step 2.

4: uninstall
```helm uninstall gossipqa-prom

helm uninstall gossipqa-metrics-stack
```

#if you really want to nuke everything, you can delete the entire namespace.  however this will delete the permanent volume claim, and thus delete all the data you've gathered
kubectl delete namespace gossipqa-prom
kubectl delete namespace gossipqa-metrics

