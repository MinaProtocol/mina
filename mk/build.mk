##@ Build

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
		src/app/mina_graphql_client/mina_graphql_client_app.exe \
		src/app/mina_healthcheck/mina_healthcheck.exe \
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
		src/app/mina_graphql_client/mina_graphql_client_app.exe \
		src/app/mina_healthcheck/mina_healthcheck.exe \
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

.PHONY: build-mina
build-mina: ocaml_checks reformat-diff libp2p_helper build ## Build mina apps
	$(info 🏗️  Building on commit $(GITLONGHASH))
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	env MINA_COMMIT_SHA1=$(GITLONGHASH) \
	dune build \
		src/app/cli/src/mina.exe \
		src/app/rosetta/rosetta.exe \
		src/app/rosetta/ocaml-signer/signer.exe \
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
		src/app/dump_slot_ledger/dump_slot_ledger.exe \
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
		src/test/node_status_mock_server/node_status_mock_server.exe \
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

.PHONY: build-rosetta-lib-encodings
build-rosetta-lib-encodings: ocaml_checks ## Test Rosetta library encodings
	$(info 🏗️  Building Rosetta library encodings with profile $(DUNE_PROFILE) and commit $(GITLONGHASH))
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
	  src/lib/rosetta_lib/test/test_encodings.exe \
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

