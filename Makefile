########################################
## Docker Wrapper 
## Hint: export USEDOCKER=TRUE

MYUID = $(shell id -u)
DOCKERNAME = nanotest-$(MYUID)

ifeq ($(USEDOCKER),TRUE)
 $(info INFO Using Docker Named $(DOCKERNAME))
 WRAP = docker exec -it $(DOCKERNAME)
else
 $(info INFO Not using Docker)
 WRAP =
endif


########################################
## Code

all: clean docker container build

clean:
	$(info Removing previous build artifacts)
	@rm -rf _build

kademlia:
	@# FIXME: Bash wrap here is awkward but required to get nix-env
	$(WRAP) bash -c "source ~/.profile && cd app/kademlia-haskell && nix-build release2.nix"

# Alias
dht: kademlia

build:
	$(info Starting Build)
	ulimit -s 65536
	$(WRAP) dune build 
	$(info Build complete)

dev: docker container build

# snark tunable

withsnark:
	sed -i '/let with_snark =/c\let with_snark = true' lib/nanobit_base/insecure.ml

withoutsnark:
	sed -i '/let with_snark =/c\let with_snark = false' lib/nanobit_base/insecure.ml

showsnark:
	@grep 'let with_snark' lib/nanobit_base/insecure.ml

########################################
## Lint

reformat:
	$(WRAP) dune exec app/reformat/reformat.exe -- -path .

check-format:
	$(WRAP) dune exec app/reformat/reformat.exe -- -path . -check


########################################
## Containers and container management

docker:
	./rebuild-docker.sh nanotest Dockerfile

ci-base-docker:
	./rebuild-docker.sh o1labs/ci-base Dockerfile-ci-base

nanobit-docker:
	./rebuild-docker.sh nanobit Dockerfile-nanobit

base-docker:
	./rebuild-docker.sh ocaml-base Dockerfile-base

base-minikube:
	./rebuild-minikube.sh ocaml-base Dockerfile-base

nanobit-minikube:
	./rebuild-minikube.sh nanobit Dockerfile-nanobit

base-googlecloud:
	./rebuild-googlecloud.sh ocaml-base Dockerfile-base $(shell git rev-parse HEAD)

nanobit-googlecloud:
	./rebuild-googlecloud.sh nanobit Dockerfile-nanobit

ocaml407-googlecloud:
	./rebuild-googlecloud.sh ocaml407 Dockerfile-ocaml407

pull-ocaml407-googlecloud:
	gcloud docker -- pull gcr.io/o1labs-192920/ocaml407:latest

update-deps: base-googlecloud
	./rewrite-from-dockerfile.sh ocaml-base $(shell git rev-parse HEAD)

container:
	@./container.sh restart

########################################
## Artifacts 

deb:
	$(WRAP) ./rebuild-deb.sh
	@mkdir /tmp/artifacts
	@cp _build/codaclient.deb /tmp/artifacts/.

codaslim:
	@# FIXME: Could not reference .deb file in the sub-dir in the docker build
	@cp _build/codaclient.deb .
	@./rebuild-docker.sh codaslim Dockerfile-codaslim
	@rm codaclient.deb


########################################
## Tests

test:
	$(WRAP) make test-all

test-all: | test-runtest \
			test-sigs \
			test-stakes 

test-runtest: SHELL := /bin/bash
test-runtest:
	source test_all.sh ; run_unit_tests

test-sigs: SHELL := /bin/bash
test-sigs:
	source test_all.sh ; CODA_CONSENSUS_METHOD=proof_of_signature run_integration_tests

test-stakes: SHELL := /bin/bash
test-stakes:
	source test_all.sh ; CODA_CONSENSUS_METHOD=proof_of_stake run_integration_tests


########################################
# To avoid unintended conflicts with file names, always add to .PHONY
# unless there is a reason not to.
# https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html
# HACK: cat Makefile | egrep '^\w.*' | sed 's/:/ /' | awk '{print $1}' | grep -v myprocs | sort | xargs
.PHONY: all base-docker base-googlecloud base-minikube build check-format ci-base-docker clean codaslim container deb dev docker kademlia nanobit-docker nanobit-googlecloud nanobit-minikube ocaml407-googlecloud pull-ocaml407-googlecloud reformat test test-all test-coda-block-production-sig test-coda-block-production-stake test-codapeers-sig test-codapeers-stake test-full-sig test-full-stake test-runtest test-transaction-snark-profiler-sig test-transaction-snark-profiler-stake update-deps
