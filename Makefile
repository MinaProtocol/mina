all : clean docker container build

.PHONY : all dev

clean :
	@echo "Removing previous build artifacts"
	@rm -rf _build

## Containers and container management

docker :
	@./rebuild-docker.sh nanotest Dockerfile

ci-base-docker:
	./rebuild-docker.sh o1labs/ci-base Dockerfile-ci-base

nanobit-docker :
	./rebuild-docker.sh nanobit Dockerfile-nanobit

base-docker :
	./rebuild-docker.sh ocaml-base Dockerfile-base

base-minikube :
	./rebuild-minikube.sh ocaml-base Dockerfile-base

nanobit-minikube :
	./rebuild-minikube.sh nanobit Dockerfile-nanobit

base-googlecloud :
	./rebuild-googlecloud.sh ocaml-base Dockerfile-base $(shell git rev-parse HEAD)

nanobit-googlecloud :
	./rebuild-googlecloud.sh nanobit Dockerfile-nanobit

ocaml407-googlecloud:
	./rebuild-googlecloud.sh ocaml407 Dockerfile-ocaml407

pull-ocaml407-googlecloud:
	gcloud docker -- pull gcr.io/o1labs-192920/ocaml407:latest

update-deps: base-googlecloud
	./rewrite-from-dockerfile.sh ocaml-base $(shell git rev-parse HEAD)

container :
	@./container.sh restart


## Code

kademlia :
	@if [ "$(USEDOCKER)" = "TRUE" ]; then \
		./scripts/run-in-docker bash -c 'cd app/kademlia-haskell && nix-build release2.nix' ; \
	else \
		bash -c 'cd app/kademlia-haskell && nix-build release2.nix' ; \
	fi

build :
	@echo "Starting Build"
	@if [ "$(USEDOCKER)" = "TRUE" ]; then \
		./scripts/run-in-docker dune build ; \
	else \
		echo "WARN: Running OUTSIDE docker - try: USEDOCKER=TRUE make ..." ; \
                ulimit -s 65536 ; \
		dune build ; \
	fi
	@echo "Build complete"

dev : docker container build


## Artifacts 

deb :
	@if [ "$(USEDOCKER)" = "TRUE" ]; then \
		./scripts/run-in-docker ./rebuild-deb.sh ; \
	else \
		./rebuild-deb.sh ; \
	fi
	@mkdir /tmp/artifacts
	@cp _build/codaclient.deb /tmp/artifacts/.

codaslim :
	@# FIXME: Could not reference .deb file in the sub-dir in the docker build
	@cp _build/codaclient.deb .
	@./rebuild-docker.sh codaslim Dockerfile-codaslim
	@rm codaclient.deb


## Tests

test :
	@if [ "$(USEDOCKER)" = "TRUE" ]; then \
		./scripts/run-in-docker make test-all ; \
	else	\
		echo "WARN: Running OUTSIDE docker - try: USEDOCKER=TRUE make ..." ; \
		make test-all ; \
	fi

test-all : test-runtest test-full test-codapeers test-coda-block-production test-transaction-snark-profiler

myprocs:=$(shell nproc --all)
test-runtest :
	dune runtest --verbose -j$(myprocs)

test-full :
	dune exec cli -- full-test

test-codapeers :
	dune exec cli -- coda-peers-test

test-coda-block-production :
	dune exec cli -- coda-block-production-test

test-transaction-snark-profiler :
	dune exec cli -- transaction-snark-profiler -check-only


## Lint

reformat:
	dune exec app/reformat/reformat.exe -- -path .

check-format:
	dune exec app/reformat/reformat.exe -- -path . -check
