# Coda

Coda is a new cryptocurrency protocol with a lightweight, constant sized blockchain.

* [Coda Protocol Website](https://codaprotocol.com/)
* [Coda Protocol Roadmap](https://github.com/orgs/CodaProtocol/projects/1)

If you haven't seen it yet, [CONTRIBUTING.md](CONTRIBUTING.md) has information
about our development process and how to contribute. If you just want to build
Coda, this is the right file!

# Building Coda

Building Coda can be slightly involved. There are many C library dependencies that need
to be present in the system, as well as some OCaml-specific setup.

Currently, Coda only builds/runs on Linux. Building on macOS [is tracked in this issue](https://github.com/CodaProtocol/coda/issues/962).

The short version:

1. Install Docker, GNU make, and bash
2. `make USEDOCKER=TRUE dev`
3. `make USEDOCKER=TRUE deb`

Now you'll have a `_build/codaclient.deb` ready to install on Ubuntu or Debian!

## Developer Setup

### Setup Docker CE on Linux
[Ubuntu Setup Instructions](https://docs.docker.com/install/linux/docker-ce/ubuntu/)

### Setup Google Cloud gcloud
We use gcloud to store developer container images

[Instructions to install gcloud sdk](https://cloud.google.com/sdk/install)

### Take a Snapshot
If developing on a VM, now is a good time to take a snapshot and save your state.

### Login and test gcloud access

* Authorize gcloud with your o1 account\
`gcloud auth login`

* Setup docker to use google cloud registry\
`gcloud auth configure-docker`

* Setup project id (o1 internal id)\
`gcloud config set project o1labs-192920`

* Test gcloud/docker access\
`docker run -it gcr.io/o1labs-192920/hellocoda`

### Build a dev docker image
* clone this repository
* Pull down dev container  (~7GB download, go stretch your legs)\
`make docker`

### First code build

* Change your shell path to include our scripts directory.\
(REMEMBER to change the HOME and SOURCE directory to match yours)

```bash
export PATH=path/to/coda/scripts:$PATH
```

* Start a build (go stretch your arms)\
`make dev`

## Docker Image Family Tree

Container Stages:
* [ocaml/ocaml:debian-stable](https://hub.docker.com/r/ocaml/ocaml/) (community image, ~856MB) 
* ocaml407 (built by us, stored in gcr, ~1.7GB)
* ocaml-base (built by us, stored in gcr, ~7.1GB -- external dependencies and haskell)
* nanotest (built with `make docker`, used with `make dev`, ~7.8GB)

### Customizing your dev environment for autocomplete/merlin

* If you use vim, add this snippet in your vimrc to use merlin.\
(REMEMBER to change the HOME directory to match yours)

```bash
let s:ocamlmerlin="/Users/bkase/.opam/4.06.0/share/merlin"
execute "set rtp+=".s:ocamlmerlin."/vim"
execute "set rtp+=".s:ocamlmerlin."/vimbufsync"
let g:syntastic_ocaml_checkers=['merlin']
```

* In your home directory `opam init`
* In this shell, `eval $(opam config env)`
* Now `/usr/bin/opam install merlin ocp-indent core async ppx_jane ppx_deriving` (everything we depend on, that you want autocompletes for) for doc reasons
* Make sure you have `au FileType ocaml set omnifunc=merlin#Complete` in your vimrc
* Install an auto-completer (such as YouCompleteMe) and a syntastic (such syntastic or ALE)

* If you use vscode, you might like these extensions
   * [OCaml and Reason IDE](https://marketplace.visualstudio.com/items?itemName=freebroccolo.reasonml)
   * [Dune](https://marketplace.visualstudio.com/items?itemName=maelvalais.dune)

## Using the makefile

The makefile contains phony targets for all the common tasks that need to be done.
It also knows how to use Docker automatically. If you have `USEDOCKER=TRUE` in your
environment, or run `make USEDOCKER=TRUE`, it will do the real work inside a container.
You should probably use `USEDOCKER=TRUE` unless you've done the [building without docker](#building-without-docker) steps.

These are the most important `make` targets:

- `kademlia`: build the kademlia helper
- `build`: build everything
- `docker`: build the container
- `container`: restart the development container (or start it if it's not yet)
- `dev`: does `docker`, `container`, and `build`
- `test`: run the tests
- `web`: build the website, including the state explorer

We use the [dune](https://github.com/ocaml/dune/) buildsystem for our OCaml code.

NOTE: all of the `test-*` targets (including `test-all`) won't run in the container.
`test` wraps them in the container.

## Building outside docker

Coda has a variety of opam and system dependencies.

You can see [`Dockerfile-base`](/dockerfiles/Dockerfile-base) for how we
install them all in the container. To get all the opam dependencies
you need, you run `opam switch import src/opam.export`.

Some of our dependencies aren't taken from `opam`, and aren't integrated
with `dune`, so you need to add them manually:

- `opam pin add src/external/ocaml-sodium`

There are a variety of C libraries we expect to be available in the system.
These are also listed in the dockerfiles.

## Common dune tasks

To run unit tests for a single library, do `dune runtest lib/$LIBNAME`.

You can use `dune exec coda` to build and run `coda`. This is especially useful
in the form of `dune exec coda -- integration-tests $SOME_TEST`.

You might see a build error like this:

```
Error: Files external/digestif/src-c/.digestif_c.objs/digestif.cmx
       and external/digestif/src-c/.digestif_c.objs/rakia.cmx
       make inconsistent assumptions over implementation Rakia
```

You can work around it with `rm -r _build/default/src/$OFFENDING_PATH` and a rebuild.
Here, the offending path is `external/digestif/src-c/.diestif_c.objs`.

## Docker Image Family Tree

Container Stages:
* [ocaml/ocaml:debian-stable](https://hub.docker.com/r/ocaml/ocaml/) (community image, ~856MB) 
* ocaml407 (built by us, stored in gcr, ~1.7GB)
* ocaml-base (built by us, stored in gcr, ~7.1GB -- external dependencies and haskell)
* nanotest (built with `make docker`, used with `make dev`, ~7.8GB)
