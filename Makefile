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

# Default branch name
# This is used for versioning and release purposes when building docker or debian
# For example when BRANCH_NAME=fix-branch:
# Target version : 3.1.2-alpha-fix-branch-bullseye-devnet
BRANCH_NAME ?= $(shell git rev-parse --abbrev-ref HEAD)

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
.PHONY: add-o1labs-opam-repo
add-o1labs-opam-repo:
	opam repository add --yes --all --set-default o1-labs https://github.com/o1-labs/opam-repository.git

.PHONY: prepare
prepare: add-o1labs-opam-repo
	@echo "Preparing the environment and installing dependencies..."
	@# Check Go installation and version
	@command -v go >/dev/null 2>&1 || { echo >&2 "Error: Go is not installed. Please install Go before continuing. You can use gvm to install the appropriate Go environment."; exit 1; }
	@GO_VERSION=$$(go version | awk '{print $$3}' | sed 's/go//'); \
	GO_MOD_PATH="src/app/libp2p_helper/src/go.mod"; \
	REQUIRED_GO_VERSION=$$(grep -E "^go [0-9]+\.[0-9]" $$GO_MOD_PATH | awk '{print $$2}'); \
	if ! printf '%s\n%s\n' "$$REQUIRED_GO_VERSION" "$$GO_VERSION" | sort -V | head -n1 | grep -q "^$$REQUIRED_GO_VERSION$$"; then \
		echo "Error: Go version $$GO_VERSION is not compatible. Required version is $$REQUIRED_GO_VERSION or newer (only minor)."; \
		exit 1; \
	fi; \
	echo "Go version $$GO_VERSION detected (requirement: $$REQUIRED_GO_VERSION or newer (only minor))"
	opam switch import --switch mina --yes opam.export
	eval $(opam env --switch=mina --set-switch)
	chmod +x scripts/pin-external-packages.sh
	./scripts/pin-external-packages.sh
	@echo "Environment prepared. You can now run 'make build' to build the project."


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
	@if ! ocamlopt -config | grep "version:" | grep -q $(OCAML_VERSION); then echo "❌ incorrect OCaml version, expected version $(OCAML_VERSION)" ; exit 1; else echo "✅ OCaml version is correct"; fi

.PHONY: ocaml_word_size
ocaml_word_size: switch ## Check OCaml word size
	@if ! ocamlopt -config | grep "word_size:" | grep -q $(WORD_SIZE); then echo "❌ invalid machine word size, expected $(WORD_SIZE)" ; exit 1; else echo "✅ OCaml word size is correct"; fi


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
	$(info 🏗️  Building libp2p_helper)
	@make -C src/app/libp2p_helper \
	&& echo "✅ libp2p_helper build complete"
endif

