# Local access to testnet nodes via GraphQL

# Prerequisites
* Install [`gcloud` SDK](https://cloud.google.com/sdk/docs/install-sdk).
* Install `kubectl` by running `gcloud components install kubectl`.
* Log-in using the [`gcloud auth
  login`](https://cloud.google.com/sdk/gcloud/reference/auth/login) command
  with your O(1) Labs email.

# Get the credentials for the region running the nodes

Retrieve the credentials for the region that the nodes are running in, using
[`gcloud container
clusters`](https://cloud.google.com/sdk/gcloud/reference/container/clusters/get-credentials).
For example:
```
gcloud container clusters get-credentials coda-infra-central1 --region us-central1 --project o1labs-192920
```

# Discover nodes in the testnet's namespace

If you do not have a particular node in mind, you can list all of the available
nodes in a namespace using `kubectl get pods`. For example, to list the nodes
on the berkeley QA net:
```
kubectl -n berkeley get pods
```

# Forward a local port to a node

Use the `kubectl port-forward` command to forward a local port. For example,
```
kubectl port-forward -n berkeley seed-1-XXXXXXXXX-XXXXX 4040:3085
```
will forward http://localhost:4040 to port 3085 on `seed-1-XXXXXXXXX-XXXXX` in
the berkeley namespace.

# Running a bash command on the node

Use the `kubectl exec` command to run a command on the testnet node. For example,
```
kubectl exec seed-1-XXXXXXXXX-XXXXX --namespace berkeley -c mina -- ls
```
will run `ls` on `seed-1-XXXXXXXXX-XXXXX` in the berkeley namespace.
