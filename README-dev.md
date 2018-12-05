# Coda

Coda is a new cryptocurrency protocol with a lightweight, constant sized blockchain.

* [Developer homepage](https://codaprotocol.com/code.html)
* [Roadmap](https://github.com/orgs/CodaProtocol/projects/1)
* [Repository Readme](README.md)

If you haven't seen it yet, [CONTRIBUTING.md](CONTRIBUTING.md) has information
about our development process and how to contribute. If you just want to build
Coda, this is the right file!

## Building Coda

Building Coda can be slightly involved. There are many C library dependencies that need
to be present in the system, as well as some OCaml-specific setup.

Currently, Coda only builds/runs on Linux. Building on macOS [is tracked in this issue](https://github.com/CodaProtocol/coda/issues/962).

The short version:

 1. Start with Ubuntu 18 or run it in a [virtual machine](https://www.osboxes.org/ubuntu/)
 2. Install Docker, GNU make, and bash
 3. `make USEDOCKER=TRUE dev`
 4. `make USEDOCKER=TRUE deb`

Now you'll have a `src/_build/codaclient.deb` ready to install on Ubuntu or Debian!

### Developer Setup

#### Install or have Ubuntu 18

* [VM Images](https://www.osboxes.org/ubuntu/)

#### Setup Docker CE on Ubuntu

* [Ubuntu Setup Instructions](https://docs.docker.com/install/linux/docker-ce/ubuntu/)

#### Toolchain docker image

* Pull down developer container image  (~2GB download, go stretch your legs)

`docker pull codaprotocol/coda:toolchain-6862c63e4f3f4989db7a27c1fe79420ae0ba7397`

* Create local builder image

`make codabuilder`

* Start developer container

`make containerstart`

* Start a build (go stretch your arms)

`make USEDOCKER=TRUE build`

#### Customizing your dev environment for autocomplete/merlin

* If you use vim, add this snippet in your vimrc to use merlin. (REMEMBER to change the HOME directory to match yours)

```bash
let s:ocamlmerlin="/Users/USERNAME/.opam/4.07/share/merlin"
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

* If you use emacs, besides the `opam` packages mentioned above, also install `tuareg`, and add the following to your .emacs file:
```lisp
(let ((opam-share (ignore-errors (car (process-lines "opam" "config" "var" "share")))))
  (when (and opam-share (file-directory-p opam-share))
    ;; Register Merlin
    (add-to-list 'load-path (expand-file-name "emacs/site-lisp" opam-share))
    (load "tuareg-site-file")
    (autoload 'merlin-mode "merlin" nil t nil)
    ;; Automatically start it in OCaml buffers
    (add-hook 'tuareg-mode-hook 'merlin-mode t)
    (add-hook 'caml-mode-hook 'merlin-mode t)))
```

Emacs has a built-in autocomplete, via `M-x completion-at-point`, or simply `M-tab`. There are other
Emacs autocompletion packages; see [Emacs from scratch] (https://github.com/ocaml/merlin/wiki/emacs-from-scratch).

## Using the makefile

The makefile contains phony targets for all the common tasks that need to be done.
It also knows how to use Docker automatically. If you have `USEDOCKER=TRUE` in your
environment, or run `make USEDOCKER=TRUE`, it will do the real work inside a container.
You should probably use `USEDOCKER=TRUE` unless you've done the [building without docker](#building-without-docker) steps.

These are the most important `make` targets:

* `kademlia`: build the kademlia helper
* `build`: build everything
* `docker`: build the container
* `container`: restart the development container (or start it if it's not yet)
* `dev`: does `docker`, `container`, and `build`
* `test`: run the tests
* `web`: build the website, including the state explorer

We use the [dune](https://github.com/ocaml/dune/) buildsystem for our OCaml code.

NOTE: all of the `test-*` targets (including `test-all`) won't run in the container.
`test` wraps them in the container.

## Building outside docker

Coda has a variety of opam and system dependencies.

You can see [`Dockerfile-toolchain`](/dockerfiles/Dockerfile-toolchain) for how we
install them all in the container. To get all the opam dependencies
you need, you run `opam switch import src/opam.export`.

Some of our dependencies aren't taken from `opam`, and aren't integrated
with `dune`, so you need to add them manually:

* `opam pin add src/external/ocaml-sodium`
* `opam pin add src/external/ocaml-rocksdb`

There are a variety of C libraries we expect to be available in the system.
These are also listed in the dockerfiles.

## Common dune tasks

To run unit tests for a single library, do `dune runtest lib/$LIBNAME`.

You can use `dune exec coda` to build and run `coda`. This is especially useful
in the form of `dune exec coda -- integration-tests $SOME_TEST`.

You might see a build error like this:

```text
Error: Files external/digestif/src-c/.digestif_c.objs/digestif.cmx
       and external/digestif/src-c/.digestif_c.objs/rakia.cmx
       make inconsistent assumptions over implementation Rakia
```

You can work around it with `rm -r src/_build/default/src/$OFFENDING_PATH` and a rebuild.
Here, the offending path is `external/digestif/src-c/.diestif_c.objs`.

## Docker Image Family Tree

Container Stages:

* Stage 0: Initial Image [ocaml/opam2:debian-9-ocaml-4.07](https://hub.docker.com/r/ocaml/opam2/) (opam community image, ~880MB)
* Stage 1: [coda toolchain](https://github.com/CodaProtocol/coda/blob/master/dockerfiles/Dockerfile-toolchain) (built by us, stored on docker hub, ~2GB compressed)
* Stage 2: [codabuilder](https://github.com/CodaProtocol/coda/blob/master/dockerfiles/Dockerfile) (built with `make codabuilder`, used with `make build`, ~2GB compressed)