.PHONY: genesis_ledger
genesis_ledger: ocaml_checks ## Build runtime genesis ledger
	$(info 🏗️  Building runtime_genesis_ledger with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
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
	$(info 🏗️  Building Mina with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	env MINA_COMMIT_SHA1=$(GITLONGHASH) \
	dune build \
		src/app/logproc/logproc.exe \
		src/app/cli/src/mina.exe \
		src/app/generate_keypair/generate_keypair.exe \
		src/app/validate_keypair/validate_keypair.exe \
		src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe \
		src/lib/snark_worker/standalone/run_snark_worker.exe \
		--profile=$(DUNE_PROFILE) \
		&& echo "✅ Build complete"

.PHONY: build-daemon-utils
build-daemon-utils: ocaml_checks reformat-diff libp2p_helper ## Build daemon utilities
	$(info 🏗️  Building Mina Daemon related utils with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	env MINA_COMMIT_SHA1=$(GITLONGHASH) \
	dune build \
		src/app/generate_keypair/generate_keypair.exe \
		src/app/validate_keypair/validate_keypair.exe \
		src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe \
		src/lib/snark_worker/standalone/run_snark_worker.exe \
		src/app/rocksdb-scanner/rocksdb_scanner.exe \
		--profile=$(DUNE_PROFILE) \
		&& echo "✅ Build complete"


.PHONY: build-logproc
build-logproc: ocaml_checks reformat-diff libp2p_helper ## Build the logproc executable
	$(info 🏗️  Building logproc with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	env MINA_COMMIT_SHA1=$(GITLONGHASH) \
	dune build \
		src/app/logproc/logproc.exe \
		--profile=$(DUNE_PROFILE) \
		&& echo "✅ Build complete"

.PHONY: build-mainnet-sigs
build-mainnet-sigs: ocaml_checks reformat-diff libp2p_helper build ## Build mainnet signature variants of the daemon
	$(info 🏗️  Building mainnet signature variants with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	env MINA_COMMIT_SHA1=$(GITLONGHASH) \
	dune build \
		src/app/cli/src/mina_mainnet_signatures.exe \
		src/app/rosetta/rosetta_mainnet_signatures.exe \
		src/app/rosetta/ocaml-signer/signer_mainnet_signatures.exe \
		--profile=mainnet \
		&& echo "✅ Build complete"

.PHONY: build-devnet-sigs
build-devnet-sigs: ocaml_checks reformat-diff libp2p_helper build ## Build devnet signature variants of the daemon
	$(info 🏗️  Building devnet signature variants with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	env MINA_COMMIT_SHA1=$(GITLONGHASH) \
	dune build \
		src/app/cli/src/mina_testnet_signatures.exe \
		src/app/rosetta/rosetta_testnet_signatures.exe \
		src/app/rosetta/ocaml-signer/signer_testnet_signatures.exe \
		--profile=devnet \
		&& echo "✅ Build complete"

.PHONY: build-archive
build-archive: ocaml_checks reformat-diff ## Build the archive node
	$(info 🏗️  Building archive with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		src/app/archive/archive.exe \
		--profile=$(DUNE_PROFILE) && \
		echo "✅ Build complete"

.PHONY: build-archive-utils
build-archive-utils: ocaml_checks reformat-diff ## Build archive node and related utilities
	$(info 🏗️  Building archive utilities with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		src/app/archive/archive.exe \
		src/app/replayer/replayer.exe \
		src/app/archive_blocks/archive_blocks.exe \
		src/app/extract_blocks/extract_blocks.exe \
		src/app/missing_blocks_auditor/missing_blocks_auditor.exe \
		src/app/archive_hardfork_toolbox/archive_hardfork_toolbox.exe \
		--profile=$(DUNE_PROFILE)  \
		&& echo "✅ Build complete"

.PHONY: build-test-utils
build-test-utils: ocaml_checks reformat-diff ## Build test utilities
	$(info 🏗️  Building test utilities with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		src/app/test_executive/test_executive.exe \
		src/app/benchmarks/benchmarks.exe \
		src/app/batch_txn_tool/batch_txn_tool.exe \
		src/app/zkapp_test_transaction/zkapp_test_transaction.exe \
		src/app/rosetta/indexer_test/indexer_test.exe \
		src/app/ledger_export_bench/ledger_export_benchmark.exe \
		src/app/disk_caching_stats/disk_caching_stats.exe \
		src/app/heap_usage/heap_usage.exe \
		src/app/zkapp_limits/zkapp_limits.exe \
		src/lib/snark_worker/standalone/run_snark_worker.exe \
		src/test/command_line_tests/command_line_tests.exe \
		src/test/archive/patch_archive_test/patch_archive_test.exe \
		src/test/archive/archive_node_tests/archive_node_tests.exe \
		--profile=$(DUNE_PROFILE) \
		&& echo "✅ Build complete"

.PHONY: build-delegation-verify
build-delegation-verify: ocaml_checks reformat-diff ## Build delegation verify tool
	$(info 🏗️  Building delegation verify tool with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		src/app/delegation_verify/delegation_verify.exe \
		--profile=$(DUNE_PROFILE) \
		&& echo "✅ Build complete"

.PHONY: build-rosetta
build-rosetta: ocaml_checks ## Build Rosetta API components
	$(info 🏗️  Building Rosetta API components with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		src/app/archive/archive.exe \
		src/app/rosetta/rosetta.exe \
		src/app/rosetta/ocaml-signer/signer.exe \
		--profile=$(DUNE_PROFILE) \
		&& echo "✅ Build complete"

.PHONY: build-intgtest
build-intgtest: ocaml_checks ## Build integration test tools
	$(info 🏗️  Building integration test tools with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
	@dune build \
		--profile=$(DUNE_PROFILE) \
		src/app/test_executive/test_executive.exe \
		src/app/logproc/logproc.exe \
		&& echo "✅ Build complete"

.PHONY: build-rosetta-mainnet-lib-encodings
build-rosetta-mainnet-lib-encodings: ocaml_checks ## Test Rosetta library encodings
	$(info 🏗️  Building Rosetta library encodings with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
	  src/lib/rosetta_lib/test/test_encodings.exe \
	  --profile=mainnet \
		&& echo "✅ Build complete"

.PHONY: build-replayer
build-replayer: ocaml_checks ## Build the replayer tool
	$(info 🏗️  Building replayer tool with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
	@ulimit -s 65532 && (ulimit -n 10240 || true) && \
	dune build \
		src/app/replayer/replayer.exe \
		--profile=$(DUNE_PROFILE) \
		&& echo "✅ Build complete"

.PHONY: build-missing-blocks-auditor
build-missing-blocks-auditor: ocaml_checks ## Build missing blocks auditor tool
	$(info 🏗️  Building missing blocks auditor tool with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		src/app/missing_blocks_auditor/missing_blocks_auditor.exe \
		--profile=$(DUNE_PROFILE) \
		&& echo "✅ Build complete"

.PHONY: extract-blocks
build-extract-blocks: ocaml_checks ## Build the extract_blocks executable
	$(info 🏗️  Building extract_blocks with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		src/app/extract_blocks/extract_blocks.exe \
		--profile=$(DUNE_PROFILE) \
		&& echo "✅ Build complete"

.PHONY: build-archive-blocks
build-archive-blocks: ocaml_checks ## Build the archive_blocks executable
	$(info 🏗️  Building archive_blocks with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		src/app/archive_blocks/archive_blocks.exe \
		--profile=$(DUNE_PROFILE) \
		&& echo "✅ Build complete"

.PHONY: build-patch-archive-test
build-patch-archive-test: ocaml_checks ## Build the patch archive test
	$(info 🏗️  Building patch archive test with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
	@ulimit -s 65532 && (ulimit -n 10240 || true) && \
	dune build \
	  src/app/patch_archive_test/patch_archive_test.exe \
		--profile=$(DUNE_PROFILE) \
		&& echo "✅ Build complete"

.PHONY: build-heap-usage
build-heap-usage: ocaml_checks ## Build heap usage analysis tool
	$(info 🏗️  Building heap usage analysis tool with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
	@ulimit -s 65532 && (ulimit -n 10240 || true) && \
	dune build \
		src/app/heap_usage/heap_usage.exe \
		--profile=$(DUNE_PROFILE) \
		&& echo "✅ Build complete"

.PHONY: build-zkapp-limits
build-zkapp-limits: ocaml_checks ## Build ZkApp limits tool
	$(info 🏗️  Building ZkApp limits tool with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
	@ulimit -s 65532 && (ulimit -n 10240 || true) && \
	dune build \
		src/app/zkapp_limits/zkapp_limits.exe \
		--profile=$(DUNE_PROFILE) \
		&& echo "✅ Build complete"

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

.PHONY: check-bash
check-bash: ## Run shellcheck on bash scripts
	shellcheck ./scripts/**/*.sh -S warning
	shellcheck ./buildkite/scripts/**/*.sh -S warning

.PHONY: check-docker
check-docker: ## Run hadolint on Docker files
ifdef BUILDKITE
	hadolint --ignore DL3008 --ignore DL3002 --ignore DL3013 --ignore DL3007 --ignore DL3006 --ignore DL3028 dockerfiles/Dockerfile-* dockerfiles/stages/*
else
	docker run --rm -v $(PWD):/workspace -w /workspace \
		hadolint/hadolint hadolint \
		--ignore DL3008 \
		--ignore DL3002 \
		--ignore DL3013 \
		--ignore DL3007 \
		--ignore DL3006 \
		--ignore DL3028 \
		dockerfiles/Dockerfile-* \
		dockerfiles/stages/*
endif

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

.PHONY: export_git_env_vars
export_git_env_vars: ## Export git environment variables for use in scripts
	KEEP_MY_TAGS_INTACT=true \
		./scripts/export-git-env-vars.sh

########################################
# Debian packages

# Helper function for building Debian packages
define build_debian_package
	$(info 🏗️  Building Debian package $(1) with profile $(DUNE_PROFILE) and commit $(GITLONGHASH) and codename $(CODENAME))
	BUILD_DIR="${PWD}/_build" \
	DUNE_PROFILE=$(DUNE_PROFILE) \
	MINA_DEB_CODENAME="$(CODENAME)" \
	BRANCH_NAME="$(BRANCH_NAME)" \
	./scripts/debian/build.sh $(1)  \
		&& echo "✅ Build complete"
endef

.PHONY: debian-build-archive-testnet-generic
debian-build-archive-testnet-generic: ## Build the Debian archive package
	$(call build_debian_package,archive_testnet_generic)

.PHONY: debian-build-archive-devnet
debian-build-archive-devnet: ## Build the Debian archive package for devnet
	$(call build_debian_package,archive_devnet)

.PHONY: debian-build-archive-mainnet
debian-build-archive-mainnet: ## Build the Debian archive package for mainnet
	$(call build_debian_package,archive_mainnet)

.PHONY: debian-build-daemon-testnet-generic
debian-build-daemon-testnet-generic: ## Build the Debian daemon package for testnet-generic
	$(call build_debian_package,daemon_testnet_generic)

.PHONY: debian-build-daemon-devnet
debian-build-daemon-devnet: ## Build the Debian daemon package for devnet
	$(call build_debian_package,daemon_devnet)

.PHONY: debian-build-daemon-mainnet
debian-build-daemon-mainnet: ## Build the Debian daemon package for mainnet
	$(call build_debian_package,daemon_mainnet)

.PHONY: debian-build-config-devnet
debian-build-config-devnet: ## Build the Debian config package for devnet
	$(call build_debian_package,daemon_devnet_config)

.PHONY: debian-build-config-mainnet
debian-build-config-mainnet: ## Build the Debian config package for mainnet
	$(call build_debian_package,daemon_mainnet_config)

.PHONY: debian-build-logproc
debian-build-logproc: ## Build the Debian logproc package
	$(call build_debian_package,logproc)

.PHONY: debian-build-functional-tests
debian-build-functional-tests: ## Build the Debian Functional tests package
	$(call build_debian_package,functional_test_suite)

.PHONY: debian-build-create-legacy-genesis
debian-build-create-legacy-genesis: ## Build the Debian Create Legacy Genesis package
	$(call build_debian_package,create_legacy_genesis)

.PHONY: debian-build-rosetta-testnet-generic
debian-build-rosetta-testnet-generic: ## Build the Debian Rosetta package
	$(call build_debian_package,rosetta_testnet_generic)

.PHONY: debian-build-rosetta-devnet
debian-build-rosetta-devnet: ## Build the Debian Rosetta package for devnet
	$(call build_debian_package,rosetta_devnet)

.PHONY: debian-build-rosetta-mainnet
debian-build-rosetta-mainnet: ## Build the Debian Rosetta package for mainnet
	$(call build_debian_package,rosetta_mainnet)

.PHONY: debian-build-daemon-devnet-post-hardfork
debian-build-daemon-devnet-post-hardfork: ## Build the Debian daemon package for automote devnet post hardfork
	$(call build_debian_package,daemon_post_hardfork_devnet)

.PHONY: debian-build-daemon-mainnet-post-hardfork
debian-build-daemon-mainnet-post-hardfork: ## Build the Debian daemon package for automote mainnet post hardfork
	$(call build_debian_package,daemon_post_hardfork_mainnet)

.PHONY: debian-build-daemon-devnet-prefork
debian-build-daemon-devnet-prefork: ## Build the Debian daemon package for automote devnet pre hardfork
	$(call build_debian_package,daemon_prefork_devnet)

.PHONY: debian-build-daemon-mainnet-prefork
debian-build-daemon-mainnet-prefork: ## Build the Debian daemon package for automote mainnet pre hardfork
	$(call build_debian_package,daemon_prefork_mainnet)

.PHONY: debian-build-daemon-devnet-pre-hardfork
debian-build-daemon-devnet-pre-hardfork: ## Build the Debian daemon package for automote devnet pre hardfork
	$(call build_debian_package,daemon_devnet_pre_hardfork)

.PHONY: debian-build-daemon-mainnet-pre-hardfork
debian-build-daemon-mainnet-pre-hardfork: ## Build the Debian daemon package for automote mainnet pre hardfork
	$(call build_debian_package,daemon_mainnet_pre_hardfork)

.PHONY: debian-download-create-legacy-hardfork
debian-download-create-legacy-hardfork: ## Download and create legacy hardfork Debian packages
	$(info 📦 Downloading legacy hardfork Debian packages for debian $(CODENAME))
	@./buildkite/scripts/release/manager.sh pull --artifacts mina-create-legacy-genesis  --from-special-folder legacy/debians/$(CODENAME)  --backend hetzner --target _build

########################################
# Docker images

.PHONY: start-local-debian-repo
start-local-debian-repo: ## Start a local Debian repository
	$(info 📦 Starting local Debian repository with codename $(CODENAME))

	@./scripts/debian/aptly.sh stop || true

	@./scripts/debian/aptly.sh start \
		--codename $(CODENAME) \
		--debians _build \
		--component unstable \
		--clean \
		--background \
		--wait \
		&& echo "✅ Build complete"

# General function for building Docker images
define build_docker_image
	$(info 🐳 Building Docker image for service $(1) with \
		codename $(CODENAME) \
		and version $$MINA_DEB_VERSION \
		and branch $$GITBRANCH \
		and network $(2))

	@BUILD_DIR=./_build \
	MINA_DEB_CODENAME=$(CODENAME) \
	KEEP_MY_TAGS_INTACT=true \
	. ./scripts/export-git-env-vars.sh \
	&& ./scripts/docker/build.sh \
		--deb-codename $(CODENAME) \
		--service $(1) \
		--version "$$MINA_DEB_VERSION" \
		--branch "$$GITBRANCH" \
		--deb-legacy-version "$$MINA_DEB_LEGACY_VERSION" \
		--docker-registry "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo" \
		--network $(2) \
		--no-cache

	$(info 📦 stopping local Debian repository)
	@./scripts/debian/aptly.sh stop
endef


.PHONY: docker-build-toolchain
docker-build-toolchain: ## Build the toolchain to be used in CI
	@BUILD_DIR=./_build \
		./scripts/docker/build.sh \
		--deb-codename $(CODENAME) \
		--service mina-toolchain \
		--version mina-toolchain-$(CODENAME)-$(GITHASH)

.PHONY: docker-build-archive-testnet-generic
docker-build-archive-testnet-generic: SHELL := /bin/bash
docker-build-archive-testnet-generic: start-local-debian-repo ## Build the archive Docker image
	$(call build_docker_image,mina-archive,testnet-generic)

.PHONY: docker-build-archive-devnet
docker-build-archive-devnet: SHELL := /bin/bash
docker-build-archive-devnet: start-local-debian-repo ## Build the archive Docker image for devnet
	$(call build_docker_image,mina-archive,devnet)

.PHONY: docker-build-archive-mainnet
docker-build-archive-mainnet: SHELL := /bin/bash
docker-build-archive-mainnet: start-local-debian-repo ## Build the archive Docker image for mainnet
	$(call build_docker_image,mina-archive,mainnet)

.PHONY: docker-build-daemon-testnet-generic
docker-build-daemon-testnet-generic: SHELL := /bin/bash
docker-build-daemon-testnet-generic: start-local-debian-repo ## Build the daemon Docker image
	$(call build_docker_image,mina-daemon,testnet-generic)

.PHONY: docker-build-daemon-devnet
docker-build-daemon-devnet: SHELL := /bin/bash
docker-build-daemon-devnet: start-local-debian-repo ## Build the daemon Docker image for devnet
	$(call build_docker_image,mina-daemon,devnet)

.PHONY: docker-build-daemon-mainnet
docker-build-daemon-mainnet: SHELL := /bin/bash
docker-build-daemon-mainnet: start-local-debian-repo ## Build the daemon Docker image for mainnet
	$(call build_docker_image,mina-daemon,mainnet)


.PHONY: docker-build-daemon-devnet-automode-hardfork
docker-build-daemon-devnet-automode-hardfork: SHELL := /bin/bash
docker-build-daemon-devnet-automode-hardfork: start-local-debian-repo ## Build the daemon Docker image for automode devnet post hardfork
	$(call build_docker_image,mina-daemon-auto-hardfork,devnet)

.PHONY: docker-build-daemon-mainnet-automode-hardfork
docker-build-daemon-mainnet-automode-hardfork: SHELL := /bin/bash
docker-build-daemon-mainnet-automode-hardfork: start-local-debian-repo ## Build the daemon Docker image for automode mainnet post hardfork
	$(call build_docker_image,mina-daemon-auto-hardfork,mainnet)

.PHONY: docker-build-rosetta
docker-build-rosetta-testnet-generic: SHELL := /bin/bash
docker-build-rosetta-testnet-generic: start-local-debian-repo ## Build the Rosetta Docker image
	$(call build_docker_image,mina-rosetta,testnet-generic)

.PHONY: docker-build-rosetta-devnet
docker-build-rosetta-devnet: SHELL := /bin/bash
docker-build-rosetta-devnet: start-local-debian-repo ## Build the Rosetta Docker image for devnet
	$(call build_docker_image,mina-rosetta,devnet)

.PHONY: docker-build-rosetta-mainnet
docker-build-rosetta-mainnet: SHELL := /bin/bash
docker-build-rosetta-mainnet: start-local-debian-repo ## Build the Rosetta Docker image for mainnet
	$(call build_docker_image,mina-rosetta,mainnet)

########################################
# Generate hardfork packages

.PHONY: hardfork-debian
hardfork-debian: SHELL := /bin/bash
hardfork-debian: #ocaml_checks ## Generate hardfork packages
	$(info 📦 Generating hardfork packages for network $(NETWORK_NAME))

	@BUILD_DIR=./_build \
	MINA_DEB_CODENAME=$(CODENAME) \
	BRANCH_NAME=$(BRANCH_NAME) \
	KEEP_MY_TAGS_INTACT=true \
	./scripts/hardfork/release/build-packages.sh daemon_devnet_hardfork


.PHONY: hardfork-docker
hardfork-docker: SHELL := /bin/bash
hardfork-docker: #ocaml_checks ## Generate hardfork packages
	$(info 📦 Generating hardfork docker for network $(NETWORK_NAME))

	$(MAKE) hardfork-debian
	$(MAKE) start-local-debian-repo

	@BUILD_DIR=./_build \
	MINA_DEB_CODENAME=$(CODENAME) \
	KEEP_MY_TAGS_INTACT=true \
	. ./scripts/export-git-env-vars.sh \
	&& ./scripts/docker/build.sh \
		--deb-codename $(CODENAME) \
		--service mina-daemon \
		--version "$$MINA_DEB_VERSION" \
		--branch $(BRANCH_NAME) \
		--network $(NETWORK_NAME) \
		--deb-suffix hardfork \
		--no-cache

	$(info 📦 stopping local Debian repository)
	@./scripts/debian/aptly.sh stop

########################################
# Generate odoc documentation

.PHONY: ml-docs
ml-docs: ocaml_checks ## Generate OCaml documentation
	dune build --profile=$(DUNE_PROFILE) @doc
