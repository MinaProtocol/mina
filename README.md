# How to Testbridge

### Docker image related setup

1. If you or a colleague has changed any opam dependencies: `make update-deps`.
2. Update the relevant containers `make nanobit-googlecloud && make testbridge-googlecloud`.

### Gcloud related setup

1. Install `gcloud`, `kubectl`. If you use the docker dev environment, just run `make dev`.
2. `gcloud auth login` (follow the instructions)
3. `gcloud set config project o1labs-192920`

### Kubernetes related setup

1. Get kubectl to work: `gcloud container clusters get-credentials testbridge-n1-standard-2 --zone us-west1-a`
2. Check to see if any pods are "Running": `kubectl get pods`
3. If they are all "Pending", it is possible you need to cleanup `./lib/testbridge/cleanup.sh` (goto 2)
   Else they are missing, you may need to resize the cluster:
   `kubectl get nodes` (you should see 2), otherwise: `gcloud container clusters resize testbridge-n1-standard-2 --size=2 --zone us-west1-a`
4. Now you can run a testbridge: (ex) `run-in-docker lib/nanobit_testbridge/run.sh recent_sca/ ../../_build/install/default/bin/nanobit_testbridge_recent_sca 4 gcr.io/o1labs-192920/testbridge-nanobit:latest`
5. If you see `have (x/4) pods`, just wait until it's `(4/4)`. Keep restarting whenever it times out.
6. Finally, things may work.

### Cleaning up

1. Run `./lib/testbridge/cleanup.sh`
2. Make the cluster size=0 so we don't burn money `gcloud container clusters resize testbridge-n1-standard-2 --size=0 --zone us-west1-a`

### If things aren't working

1. Can you spawn a bash shell in a kubernetes pod?
    List the pods: `kubectl get pods`, copy one down here:
    `kubectl exec -it testbridge-fwzgsxbvyj-4178240947-10vsn -- /bin/bash`
2. Is there anything interesting in the logs?
    `jbuilder exec fetch_logs`, then `cat /tmp/testbridge_logs/<your-pod-name>`
   If you see a build failure, but no failure locally:
    a. Did you need to remake the Docker containers? Esp. base? If so, make sure you also cleanup/redeploy pods


