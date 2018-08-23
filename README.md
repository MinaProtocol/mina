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

* Authorize gcloud with your o1 account\
`gclould auth login`

* Setup docker to use google cloud registry\
`gcloud auth configure-docker`

* Setup project id (o1 internal id)\
`gcloud config set project o1labs-192920`

* Test gcloud/docker access\
`docker run -it gcr.io/o1labs-192920/hellocoda`

## Build a dev docker image
* clone this repository 
* Pull down dev container  (~7GB download, go stretch your legs)\
`make docker` 

## First code build

* Change your shell path to include our scripts directory.\
(REMEMBER to change the HOME and SOURCE directory to match yours)

```bash
export PATH=~/src/nanobit/scripts:$PATH
```

* Start a build (go stretch your arms)\
`make dev`

## Customizing your dev environment for autocomplete/merlin

* If you use vim, add this snippet in your vimrc to use merlin.\
(REMEMBER to change the HOME directory to match yours)

```bash
let s:ocamlmerlin="/Users/bkase/.opam/4.06.0/share/merlin"
execute "set rtp+=".s:ocamlmerlin."/vim"
execute "set rtp+=".s:ocamlmerlin."/vimbufsync"
let g:syntastic_ocaml_checkers=['merlin']
```

* In your home directory `opam init`
* In this shell, `eval \`opam config env\``* Now `/usr/bin/opam install merlin ocp-indent core async ppx_jane ppx_deriving` (everything we depend on, that you want autocompletes for) for doc reasons
* Make sure you have `au FileType ocaml set omnifunc=merlin#Complete` in your vimrc
* Install an auto-completer (such as YouCompleteMe) and a syntastic (such syntastic or ALE)

* If you use vscode, you might like these extensions
   * [OCaml and Reason IDE](https://marketplace.visualstudio.com/items?itemName=freebroccolo.reasonml)
   * [Dune](https://marketplace.visualstudio.com/items?itemName=maelvalais.dune)

# Docker Image Family Tree

Container Stages:
* [ocaml/ocaml:debian-stable](https://hub.docker.com/r/ocaml/ocaml/) (community image, ~856MB) 
* ocaml407 (built by us, stored in gcr, ~1.7GB)
* ocaml-base (built by us, stored in gcr, ~7.1GB -- external dependancies and haskell)
* nanotest (built with `make docker`, used with `make dev`, ~7.8GBm)

# ~~How to Testbridge~~
FIXME: Everything Testbridge is Deprecated

### Docker image related setup

* If you or a colleague has changed any opam dependencies: `make update-deps`.
* Update the relevant containers `make nanobit-googlecloud && make testbridge-googlecloud`.

### Gcloud related setup

* Install `gcloud`, `kubectl`. If you use the docker dev environment, just run `make dev`.
* `gcloud auth login` (follow the instructions)
* `gcloud config set project o1labs-192920`

### Kubernetes related setup

* Get kubectl to work: `gcloud container clusters get-credentials testbridge-n1-standard-2 --zone us-west1-a`
* Check to see if any pods are "Running": `kubectl get pods`
* If they are all "Pending", it is possible you need to cleanup `./lib/testbridge/cleanup.sh` (goto 2)
   Else they are missing, you may need to resize the cluster:
   `kubectl get nodes` (you should see 2), otherwise: `gcloud container clusters resize testbridge-n1-standard-2 --size=2 --zone us-west1-a`
* Now you can run a testbridge: (ex) `run-in-docker lib/nanobit_testbridge/run.sh recent_sca/ ../../_build/install/default/bin/nanobit_testbridge_recent_sca 4 gcr.io/o1labs-192920/testbridge-nanobit:latest`
* If you see `have (x/4) pods`, just wait until it's `(4/4)`. Keep restarting whenever it times out.
* Finally, things may work.

### Cleaning up
* Run `./lib/testbridge/cleanup.sh`
* Make the cluster size=0 so we don't burn money `gcloud container clusters resize testbridge-n1-standard-2 --size=0 --zone us-west1-a`

### If things aren't working

* Can you spawn a bash shell in a kubernetes pod?
    List the pods: `kubectl get pods`, copy one down here:
    `kubectl exec -it testbridge-fwzgsxbvyj-4178240947-10vsn -- /bin/bash`
* Is there anything interesting in the logs?
    `jbuilder exec fetch_logs`, then `cat /tmp/testbridge_logs/<your-pod-name>`
   If you see a build failure, but no failure locally:
    a. Did you need to remake the Docker containers? Esp. base? If so, make sure you also cleanup/redeploy pods
