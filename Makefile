########################################
## Docker Wrapper 
## Hint: export USEDOCKER=TRUE

GITHASH = $(shell git rev-parse --short=8 HEAD)
GITLONGHASH = $(shell git rev-parse HEAD)

MYUID = $(shell id -u)
DOCKERNAME = codabuilder-$(MYUID)

ifeq ($(DUNE_PROFILE),)
DUNE_PROFILE := dev
endif

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
	cd src ; $(WRAPSRC) env CODA_COMMIT_SHA1=$(GITLONGHASH) dune build --profile=$(DUNE_PROFILE)
	$(info Build complete)

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
	cd src; $(WRAPSRC) dune exec --profile=$(DUNE_PROFILE) app/reformat/reformat.exe -- -path .

check-format:
	cd src; $(WRAPSRC) dune exec --profile=$(DUNE_PROFILE) app/reformat/reformat.exe -- -path . -check

########################################
## Containers and container management

# customized local docker
docker:
	docker build --file dockerfiles/Dockerfile --tag codabuilder .

# push steps require auth on docker hub
docker-toolchain:
	@if git diff-index --quiet HEAD ; then \
		docker build --file dockerfiles/Dockerfile-toolchain --tag codaprotocol/coda:toolchain-$(GITLONGHASH) . ;\
		docker tag  codaprotocol/coda:toolchain-$(GITLONGHASH) codaprotocol/coda:toolchain-latest ;\
		docker push codaprotocol/coda:toolchain-$(GITLONGHASH) ;\
		docker push codaprotocol/coda:toolchain-latest ;\
	else \
		echo "Repo is dirty, commit first." ;\
	fi

update-deps:
	./scripts/update-toolchain-references.sh $(GITLONGHASH)
	cd .circleci; python2 render.py > config.yml

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
	source scripts/test_all.sh ; cd src ; run_all_sig_integration_tests

test-stakes: SHELL := /bin/bash
test-stakes:
	source scripts/test_all.sh ; cd src ; run_all_stake_integration_tests

test-withsnark: SHELL := /bin/bash
test-withsnark:
	source scripts/test_all.sh ; cd src; CODA_CONSENSUS_MECHANISM=proof_of_signature WITH_SNARKS=true run_integration_test full-test

web:
	./scripts/web.sh


########################################
# To avoid unintended conflicts with file names, always add to .PHONY
# unless there is a reason not to.
# https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html
# HACK: cat Makefile | egrep '^\w.*' | sed 's/:/ /' | awk '{print $1}' | grep -v myprocs | sort | xargs
.PHONY: all base-docker base-googlecloud base-minikube build check-format ci-base-docker clean codaslim container deb dev docker kademlia coda-docker coda-googlecloud coda-minikube ocaml407-googlecloud pull-ocaml407-googlecloud reformat test test-all test-coda-block-production-sig test-coda-block-production-stake test-codapeers-sig test-codapeers-stake test-full-sig test-full-stake test-runtest test-transaction-snark-profiler-sig test-transaction-snark-profiler-stake update-deps bundle-keys update-keys render-circleci check-render-circleci
