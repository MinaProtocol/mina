########################################
## Configuration

# Current OCaml version
OCAML_VERSION = "4.14.0"

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

# This commit hash
GITHASH := $(shell git rev-parse --short=8 HEAD)
GITLONGHASH := $(shell git rev-parse HEAD)

# Unique signature of libp2p code tree
LIBP2P_HELPER_SIG := $(shell cd src/app/libp2p_helper ; find . -type f -print0  | xargs -0 sha1sum | sort | sha1sum | cut -f 1 -d ' ')

########################################
## Help
.PHONY: help
help:
	@echo "Mina Makefile Targets:"
	@echo "======================="
	@echo "all                       - Clean and build the project"
	@echo "archive_blocks            - Build the archive_blocks executable"
	@echo "benchmarks                - Build benchmarking tools"
	@echo "build                     - Build the main project executables"
	@echo "build_all_sigs            - Build all signature variants of the daemon"
	@echo "build_archive             - Build the archive node"
	@echo "build_archive_utils       - Build archive node and related utilities"
	@echo "build_intgtest            - Build integration test tools"
	@echo "build_or_download_pv_keys - Build or download proving/verification keys"
	@echo "build_pv_keys             - Build proving/verification keys"
	@echo "build_rosetta             - Build Rosetta API components"
	@echo "build_rosetta_all_sigs    - Build all signature variants of Rosetta"
	@echo "check                     - Check that all OCaml packages build without issues"
	@echo "check-format              - Check formatting of OCaml code"
	@echo "check_opam_switch         - Verify the opam switch has correct packages"
	@echo "check-snarky-submodule    - Check the snarky submodule"
	@echo "clean                     - Remove build artifacts"
	@echo "coverage-html             - Generate HTML report from coverage data"
	@echo "coverage-summary          - Generate coverage summary report"
	@echo "deb                       - Build Debian package"
	@echo "dev                       - Alias for build"
	@echo "doc_diagrams              - Generate documentation diagrams"
	@echo "extract_blocks            - Build the extract_blocks executable"
	@echo "genesiskeys               - Generate and copy genesis keys"
	@echo "genesis_ledger            - Build runtime genesis ledger"
	@echo "genesis-ledger-ocaml      - Generate OCaml genesis ledger from daemon"
	@echo "heap_usage                - Build heap usage analysis tool"
	@echo "help                      - Display this help information"
	@echo "install                   - Install all the binaries and libraries to the"
	@echo "                            opam switch, and make it available in the PATH"
	@echo "libp2p_helper             - Build libp2p helper"
	@echo "missing_blocks_auditor    - Build missing blocks auditor tool"
	@echo "ml-docs                   - Generate OCaml documentation"
	@echo "ocaml_checks              - Run OCaml version and config checks"
	@echo "ocaml_version             - Check OCaml version"
	@echo "ocaml_word_size           - Check OCaml word size"
	@echo "patch_archive_test        - Build the patch archive test"
	@echo "publish-macos             - Publish macOS artifacts"
	@echo "reformat                  - Reformat all OCaml code"
	@echo "reformat-diff             - Reformat only modified OCaml files"
	@echo "replayer                  - Build the replayer tool"
	@echo "rosetta_lib_encodings     - Test Rosetta library encodings"
	@echo "switch                    - Set up the opam switch"
	@echo "test-coverage             - Run tests with coverage instrumentation"
	@echo "test-ppx                  - Test PPX extensions"
	@echo "uninstall                 - Uninstall all binaries and libraries from the opam switch"
	@echo "update-graphql            - Update GraphQL schema"
	@echo "zkapp_limits              - Build ZkApp limits tool"

########################################
## Code

.PHONY: all
all: clean build

.PHONY: clean
clean:
	$(info Removing previous build artifacts)
	@rm -rf _build
	@rm -rf Cargo.lock target
	@rm -rf src/$(COVERAGE_DIR)
	@rm -rf src/app/libp2p_helper/result src/libp2p_ipc/libp2p_ipc.capnp.go

.PHONY: switch
switch:
	./scripts/update-opam-switch.sh

# enforces the OCaml version being used
.PHONY: ocaml_version
ocaml_version: switch
	@if ! ocamlopt -config | grep "version:" | grep $(OCAML_VERSION); then echo "incorrect OCaml version, expected version $(OCAML_VERSION)" ; exit 1; fi

# enforce machine word size
.PHONY: ocaml_word_size
ocaml_word_size: switch
	@if ! ocamlopt -config | grep "word_size:" | grep $(WORD_SIZE); then echo "invalid machine word size, expected $(WORD_SIZE)" ; exit 1; fi


# Checks that the current opam switch contains the packages from opam.export at the same version.
# This check is disabled in the pure nix environment (that does not use opam).
.PHONY: check_opam_switch
check_opam_switch: switch
ifneq ($(DISABLE_CHECK_OPAM_SWITCH), true)
	@which check_opam_switch 2>/dev/null >/dev/null || ( echo "The check_opam_switch binary was not found in the PATH, try: opam switch import opam.export" >&2 && exit 1 )
	@check_opam_switch opam.export
