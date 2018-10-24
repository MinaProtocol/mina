########################################
## Docker Wrapper 
## Hint: export USEDOCKER=TRUE

GITHASH = $(shell git rev-parse --short=8 HEAD)
GITLONGHASH = $(shell git rev-parse HEAD)

MYUID = $(shell id -u)
DOCKERNAME = nanotest-$(MYUID)

ifeq ($(USEDOCKER),TRUE)
 $(info INFO Using Docker Named $(DOCKERNAME))
 WRAP = docker exec -it $(DOCKERNAME)
 WRAPSRC = docker exec --workdir /home/opam/app/src -it $(DOCKERNAME)
else
 $(info INFO Not using Docker)
 WRAP =
endif


########################################
## Code

all: clean docker container build

clean:
	$(info Removing previous build artifacts)
	@rm -rf src/_build

kademlia:
	@# FIXME: Bash wrap here is awkward but required to get nix-env
	$(WRAP) bash -c "source ~/.profile && cd src/app/kademlia-haskell && nix-build release2.nix"

# Alias
dht: kademlia

build:
	$(info Starting Build)
	ulimit -s 65536
	cd src ; $(WRAPSRC) env CODA_COMMIT_SHA1=$(GITLONGHASH) dune build
	$(info Build complete)

withupdates:
	sed -i '/let force_updates = /c\let force_updates = true' src/app/cli/src/coda.ml

withoutupdates:
	sed -i '/let force_updates = /c\let force_updates = false' src/app/cli/src/coda.ml

dev: docker container build

# snark tunable

withsnark:
	sed -i '/let with_snark =/c\let with_snark = true' src/lib/coda_base/insecure.ml

withoutsnark:
	sed -i '/let with_snark =/c\let with_snark = false' src/lib/coda_base/insecure.ml

showsnark:
	@grep 'let with_snark' src/lib/coda_base/insecure.ml

# gets proiving keys -- only used in CI
withkeys:
	sudo -E scripts/get_keys.sh

########################################
## Lint

reformat:
	cd src; $(WRAPSRC) dune exec app/reformat/reformat.exe -- -path .

check-format:
	cd src; $(WRAPSRC) dune exec app/reformat/reformat.exe -- -path . -check


########################################
## Containers and container management

docker:
	./scripts/rebuild-docker.sh nanotest dockerfiles/Dockerfile

ci-base-docker:
	./scripts/rebuild-docker.sh o1labs/ci-base dockerfiles/Dockerfile-ci-base

coda-docker:
	./scripts/rebuild-docker.sh coda dockerfiles/Dockerfile-coda

base-docker:
	./scripts/rebuild-docker.sh ocaml-base dockerfiles/Dockerfile-base

base-minikube:
	./scripts/rebuild-minikube.sh ocaml-base dockerfiles/Dockerfile-base

coda-minikube:
	./scripts/rebuild-minikube.sh coda dockerfiles/Dockerfile-coda

base-googlecloud:
	./scripts/rebuild-googlecloud.sh ocaml-base dockerfiles/Dockerfile-base $(GITLONGHASH)

coda-googlecloud:
	./scripts/rebuild-googlecloud.sh coda dockerfiles/Dockerfile-coda

ocaml407-googlecloud:
	./scripts/rebuild-googlecloud.sh ocaml407 dockerfiles/Dockerfile-ocaml407

pull-ocaml407-googlecloud:
	gcloud docker -- pull gcr.io/o1labs-192920/ocaml407:latest

update-deps: base-googlecloud
	./scripts/rewrite-from-dockerfile.sh ocaml-base $(GITLONGHASH)

container:
	@./scripts/container.sh restart

########################################
## Artifacts 

deb:
	$(WRAP) ./scripts/rebuild-deb.sh
	@mkdir -p /tmp/artifacts
	@cp src/_build/codaclient.deb /tmp/artifacts/.

provingkeys:
	$(WRAP) tar -cvjf src/_build/coda_cache_dir_$(GITHASH).tar.bz2  /var/lib/coda
	@mkdir -p /tmp/artifacts
	@cp src/_build/coda_cache_dir*.tar.bz2 /tmp/artifacts/.

genesiskeys:
	@mkdir -p /tmp/artifacts
	@cp src/_build/default/lib/coda_base/sample_keypairs.ml /tmp/artifacts/.

codaslim:
	@# FIXME: Could not reference .deb file in the sub-dir in the docker build
	@cp src/_build/codaclient.deb .
	@./scripts/rebuild-docker.sh codaslim dockerfiles/Dockerfile-codaslim
	@rm codaclient.deb

src/_build/keys-$(GITLONGHASH).tar.bz2: withsnark build
ifneq (,$(wildcard /var/lib/coda))
	$(error "Trying to bundle keys but /var/lib/coda exists so they won't be built")
endif
	$(WRAP) tar -cvjf src/_build/keys-$(GITLONGHASH).tar.bz2  /tmp/coda_cache_dir

bundle-keys: withsnark build src/_build/keys-$(GITLONGHASH).tar.bz2
	gsutil cp -n src/_build/keys-$(GITLONGHASH).tar.bz2 gs://proving-keys-stable/keys-$(GITLONGHASH).tar.bz2

update-keys:
ifeq (,$(wildcard src/_build/keys-$(GITLONGHASH).tar.bz2))
	$(error "Trying to update keys, but I'm not sure we've bundled them yet")
endif
	perl -i -p -e "s,PINNED_KEY_COMMIT=.*,PINNED_KEY_COMMIT=$(GITLONGHASH)," scripts/get_keys.sh

########################################
## Tests

render-circleci:
	cd .circleci; python2 render.py > config.yml

check-render-circleci:
	cd .circleci; ./check_render.sh

test:
	$(WRAP) make test-all

test-all: | test-runtest \
			test-sigs \
			test-stakes 

test-runtest: SHELL := /bin/bash
test-runtest:
	source scripts/test_all.sh ; cd src ; run_unit_tests

test-sigs: SHELL := /bin/bash
test-sigs:
	source scripts/test_all.sh ; cd src ; CODA_CONSENSUS_METHOD=proof_of_signature run_integration_tests

test-stakes: SHELL := /bin/bash
test-stakes:
	source scripts/test_all.sh ; cd src ; CODA_CONSENSUS_METHOD=proof_of_stake run_integration_tests

web:
	./scripts/web.sh


########################################
# To avoid unintended conflicts with file names, always add to .PHONY
# unless there is a reason not to.
# https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html
# HACK: cat Makefile | egrep '^\w.*' | sed 's/:/ /' | awk '{print $1}' | grep -v myprocs | sort | xargs
.PHONY: all base-docker base-googlecloud base-minikube build check-format ci-base-docker clean codaslim container deb dev docker kademlia coda-docker coda-googlecloud coda-minikube ocaml407-googlecloud pull-ocaml407-googlecloud reformat test test-all test-coda-block-production-sig test-coda-block-production-stake test-codapeers-sig test-codapeers-stake test-full-sig test-full-stake test-runtest test-transaction-snark-profiler-sig test-transaction-snark-profiler-stake update-deps bundle-keys update-keys render-circleci check-render-circleci
