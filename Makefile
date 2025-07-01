########################################
## Configuration

# Current OCaml version
OCAML_VERSION = "4.14.2"

# machine word size
WORD_SIZE = "64"

# Default profile
ifeq ($(DUNE_PROFILE),)
DUNE_PROFILE := dev
endif

ifeq ($(OPAMSWITCH)$(IN_NIX_SHELL)$(CI)$(BUILDKITE),)
# Sometimes opam replaces these env variables in shell with
# an explicit mention of a particular switch (dereferenced from the value)
OPAM_SWITCH_PREFIX := $(PWD)/_opam
OCAML_TOPLEVEL_PATH := $(OPAM_SWITCH_PREFIX)/lib/toplevel
PATH := $(OPAM_SWITCH_PREFIX)/bin:$(PATH)
endif

# Temp directory
TMPDIR ?= /tmp

# Genesis dir
GENESIS_DIR := $(TMPDIR)/coda_cache_dir

# Coverage directory
COVERAGE_DIR=_coverage

########################################
## Handy variables

# Distribution codename, to be used in Docker builds
CODENAME ?= $(shell lsb_release -cs)

# This commit hash
GITHASH := $(shell git rev-parse --short=8 HEAD)
GITLONGHASH := $(shell git rev-parse HEAD)

# Unique signature of libp2p code tree
LIBP2P_HELPER_SIG := $(shell cd src/app/libp2p_helper ; find . -type f -print0  | xargs -0 sha1sum | sort | sha1sum | cut -f 1 -d ' ')

########################################
.PHONY: help
help: ## Display this help information
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

########################################
## Code

.PHONY: all
all: clean build ## Clean and build the project

.PHONY: clean
clean: ## Remove build artifacts
	$(info Removing previous build artifacts)
	@rm -rf _build
	@rm -rf Cargo.lock target
	@rm -rf src/$(COVERAGE_DIR)
	@rm -rf src/app/libp2p_helper/result src/libp2p_ipc/libp2p_ipc.capnp.go

.PHONY: switch
switch: ## Set up the opam switch
	./scripts/update-opam-switch.sh

.PHONY: ocaml_version
ocaml_version: switch ## Check OCaml version
	@if ! ocamlopt -config | grep "version:" | grep $(OCAML_VERSION); then echo "incorrect OCaml version, expected version $(OCAML_VERSION)" ; exit 1; fi

.PHONY: ocaml_word_size
ocaml_word_size: switch ## Check OCaml word size
	@if ! ocamlopt -config | grep "word_size:" | grep $(WORD_SIZE); then echo "invalid machine word size, expected $(WORD_SIZE)" ; exit 1; fi


.PHONY: check_opam_switch
check_opam_switch: switch ## Verify the opam switch has correct packages
ifneq ($(DISABLE_CHECK_OPAM_SWITCH), true)
	@which check_opam_switch 2>/dev/null >/dev/null || ( echo "The check_opam_switch binary was not found in the PATH, try: opam switch import opam.export" >&2 && exit 1 )
	@check_opam_switch opam.export
endif

.PHONY: ocaml_checks
ocaml_checks: switch ocaml_version ocaml_word_size check_opam_switch ## Run OCaml version and config checks

.PHONY: libp2p_helper
libp2p_helper: ## Build libp2p helper
ifeq (, $(MINA_LIBP2P_HELPER_PATH))
	make -C src/app/libp2p_helper
endif

