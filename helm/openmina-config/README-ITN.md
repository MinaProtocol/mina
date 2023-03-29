## Prerequisites
- Install kubectl https://kubernetes.io/docs/tasks/tools/#kubectl
- Install helm https://helm.sh/docs/intro/install/

## Setting up the config file

In your home directory, create a `.kube` direcory
```bash
mkdir ~/.kube
```

Copy the provided config file into `~/.kube` directory

Verify that both `kubectl` and `helm` is working

```bash
helm -n list
```

```bash
kubectl -n get pods
```

## Restarting the network

- Clone this repo
- Navigate to helm/openmina-config

First, we need to clean up the old nodes
```bash
./deploy.sh delete --all --force
```

Then, we need to change the `genesis_state_timestamp` in the [daemon.json](/helm/openmina-config/resources/daemon.json) to mitigate the empty epoch error in the block producers. A safe bet is to change it to the current day.

Ex.: (current date is 29th March 2023)
```
"2023-03-23T00:00:00+00:00" -> "2023-03-29T00:00:00+00:00"
```

Then we can redeploy the nodes using
```bash
./deploy.sh deploy --all --node-port=31400
```