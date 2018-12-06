########################################
## Docker Wrapper
## Hint: export USEDOCKER=TRUE

GITHASH = $(shell git rev-parse --short=8 HEAD)
GITLONGHASH = $(shell git rev-parse HEAD)

MYUID = $(shell id -u)
DOCKERNAME = codabuilder-$(MYUID)

# Unique signature of kademlia code tree
KADEMLIA_SIG = $(shell cd src/app/kademlia-haskell ; find . -type f -print0  | xargs -0 sha1sum | sort | sha1sum | cut -f 1 -d ' ')

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
# Coverage directory

COVERAGE_DIR=_coverage

########################################
## Code

all: clean codabuilder containerstart build

clean:
	$(info Removing previous build artifacts)
	@rm -rf src/_build
	@rm -rf src/$(COVERAGE_DIR)

kademlia:
	@# FIXME: Bash wrap here is awkward but required to get nix-env
	bash -c "source ~/.profile && cd src/app/kademlia-haskell && nix-build release2.nix"

# Alias
dht: kademlia

build:
	$(info Starting Build)
	ulimit -s 65536
	cd src ; $(WRAPSRC) env CODA_COMMIT_SHA1=$(GITLONGHASH) dune build --profile=$(DUNE_PROFILE)
	$(info Build complete)

dev: docker container build

########################################
## Lint

reformat:
	cd src; $(WRAPSRC) dune exec --profile=$(DUNE_PROFILE) app/reformat/reformat.exe -- -path .

check-format:
	cd src; $(WRAPSRC) dune exec --profile=$(DUNE_PROFILE) app/reformat/reformat.exe -- -path . -check

########################################
## Merlin fixup for docker builds

merlin-fixup:
ifeq ($(USEDOCKER),TRUE)
	@echo "Fixing up .merlin files for Docker build"
	@./scripts/merlin-fixup.sh
else
	@echo "Not building in Docker, .merlin files unchanged"
endif

########################################
## Containers and container management


# push steps require auth on docker hub
docker-toolchain:
	@if git diff-index --quiet HEAD ; then \
		docker build --no-cache --file dockerfiles/Dockerfile-toolchain --tag codaprotocol/coda:toolchain-$(GITLONGHASH) . && \
		docker tag  codaprotocol/coda:toolchain-$(GITLONGHASH) codaprotocol/coda:toolchain-latest && \
		docker push codaprotocol/coda:toolchain-$(GITLONGHASH) && \
		docker push codaprotocol/coda:toolchain-latest ;\
	else \
		echo "Repo has uncommited changes, commit first to set hash." ;\
	fi

docker-toolchain-rust:
	@if git diff-index --quiet HEAD ; then \
		docker build --file dockerfiles/Dockerfile-toolchain-rust --tag codaprotocol/coda:toolchain-rust-$(GITLONGHASH) . && \
		docker tag  codaprotocol/coda:toolchain-rust-$(GITLONGHASH) codaprotocol/coda:toolchain-rust-latest && \
		docker push codaprotocol/coda:toolchain-rust-$(GITLONGHASH) && \
		docker push codaprotocol/coda:toolchain-rust-latest ;\
	else \
		echo "Repo has uncommited changes, commit first to set hash." ;\
	fi

# All in one step to build toolchain and binary for kademlia
docker-toolchain-haskell:
	@echo "Building codaprotocol/coda:toolchain-haskell-$(KADEMLIA_SIG)" ;\
    docker build --file dockerfiles/Dockerfile-toolchain-haskell --tag codaprotocol/coda:toolchain-haskell-$(KADEMLIA_SIG) . ;\
    echo  'Extracting deb package' ;\
    mkdir -p src/_build ;\
    docker run --rm --entrypoint cat codaprotocol/coda:toolchain-haskell-$(KADEMLIA_SIG) /src/coda-kademlia.deb > src/_build/coda-kademlia.deb

toolchains: docker-toolchain docker-toolchain-rust docker-toolchain-haskell

update-deps:
	./scripts/update-toolchain-references.sh $(GITLONGHASH)
	cd .circleci; python2 render.py > config.yml

# Local 'codabuilder' docker image (based off docker-toolchain)
codabuilder:
	docker build --file dockerfiles/Dockerfile --tag codabuilder .

# Restarts codabuilder
containerstart:
	@./scripts/container.sh restart

########################################
## Artifacts

