# Coda

Coda is a new cryptocurrency protocol with a lightweight, constant sized blockchain.

* [Coda Protocol Website](https://codaprotocol.com/)
* [Coda Protocol Roadmap](https://github.com/orgs/CodaProtocol/projects/1)

# Developer Setup

## Setup Docker CE on Linux
[Ubuntu Setup Instructions](https://docs.docker.com/install/linux/docker-ce/ubuntu/)

## Setup Google Cloud gcloud
We use gcloud to store developer container images

[Instructions to install gcloud sdk](https://cloud.google.com/sdk/install)
(also install kubectl)

## Take a Snapshot
If developing on a VM, now is a good time to take a snapshot and save your state.

## Login and test gcloud access

* Authorize gcloud with your o1 account\
`gcloud auth login`

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

## Building outside docker
You can see the dockerfiles for the opam deps we need. You can also
do `opam switch import opam.export`. You'll also need to

`opam pin add external/ocaml-sodium`

## First code build

* Change your shell path to include our scripts directory.\
(REMEMBER to change the HOME and SOURCE directory to match yours)

```bash
export PATH=path/to/coda/scripts:$PATH
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

# License

This repository is distributed under the terms of the Apache 2.0 license,
available in the LICENSE fail and online at
https://www.apache.org/licenses/LICENSE-2.0. Commits older than 2018-10-03 do
not have a LICENSE file or this notice, but are distributed under the same terms.
