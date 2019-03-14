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
 WRAPSRC = docker exec --workdir /home/opam/app/src -t $(DOCKERNAME)
else
 $(info INFO Not using Docker)
 WRAP =
endif

########################################
## Coverage directory

COVERAGE_DIR=_coverage

########################################
## Git hooks

git_hooks: $(wildcard scripts/git_hooks/*)
	@case "$$(file .git | cut -d: -f2)" in \
	' ASCII text') \
	    echo 'refusing to install git hooks in worktree' \
	    break;; \
	' directory') \
	    for f in $^; do \
	      [ ! -f ".git/hooks/$$(basename $$f)" ] && ln -s ../../$$f .git/hooks/; \
	    done; \
	    break;; \
	*) \
	    echo 'unhandled case when installing git hooks' \
	    exit 1 \
	    break;; \
	esac

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

build: git_hooks reformat-diff
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && (ulimit -u 2128 || true) && cd src && $(WRAPSRC) env CODA_COMMIT_SHA1=$(GITLONGHASH) dune build --profile=$(DUNE_PROFILE)
	$(info Build complete)

dev: codabuilder containerstart build

########################################
## Lint

reformat: git_hooks
	cd src; $(WRAPSRC) dune exec --profile=$(DUNE_PROFILE) app/reformat/reformat.exe -- -path .

reformat-diff:
	ocamlformat --inplace $(shell git diff --name-only HEAD | grep '.mli\?$$' | while IFS= read -r f; do stat "$$f" >/dev/null 2>&1 && echo "$$f"; done) || true

check-format:
	cd src; $(WRAPSRC) dune exec --profile=$(DUNE_PROFILE) app/reformat/reformat.exe -- -path . -check

check-snarky-submodule:
	./scripts/check-snarky-submodule.sh

########################################
## Merlin fixup for docker builds

merlin-fixup:
ifeq ($(USEDOCKER),TRUE)
	@echo "Fixing up .merlin files for Docker build"
	@./scripts/merlin-fixup.sh
else
	@echo "Not building in Docker, .merlin files unchanged"
endif

#######################################
## Environment setup

macos-setup-download:
	./scripts/macos-setup.sh download

macos-setup-compile:
	./scripts/macos-setup.sh compile

macos-setup:
	./scripts/macos-setup.sh all

########################################
## Containers and container management


# push steps require auth on docker hub
docker-toolchain:
	@if git diff-index --quiet HEAD ; then \
		docker build --file dockerfiles/Dockerfile-toolchain --tag codaprotocol/coda:toolchain-$(GITLONGHASH) . && \
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
	make render-circleci

# Local 'codabuilder' docker image (based off docker-toolchain)
codabuilder: git_hooks
	docker build --file dockerfiles/Dockerfile --tag codabuilder .

# Restarts codabuilder
containerstart: git_hooks
	@./scripts/container.sh restart

########################################
## Artifacts

deb:
	$(WRAP) ./scripts/rebuild-deb.sh
	@mkdir -p /tmp/artifacts
	@cp src/_build/coda.deb /tmp/artifacts/.

# deb-s3 https://github.com/krobertson/deb-s3
DEBS3 = deb-s3 upload --s3-region=us-west-2 --bucket packages.o1test.net --preserve-versions --cache-control=max-age=120

publish_kademlia_deb:
	@if [ $(AWS_ACCESS_KEY_ID) ] ; then \
		if [ "$(CIRCLE_BRANCH)" = "master" ] ; then \
			$(DEBS3) --codename stable   --component main src/_build/coda-kademlia.deb ; \
		else \
			$(DEBS3) --codename unstable --component main src/_build/coda-kademlia.deb ; \
		fi ; \
	else \
		echo "WARNING: AWS_ACCESS_KEY_ID not set, deb-s3 not run" ; \
	fi

publish_deb:
	@if [ $(AWS_ACCESS_KEY_ID) ] ; then \
		if [ "$(CIRCLE_BRANCH)" = "master" ] && [ "$(CIRCLE_JOB)" = "build_testnet_postake" ] ; then \
            echo "Publishing to stable" ; \
			$(DEBS3) --codename stable   --component main src/_build/coda-*.deb ; \
		else \
            echo "Publishing to unstable" ; \
			$(DEBS3) --codename unstable --component main src/_build/coda-*.deb ; \
		fi ; \
	else  \
		echo "WARNING: AWS_ACCESS_KEY_ID not set, deb-s3 commands not run" ; \
	fi

publish_debs: publish_deb publish_kademlia_deb

provingkeys:
	$(WRAP) tar -cvjf src/_build/coda_cache_dir_$(GITHASH)_$(CODA_CONSENSUS).tar.bz2  /tmp/coda_cache_dir ; \
	mkdir -p /tmp/artifacts ; \
	cp src/_build/coda_cache_dir*.tar.bz2 /tmp/artifacts/. ; \

genesiskeys:
	@mkdir -p /tmp/artifacts
	@cp src/_build/default/lib/coda_base/sample_keypairs.ml /tmp/artifacts/.
	@cp src/_build/default/lib/coda_base/sample_keypairs.json /tmp/artifacts/.

codaslim:
	@# FIXME: Could not reference .deb file in the sub-dir in the docker build
	@cp src/_build/coda.deb .
	@./scripts/rebuild-docker.sh codaslim dockerfiles/Dockerfile-codaslim
	@rm coda.deb

########################################
## Tests

render-circleci:
	./scripts/test.py render .circleci/config.yml.jinja

test-ppx:
	$(MAKE) -C src/lib/ppx_coda/tests

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

docs/res/%.dot.png: docs/res/%.dot
	dot -Tpng $< > $@

docs/res/%.tex.pdf: docs/res/%.tex
	cd docs/res && pdflatex $(notdir $<)
	cp $(@:.tex.pdf=.pdf) $@

docs/res/%.tex.png: docs/res/%.tex.pdf
	convert -density 600x600 $< -quality 90 -resize 1080x1080 $@

doc_diagrams: $(addsuffix .png,$(wildcard docs/res/*.tex) $(wildcard docs/res/*.dot))

########################################
# Generate odoc documentation

ml-docs:
	cd src; $(WRAPSRC) dune build --profile=$(DUNE_PROFILE) @doc

########################################
# To avoid unintended conflicts with file names, always add to .PHONY
# unless there is a reason not to.
# https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html
# HACK: cat Makefile | egrep '^\w.*' | sed 's/:/ /' | awk '{print $1}' | grep -v myprocs | sort | xargs
.PHONY: all base-docker base-googlecloud base-minikube build check-format ci-base-docker clean codaslim containerstart deb dev codabuilder kademlia coda-docker coda-googlecloud coda-minikube ocaml407-googlecloud pull-ocaml407-googlecloud reformat test test-all test-coda-block-production-sig test-coda-block-production-stake test-codapeers-sig test-codapeers-stake test-full-sig test-full-stake test-runtest test-transaction-snark-profiler-sig test-transaction-snark-profiler-stake update-deps render-circleci check-render-circleci docker-toolchain-rust toolchains doc_diagrams ml-docs macos-setup macos-setup-download macos-setup-compile