.PHONY: genesis_ledger
genesis_ledger: ocaml_checks ## Build runtime genesis ledger
	$(info Building runtime_genesis_ledger)
	(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	env MINA_COMMIT_SHA1=$(GITLONGHASH) \
	dune exec \
		--profile=$(DUNE_PROFILE) \
		src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe -- \
		--genesis-dir $(GENESIS_DIR)
	$(info Genesis ledger and genesis proof generated)

.PHONY: check
check: ocaml_checks libp2p_helper ## Check that all OCaml packages build without issues
	dune build @src/check

.PHONY: build
build: ocaml_checks reformat-diff libp2p_helper ## Build the main project executables
	$(info Starting Build)
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	env MINA_COMMIT_SHA1=$(GITLONGHASH) \
	dune build \
		src/app/logproc/logproc.exe \
		src/app/cli/src/mina.exe \
		src/app/generate_keypair/generate_keypair.exe \
		src/app/validate_keypair/validate_keypair.exe \
		src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe \
		--profile=$(DUNE_PROFILE)
	$(info Build complete)

.PHONY: build_all_sigs
build_all_sigs: ocaml_checks reformat-diff libp2p_helper build ## Build all signature variants of the daemon
	$(info Starting Build)
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	env MINA_COMMIT_SHA1=$(GITLONGHASH) \
	dune build \
		src/app/cli/src/mina_testnet_signatures.exe \
		src/app/cli/src/mina_mainnet_signatures.exe \
		--profile=$(DUNE_PROFILE)
	$(info Build complete)

.PHONY: build_archive
build_archive: ocaml_checks reformat-diff ## Build the archive node
	$(info Starting Build)
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		src/app/archive/archive.exe \
		--profile=$(DUNE_PROFILE)
	$(info Build complete)

.PHONY: build_archive_utils
build_archive_utils: ocaml_checks reformat-diff ## Build archive node and related utilities
	$(info Starting Build)
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		src/app/archive/archive.exe \
		src/app/replayer/replayer.exe \
		src/app/archive_blocks/archive_blocks.exe \
		src/app/extract_blocks/extract_blocks.exe \
		src/app/missing_blocks_auditor/missing_blocks_auditor.exe \
		--profile=$(DUNE_PROFILE)
	$(info Build complete)

.PHONY: build_rosetta
build_rosetta: ocaml_checks ## Build Rosetta API components
	$(info Starting Build)
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		src/app/archive/archive.exe \
		src/app/rosetta/rosetta.exe \
		src/app/rosetta/ocaml-signer/signer.exe \
		--profile=$(DUNE_PROFILE)
	$(info Build complete)

.PHONY: build_rosetta_all_sigs
build_rosetta_all_sigs: ocaml_checks ## Build all signature variants of Rosetta
	$(info Starting Build)
	(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && dune build src/app/archive/archive.exe src/app/archive/archive_testnet_signatures.exe src/app/archive/archive_mainnet_signatures.exe src/app/rosetta/rosetta.exe src/app/rosetta/rosetta_testnet_signatures.exe src/app/rosetta/rosetta_mainnet_signatures.exe src/app/rosetta/ocaml-signer/signer.exe src/app/rosetta/ocaml-signer/signer_testnet_signatures.exe src/app/rosetta/ocaml-signer/signer_mainnet_signatures.exe --profile=$(DUNE_PROFILE)
	$(info Build complete)

.PHONY: build_intgtest
build_intgtest: ocaml_checks ## Build integration test tools
	$(info Starting Build)
	@dune build \
		--profile=$(DUNE_PROFILE) \
		src/app/test_executive/test_executive.exe \
		src/app/logproc/logproc.exe
	$(info Build complete)

.PHONY: rosetta_lib_encodings
rosetta_lib_encodings: ocaml_checks ## Test Rosetta library encodings
	$(info Starting Build)
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
	  src/lib/rosetta_lib/test/test_encodings.exe \
	  --profile=mainnet
	$(info Build complete)

.PHONY: replayer
replayer: ocaml_checks ## Build the replayer tool
	$(info Starting Build)
	@ulimit -s 65532 && (ulimit -n 10240 || true) && \
	dune build \
		src/app/replayer/replayer.exe \
		--profile=devnet
	$(info Build complete)

.PHONY: missing_blocks_auditor
missing_blocks_auditor: ocaml_checks ## Build missing blocks auditor tool
	$(info Starting Build)
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		src/app/missing_blocks_auditor/missing_blocks_auditor.exe \
		--profile=testnet_postake_medium_curves
	$(info Build complete)

.PHONY: extract_blocks
extract_blocks: ocaml_checks ## Build the extract_blocks executable
	$(info Starting Build)
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		src/app/extract_blocks/extract_blocks.exe \
		--profile=testnet_postake_medium_curves
	$(info Build complete)

.PHONY: archive_blocks
archive_blocks: ocaml_checks ## Build the archive_blocks executable
	$(info Starting Build)
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		src/app/archive_blocks/archive_blocks.exe \
		--profile=testnet_postake_medium_curves
	$(info Build complete)

.PHONY: patch_archive_test
patch_archive_test: ocaml_checks ## Build the patch archive test
	$(info Starting Build)
	@ulimit -s 65532 && (ulimit -n 10240 || true) && \
	dune build \
	  src/app/patch_archive_test/patch_archive_test.exe \
		--profile=testnet_postake_medium_curves
	$(info Build complete)

.PHONY: heap_usage
heap_usage: ocaml_checks ## Build heap usage analysis tool
	$(info Starting Build)
	@ulimit -s 65532 && (ulimit -n 10240 || true) && \
	dune build \
		src/app/heap_usage/heap_usage.exe \
		--profile=devnet
	$(info Build complete)

.PHONY: zkapp_limits
zkapp_limits: ocaml_checks ## Build ZkApp limits tool
	$(info Starting Build)
	@ulimit -s 65532 && (ulimit -n 10240 || true) && \
	dune build \
		src/app/zkapp_limits/zkapp_limits.exe \
		--profile=devnet
	$(info Build complete)

.PHONY: dev
dev: build ## Alias for build

.PHONY: update-graphql
update-graphql: ## Update GraphQL schema
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		--profile=$(DUNE_PROFILE) \
		graphql_schema.json

update-rust-vendors: ## Update the Rust vendors
	@echo "Updating Rust vendors in src/lib/crypto/kimchi_bindings/stubs..."
	@cd src/lib/crypto/kimchi_bindings/stubs && cargo vendor kimchi-stubs-vendors

.PHONY: install
install:
	@dune build @install
	@dune install
	@echo "--------------------------------------------------------------"
	@echo "All binaries (resp. libraries) have been installed into $(OPAM_SWITCH_PREFIX)/bin"
	@echo "(resp. ${OPAM_SWITCH_PREFIX}/lib) and the binaries are available in the path."
	@echo "You can list the installed binaries with:"
	@echo "> ls -al ${OPAM_SWITCH_PREFIX}/bin"
	@echo "In particular, you should be able to run the command 'mina'"
	@echo "'logproc', 'rosetta', 'generate_keypair', etc from this shell"

.PHONY: uninstall
uninstall:
	@dune uninstall

########################################
## Lint

.PHONY: reformat
reformat: ocaml_checks ## Reformat all OCaml code
	dune exec \
		--profile=$(DUNE_PROFILE) \
	  src/app/reformat/reformat.exe -- \
		-path .

.PHONY: reformat-diff
reformat-diff: ## Reformat only modified OCaml files
	@FILES=$$(git status -s | cut -c 4- | grep '\.mli\?$$' | while IFS= read -r f; do stat "$$f" >/dev/null 2>&1 && echo "$$f"; done); \
	if [ -n "$$FILES" ]; then ocamlformat --doc-comments=before --inplace $$FILES; fi

.PHONY: check-format
check-format: ocaml_checks ## Check formatting of OCaml code
	dune exec \
		--profile=$(DUNE_PROFILE) \
	  src/app/reformat/reformat.exe -- \
		-path . -check

.PHONY: check-snarky-submodule
check-snarky-submodule: ## Check the snarky submodule
	./scripts/check-snarky-submodule.sh

#######################################
## Bash checks

check-bash: ## Run shellcheck on bash scripts
	shellcheck ./scripts/**/*.sh -S warning
	shellcheck ./buildkite/scripts/**/*.sh -S warning

########################################
## Artifacts

.PHONY: build_pv_keys
build_pv_keys: ocaml_checks ## Build proving/verification keys
	$(info Building keys)
	(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	env MINA_COMMIT_SHA1=$(GITLONGHASH) \
	dune exec \
		--profile=$(DUNE_PROFILE) \
	  src/lib/snark_keys/gen_keys/gen_keys.exe -- \
		--generate-keys-only
	$(info Keys built)

.PHONY: build_or_download_pv_keys
build_or_download_pv_keys: ocaml_checks ## Build or download proving/verification keys
	$(info Building keys)
	(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	env MINA_COMMIT_SHA1=$(GITLONGHASH) \
	dune exec \
		--profile=$(DUNE_PROFILE) \
		src/lib/snark_keys/gen_keys/gen_keys.exe -- \
		--generate-keys-only
	$(info Keys built)

.PHONY: genesiskeys
genesiskeys: ## Generate and copy genesis keys
	@mkdir -p /tmp/artifacts
	@cp _build/default/src/lib/key_gen/sample_keypairs.ml /tmp/artifacts/.
	@cp _build/default/src/lib/key_gen/sample_keypairs.json /tmp/artifacts/.


##############################################
## Genesis ledger in OCaml from running daemon

.PHONY: genesis-ledger-ocaml
genesis-ledger-ocaml: ## Generate OCaml genesis ledger from daemon
	@./scripts/generate-genesis-ledger.py .genesis-ledger.ml.jinja

########################################
## Tests

.PHONY: test-ppx
test-ppx: ## Test PPX extensions
	$(MAKE) -C src/lib/ppx_mina/tests

########################################
## Benchmarks

.PHONY: benchmarks
benchmarks: ocaml_checks ## Build benchmarking tools
	dune build src/app/benchmarks/benchmarks.exe

########################################
# Coverage testing and output

.PHONY: test-coverage
test-coverage: SHELL := /bin/bash
test-coverage: libp2p_helper ## Run tests with coverage instrumentation
	scripts/create_coverage_profiles.sh

.PHONY: coverage-html
coverage-html: ## Generate HTML report from coverage data
ifeq ($(shell find _build/default -name bisect\*.out),"")
	echo "No coverage output; run make test-coverage"
else
	bisect-ppx-report html --source-path=_build/default --coverage-path=_build/default
endif

.PHONY: coverage-summary
coverage-summary: ## Generate coverage summary report
ifeq ($(shell find _build/default -name bisect\*.out),"")
	echo "No coverage output; run make test-coverage"
else
	bisect-ppx-report summary --coverage-path=_build/default --per-file
endif

########################################
# Diagrams for documentation

%.dot.png: %.dot
	dot -Tpng $< > $@

%.tex.pdf: %.tex
	cd $(dir $@) && pdflatex -halt-on-error $(notdir $<)
	cp $(@:.tex.pdf=.pdf) $@

%.tex.png: %.tex.pdf
	convert -density 600x600 $< -quality 90 -resize 1080x1080 $@

%.conv.tex.png: %.conv.tex
	cd $(dir $@) && pdflatex -halt-on-error -shell-escape $(notdir $<)

# TODO: this, but smarter so we don't have to add every library
doc_diagram_sources=$(addprefix docs/res/,*.dot *.tex *.conv.tex)
doc_diagram_sources+=$(addprefix rfcs/res/,*.dot *.tex *.conv.tex)
doc_diagram_sources+=$(addprefix src/lib/transition_frontier/res/,*.dot *.tex *.conv.tex)

.PHONY: doc_diagrams
doc_diagrams: $(addsuffix .png,$(wildcard $(doc_diagram_sources))) ## Generate documentation diagrams

########################################
# Docker images

.PHONY: docker-build-toolchain-bullseye
docker-build-toolchain-bullseye: ## Build the toolchain to be used in CI, based on Debian Bullseye
	./scripts/docker/build.sh \
		--deb-codename bullseye \
		--service mina-toolchain \
		--version mina-toolchain-bullseye-$(shell git rev-parse --short=8 HEAD)

.PHONY: docker-build-toolchain-focal
docker-build-toolchain-focal: ## Build the toolchain to be used in CI, based on Debian Focal
	./scripts/docker/build.sh \
		--deb-codename focal \
		--service mina-toolchain \
		--version mina-toolchain-focal-$(shell git rev-parse --short=8 HEAD)

.PHONY: docker-build-toolchain-noble
docker-build-toolchain-noble: ## Build the toolchain to be used in CI, based on Ubuntu Noble
	./scripts/docker/build.sh \
		--deb-codename noble \
		--service mina-toolchain \
		--version mina-toolchain-noble-$(shell git rev-parse --short=8 HEAD)

########################################
# Generate odoc documentation

.PHONY: ml-docs
ml-docs: ocaml_checks ## Generate OCaml documentation
	dune build --profile=$(DUNE_PROFILE) @doc
