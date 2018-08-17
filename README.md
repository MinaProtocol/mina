# Developer Setup

## ~~Setup Docker CE for Mac~~
(WARNING: Docker for Mac is not reccomended for builds as it is slower than local builds)

1. ~~Install docker for mac~~
1. ~~Click the whale dude in your tray and go to preferences~~
1. ~~Change the disk space to >=128GB~~
1. ~~Change the RAM to >=8GB~~
1. ~~Change the cores to more (so your builds are faster)~~

## Setup Docker CE on Linux
[Ubuntu Setup Instructions](https://docs.docker.com/install/linux/docker-ce/ubuntu/)

## Setup Google Cloud gcloud/kubectl 
We use gcloud to store developer container images

[Instructions to install gcloud sdk](https://cloud.google.com/sdk/install)
(also install kubectl)

## Take a Snapshot
If developing on a VM, now is a good time to take a snapshot and save your state.

## Login and test gcloud access

1. Setup docker to use google cloud registry
`gcloud auth configure-docker`

1. Setup project id (o1 internal id)
`gcloud config set project o1labs-192920`

1. Test gcloud/docker access
`docker run -it gcr.io/o1labs-192920/hellocoda`

## Build a dev docker image
1. clone this repository 
1. run `make docker` to pull down our dev container image (~7GB download, go strecth)

## First build

1. Change your shell path to include our scripts directory.
(REMEMBER to change the HOME and SOURCE directory to match yours)

```bash
export PATH=~/src/nanobit/scripts:$PATH
```

2. Start a build `make dev` (go stretch)

## Customizing your developer environment

1. If you use vim, add this in your vimrc to use merlin. 
(REMEMBER to change the HOME directory to match yours)

```bash
let s:ocamlmerlin="/Users/bkase/.opam/4.06.0/share/merlin"
execute "set rtp+=".s:ocamlmerlin."/vim"
execute "set rtp+=".s:ocamlmerlin."/vimbufsync"
let g:syntastic_ocaml_checkers=['merlin']
```

2. In your home directory `opam init`
1. In this shell, `eval \`opam config env\``
1. Now `/usr/bin/opam install merlin ocp-indent core async ppx_jane ppx_deriving` (everything we depend on, that you want autocompletes for) for doc reasons
1. Make sure you have `au FileType ocaml set omnifunc=merlin#Complete` in your vimrc
1. Install an auto-completer (such as YouCompleteMe) and a syntastic (such syntastic or ALE)


# ~~How to Testbridge~~
FIXME: Deprecated

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