deb:
	$(WRAP) ./scripts/rebuild-deb.sh
	@mkdir -p /tmp/artifacts
	@cp src/_build/coda.deb /tmp/artifacts/.

# deb-s3 https://github.com/krobertson/deb-s3
DEBS3 = deb-s3 upload --s3-region=us-west-2 --bucket packages.o1test.net --preserve-versions --cache-control=120

publish_kademlia_deb:
	@if [ "$(CIRCLE_BRANCH)" = "master" ] ; then \
		$(DEBS3) --codename stable   --component main src/_build/coda-kademlia.deb ; \
	else \
		$(DEBS3) --codename unstable --component main src/_build/coda-kademlia.deb ; \
	fi

publish_deb:
	@if [ "$(CIRCLE_BRANCH)" = "master" ] ; then \
		$(DEBS3) --codename stable   --component main src/_build/coda.deb ; \
	else \
		$(DEBS3) --codename unstable --component main src/_build/coda.deb ; \
	fi

publish_debs: publish_deb publish_kademlia_deb

provingkeys:
	@if [ "$(CIRCLE_BRANCH)" = "master" ] ; then \
		$(WRAP) tar -cvjf src/_build/coda_cache_dir_$(GITHASH).tar.bz2  /tmp/coda_cache_dir ; \
		mkdir -p /tmp/artifacts ; \
		cp src/_build/coda_cache_dir*.tar.bz2 /tmp/artifacts/. ; \
	else \
		echo "Skipping because not on master" ; \
	fi

genesiskeys:
	@mkdir -p /tmp/artifacts
	@cp src/_build/default/lib/coda_base/sample_keypairs.ml /tmp/artifacts/.

codaslim:
	@# FIXME: Could not reference .deb file in the sub-dir in the docker build
	@cp src/_build/coda.deb .
	@./scripts/rebuild-docker.sh codaslim dockerfiles/Dockerfile-codaslim
	@rm coda.deb

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
	source scripts/test_all.sh ; cd src; CODA_PROPOSAL_INTERVAL=30000 WITH_SNARKS=true DUNE_PROFILE=test_snark run_integration_test full-test

web:
	./scripts/web.sh

########################################
# Coverage testing and output

test-coverage: SHELL := /bin/bash
test-coverage:
	source scripts/test_all.sh ; cd src ; run_unit_tests_with_coverage

# we don't depend on test-coverage, which forces a run of all unit tests
coverage-html:
ifeq ($(shell find src/_build/default -name bisect\*.out),"")
	echo "No coverage output; run make test-coverage"
else
	cd src && bisect-ppx-report -I _build/default/ -html $(COVERAGE_DIR) `find . -name bisect\*.out`
endif

coverage-text:
ifeq ($(shell find src/_build/default -name bisect\*.out),"")
	echo "No coverage output; run make test-coverage"
else
	cd src && bisect-ppx-report -I _build/default/ -text $(COVERAGE_DIR)/coverage.txt `find . -name bisect\*.out`
endif

coverage-coveralls:
ifeq ($(shell find src/_build/default -name bisect\*.out),"")
	echo "No coverage output; run make test-coverage"
else
	cd src && bisect-ppx-report -I _build/default/ -coveralls $(COVERAGE_DIR)/coveralls.json `find . -name bisect\*.out`
endif

########################################
# Diagrams for documentation

transition_frontier_diagram: SHELL := /bin/bash
transition_frontier_diagram:
	cd docs/res; pdflatex transition_frontier_diagram.tex && convert -density 600x600 transition_frontier_diagram.pdf -quality 90 -resize 1080x800 transition_frontier_diagram.png

diagrams: transition_frontier_diagram

########################################
# To avoid unintended conflicts with file names, always add to .PHONY
# unless there is a reason not to.
# https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html
# HACK: cat Makefile | egrep '^\w.*' | sed 's/:/ /' | awk '{print $1}' | grep -v myprocs | sort | xargs
.PHONY: all base-docker base-googlecloud base-minikube build check-format ci-base-docker clean codaslim containerstart deb dev codabuilder kademlia coda-docker coda-googlecloud coda-minikube ocaml407-googlecloud pull-ocaml407-googlecloud reformat test test-all test-coda-block-production-sig test-coda-block-production-stake test-codapeers-sig test-codapeers-stake test-full-sig test-full-stake test-runtest test-transaction-snark-profiler-sig test-transaction-snark-profiler-stake update-deps render-circleci check-render-circleci docker-toolchain-rust toolchains transition_frontier_diagram diagrams
