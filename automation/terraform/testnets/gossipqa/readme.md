GossipQA testnet deployment Instructions

0: Before starting, make sure that no pre-existing gossipqa deployment exists, and also make sure one is working within us-central-1 by running 

`gcloud container clusters get-credentials --region us-central1 coda-infra-central1`

1: Firstly figure out how many unique and total fish, whales, plain nodes, snark coordinators, and how many snark workers per coordinator.  All these must be written out in `automation/terraform/testnets/gossipqa/main.tf`.  use the terraform for-loops to make this process less copy-pasty

2: Generate the keys and genesis ledger.  If you want there to be thousands and thousands of extra random keys in the genesis ledger, use the efc (extra fish count) flag.  From the /mina base directory, run:

`./automation/scripts/generate-keys-and-ledger.sh --testnet="gossipqa" --wu=<unique whales> --wt=<total whales> --fu=<unique fish> --ft=<total fish> --sc=<seed count> --efc=<extra fish count>`

3: Ideally, in the newly generated genesis ledger, grab any bunch of public keys and use those keys for the `snark_worker_public_key` in a snark worker/coordinator set.  You will have to modify the `snark_coordinators` list within `automation/terraform/testnets/gossipqa/main.tf`.  Because each key is different and we haven't written auto selection logic, this bit is unfortunately a process of "copy -> paste -> manual change".

4: The above steps only have to be done once.  When all that is done, run `terraform apply` in `./automation/terraform/testnets/gossipqa`

5: When the network is fully deployed, you can deploy the txn burst cronjob.  make whatever modifications to `helm/cron_jobs/gossipqa-txn-burst-cronjob.yaml` as you like, then deploy it with `kubectl apply -f helm/cron_jobs/<your new file>.yaml`.  you may need to modify the cronjob scheduling, as well as the arguments to `batch_txn_tool.exe`.  Also each time you generate keys, the seed urls will be different.  these need to be manually hardcoded into the script inside the cronjob.


when you're all done, clean up with either `terraform destroy`, or `kubectl delete namespace gossipqa`

------------------------------------------------

Metrics Deployment Instructions

1: create a separate namspace so that all the metrics stuff is isolated in one place.  technically it doesn't matter what namespace this is deployed in.

kubectl create namespace gossipqa-metrics
kubectl config set-context --current --namespace=gossipqa-metrics

2: deploy the stack

2.1: make the permanent volume claim.  if you don't do this then you'll lose all of the data that prometheus gathers when promtheus goes down.  

```
# make the permanent volume claim
kubectl apply -f automation/terraform/testnets/gossipqa/gossipqa-prom-pvc.yaml
```

2.2: make a config map with all the configs which create for us a useful dashboard on grafana.

```
# upload the config map which gives us a useful dashboard in grafana.  the label is necessary for the grafana sidecar that monitors the config maps and installs them.
kubectl create configmap simplified-mainnet-dashboard --namespace gossipqa-metrics --from-file automation/terraform/testnets/gossipqa/Grafana_Export_Simplified_Mainnet_Overview-1634935128244.json
kubectl label configmap simplified-mainnet-dashboard grafana_dashboard=1
```

2.3: install the stack with helm.  this deploys both prometheus, and grafana in one single command.  the values.yaml file that we give the command contains a bunch of configs which override the default configs of "prometheus-community/kube-prometheus-stack".  notably, we need to configure it to use the PVC for prometheus and the config map for graphana.  

```
#install prometheus and grafana
helm install gossipqa-metrics-stack prometheus-community/kube-prometheus-stack -f automation/terraform/testnets/gossipqa/values-stack.yaml```

3: In order to see all those nice colorful charts we deployed on grafana

#get the login credentials if you don't already have it.  the username is "admin"
kubectl get secret gossipqa-metrics-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

#run kubectl get pods and find the grafana pod, then do a port forward
kubectl port-forward pod/gossipqa-metrics-stack-grafana-56d9c65796-s6dbw 3000:3000


4: uninstall
helm uninstall gossipqa-metrics-stack

#if you really want to nuke everything, you can delete the entire namespace.  however this will delete the permanent volume claim, and thus delete all the data you've gathered
kubectl delete namespace gossipqa-metrics