endif

.PHONY: ocaml_checks
ocaml_checks: switch ocaml_version ocaml_word_size check_opam_switch

.PHONY: libp2p_helper
libp2p_helper:
ifeq (, $(MINA_LIBP2P_HELPER_PATH))
	make -C src/app/libp2p_helper
endif

.PHONY: genesis_ledger
genesis_ledger: ocaml_checks
	$(info Building runtime_genesis_ledger)
	(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	env MINA_COMMIT_SHA1=$(GITLONGHASH) \
	dune exec \
		--profile=$(DUNE_PROFILE) \
		src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe -- \
		--genesis-dir $(GENESIS_DIR)
	$(info Genesis ledger and genesis proof generated)

# Checks that every OCaml packages in the project build without issues
.PHONY: check
check: ocaml_checks libp2p_helper
	dune build @src/check

.PHONY: build
build: ocaml_checks reformat-diff libp2p_helper
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
build_all_sigs: ocaml_checks reformat-diff libp2p_helper build
	$(info Starting Build)
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	env MINA_COMMIT_SHA1=$(GITLONGHASH) \
	dune build \
		src/app/cli/src/mina_testnet_signatures.exe \
		src/app/cli/src/mina_mainnet_signatures.exe \
		--profile=$(DUNE_PROFILE)
	$(info Build complete)

.PHONY: build_archive
build_archive: ocaml_checks reformat-diff
	$(info Starting Build)
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		src/app/archive/archive.exe \
		--profile=$(DUNE_PROFILE)
	$(info Build complete)

.PHONY: build_archive_utils
build_archive_utils: ocaml_checks reformat-diff
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
build_rosetta: ocaml_checks
	$(info Starting Build)
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		src/app/archive/archive.exe \
		src/app/rosetta/rosetta.exe \
		src/app/rosetta/ocaml-signer/signer.exe \
		--profile=$(DUNE_PROFILE)
	$(info Build complete)

.PHONY: build_rosetta_all_sigs
build_rosetta_all_sigs: ocaml_checks
	$(info Starting Build)
	(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		src/app/archive/archive.exe \
		src/app/archive/archive_testnet_signatures.exe \
		src/app/archive/archive_mainnet_signatures.exe \
		src/app/rosetta/rosetta.exe \
		src/app/rosetta/rosetta_testnet_signatures.exe \
		src/app/rosetta/rosetta_mainnet_signatures.exe \
		src/app/rosetta/ocaml-signer/signer.exe \
		--profile=$(DUNE_PROFILE)
	$(info Build complete)

.PHONY: build_intgtest
build_intgtest: ocaml_checks
	$(info Starting Build)
	@dune build \
		--profile=$(DUNE_PROFILE) \
		src/app/test_executive/test_executive.exe \
		src/app/logproc/logproc.exe
	$(info Build complete)

.PHONY: rosetta_lib_encodings
rosetta_lib_encodings: ocaml_checks
	$(info Starting Build)
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
	  src/lib/rosetta_lib/test/test_encodings.exe \
	  --profile=mainnet
	$(info Build complete)

.PHONY: replayer
replayer: ocaml_checks
	$(info Starting Build)
	@ulimit -s 65532 && (ulimit -n 10240 || true) && \
	dune build \
		src/app/replayer/replayer.exe \
		--profile=devnet
	$(info Build complete)

.PHONY: missing_blocks_auditor
missing_blocks_auditor: ocaml_checks
	$(info Starting Build)
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		src/app/missing_blocks_auditor/missing_blocks_auditor.exe \
		--profile=testnet_postake_medium_curves
	$(info Build complete)

.PHONY: extract_blocks
extract_blocks: ocaml_checks
	$(info Starting Build)
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		src/app/extract_blocks/extract_blocks.exe \
		--profile=testnet_postake_medium_curves
	$(info Build complete)

.PHONY: archive_blocks
archive_blocks: ocaml_checks
	$(info Starting Build)
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		src/app/archive_blocks/archive_blocks.exe \
		--profile=testnet_postake_medium_curves
	$(info Build complete)

.PHONY: patch_archive_test
patch_archive_test: ocaml_checks
	$(info Starting Build)
	@ulimit -s 65532 && (ulimit -n 10240 || true) && \
	dune build \
	  src/app/patch_archive_test/patch_archive_test.exe \
		--profile=testnet_postake_medium_curves
	$(info Build complete)

.PHONY: heap_usage
heap_usage: ocaml_checks
	$(info Starting Build)
	@ulimit -s 65532 && (ulimit -n 10240 || true) && \
	dune build \
		src/app/heap_usage/heap_usage.exe \
		--profile=devnet
	$(info Build complete)

.PHONY: zkapp_limits
zkapp_limits: ocaml_checks
	$(info Starting Build)
	@ulimit -s 65532 && (ulimit -n 10240 || true) && \
	dune build \
		src/app/zkapp_limits/zkapp_limits.exe \
		--profile=devnet
	$(info Build complete)

.PHONY: dev
dev: build

.PHONY: update-graphql
update-graphql:
	@(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	dune build \
		--profile=$(DUNE_PROFILE) \
		graphql_schema.json

########################################
## Lint

.PHONY: reformat
reformat: ocaml_checks
	dune exec \
		--profile=$(DUNE_PROFILE) \
	  src/app/reformat/reformat.exe -- \
		-path .

.PHONY: reformat-diff
reformat-diff:
	@FILES=$$(git status -s | cut -c 4- | grep '\.mli\?$$' | while IFS= read -r f; do stat "$$f" >/dev/null 2>&1 && echo "$$f"; done); \
	if [ -n "$$FILES" ]; then ocamlformat --doc-comments=before --inplace $$FILES; fi

.PHONY: check-format
check-format: ocaml_checks
	dune exec \
		--profile=$(DUNE_PROFILE) \
	  src/app/reformat/reformat.exe -- \
		-path . -check

.PHONY: check-snarky-submodule
check-snarky-submodule:
	./scripts/check-snarky-submodule.sh

.PHONY: install
install:
	@dune build @install
	@dune install
	@cp ${OPAM_SWITCH_PREFIX}/bin/signer ${OPAM_SWITCH_PREFIX}/bin/mina-ocaml-signer
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
	@rm ${OPAM_SWITCH_PREFIX}/bin/mina-ocaml-signer
########################################
## Artifacts

.PHONY: build_pv_keys
build_pv_keys: ocaml_checks
	$(info Building keys)
	(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	env MINA_COMMIT_SHA1=$(GITLONGHASH) \
	dune exec \
		--profile=$(DUNE_PROFILE) \
	  src/lib/snark_keys/gen_keys/gen_keys.exe -- \
		--generate-keys-only
	$(info Keys built)

.PHONY: build_or_download_pv_keys
build_or_download_pv_keys: ocaml_checks
	$(info Building keys)
	(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && \
	env MINA_COMMIT_SHA1=$(GITLONGHASH) \
	dune exec \
		--profile=$(DUNE_PROFILE) \
		src/lib/snark_keys/gen_keys/gen_keys.exe -- \
		--generate-keys-only
	$(info Keys built)

.PHONY: genesiskeys
genesiskeys:
	@mkdir -p /tmp/artifacts
	@cp _build/default/src/lib/key_gen/sample_keypairs.ml /tmp/artifacts/.
	@cp _build/default/src/lib/key_gen/sample_keypairs.json /tmp/artifacts/.


##############################################
## External toolings

# Keep this in line with ./dockerfiles/Dockerfile-mina-rosetta
.PHONY: install-rosetta-cli
install-rosetta-cli:
	curl -L "https://github.com/coinbase/mesh-cli/archive/refs/tags/v0.10.1.tar.gz" \
		-o "/tmp/v0.10.1.tar.gz"
	tar xzf "/tmp/v0.10.1.tar.gz" -C "/tmp"
	cd /tmp/mesh-cli-0.10.1 \
    && go mod edit -replace github.com/coinbase/mesh-sdk-go@v0.8.1=github.com/MinaProtocol/rosetta-sdk-go@stake-delegation-v1 \
    && go mod tidy \
    && GOBIN=${OPAM_SWITCH_PREFIX}/bin go install

.PHONY: setup-rosetta-pg-cluster
setup-rosetta-pg-cluster:
	@POSTGRES_VERSION=$$(psql -V | cut -d " " -f 3 | sed 's/\.[[:digit:]]*$$//') && \
	pg_createcluster --start \
		-d /data/postgresql \
		--createclusterconf \
		./src/app/rosetta/scripts/postgresql.conf \
		$$POSTGRES_VERSION \
		main

##############################################
## Genesis ledger in OCaml from running daemon

.PHONY: genesis-ledger-ocaml
genesis-ledger-ocaml:
	@./scripts/generate-genesis-ledger.py .genesis-ledger.ml.jinja

########################################
## Tests

.PHONY: test-ppx
test-ppx:
	$(MAKE) -C src/lib/ppx_mina/tests

########################################
## Benchmarks

.PHONY: benchmarks
benchmarks: ocaml_checks
	dune build src/app/benchmarks/benchmarks.exe

########################################
# Coverage testing and output

.PHONY: test-coverage
test-coverage: SHELL := /bin/bash
test-coverage: libp2p_helper
	scripts/create_coverage_profiles.sh

# we don't depend on test-coverage, which forces a run of all unit tests
.PHONY: coverage-html
coverage-html:
ifeq ($(shell find _build/default -name bisect\*.out),"")
	echo "No coverage output; run make test-coverage"
else
	bisect-ppx-report html --source-path=_build/default --coverage-path=_build/default
endif

.PHONY: coverage-summary
coverage-summary:
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
doc_diagrams: $(addsuffix .png,$(wildcard $(doc_diagram_sources)))

########################################
# Generate odoc documentation

.PHONY: ml-docs
ml-docs: ocaml_checks
	dune build --profile=$(DUNE_PROFILE) @doc
