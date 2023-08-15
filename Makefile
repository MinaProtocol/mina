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
## Code

all: clean build

clean:
	$(info Removing previous build artifacts)
	@rm -rf _build
	@rm -rf Cargo.lock target
	@rm -rf src/$(COVERAGE_DIR)
	@rm -rf src/app/libp2p_helper/result src/libp2p_ipc/libp2p_ipc.capnp.go

# enforces the OCaml version being used
ocaml_version:
	@if ! ocamlopt -config | grep "version:" | grep $(OCAML_VERSION); then echo "incorrect OCaml version, expected version $(OCAML_VERSION)" ; exit 1; fi

# enforce machine word size
ocaml_word_size:
	@if ! ocamlopt -config | grep "word_size:" | grep $(WORD_SIZE); then echo "invalid machine word size, expected $(WORD_SIZE)" ; exit 1; fi


# Checks that the current opam switch contains the packages from opam.export at the same version.
# This check is disabled in the pure nix environment (that does not use opam).
check_opam_switch:
ifneq ($(DISABLE_CHECK_OPAM_SWITCH), true)
    ifeq (, $(shell which check_opam_switch))
	$(warning The check_opam_switch binary was not found in the PATH.)
	$(error The current opam switch should likely be updated by running: "opam switch import opam.export")
    else
	check_opam_switch opam.export
    endif
endif

ocaml_checks: ocaml_version ocaml_word_size check_opam_switch

libp2p_helper:
	make -C src/app/libp2p_helper

genesis_ledger: ocaml_checks
	$(info Building runtime_genesis_ledger)
	ulimit -s 65532 && (ulimit -n 10240 || true) && env MINA_COMMIT_SHA1=$(GITLONGHASH) dune exec --profile=$(DUNE_PROFILE) src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe -- --genesis-dir $(GENESIS_DIR)
	$(info Genesis ledger and genesis proof generated)

# Checks that every OCaml packages in the project build without issues
check: ocaml_checks libp2p_helper
	dune build @src/check

build: ocaml_checks reformat-diff libp2p_helper
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && env MINA_COMMIT_SHA1=$(GITLONGHASH) dune build src/app/logproc/logproc.exe src/app/cli/src/mina.exe --profile=$(DUNE_PROFILE)
	$(info Build complete)

build_all_sigs: ocaml_checks reformat-diff libp2p_helper
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && env MINA_COMMIT_SHA1=$(GITLONGHASH) dune build src/app/logproc/logproc.exe src/app/cli/src/mina.exe src/app/cli/src/mina_testnet_signatures.exe src/app/cli/src/mina_mainnet_signatures.exe --profile=$(DUNE_PROFILE)
	$(info Build complete)

build_archive: ocaml_checks reformat-diff
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/archive/archive.exe --profile=$(DUNE_PROFILE)
	$(info Build complete)

build_archive_all_sigs: ocaml_checks reformat-diff
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/archive/archive.exe src/app/archive/archive_testnet_signatures.exe src/app/archive/archive_mainnet_signatures.exe --profile=$(DUNE_PROFILE)
	$(info Build complete)

build_rosetta: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/archive/archive.exe src/app/rosetta/rosetta.exe src/app/rosetta/ocaml-signer/signer.exe --profile=$(DUNE_PROFILE)
	$(info Build complete)

build_rosetta_all_sigs: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/archive/archive.exe src/app/archive/archive_testnet_signatures.exe src/app/archive/archive_mainnet_signatures.exe src/app/rosetta/rosetta.exe src/app/rosetta/rosetta_testnet_signatures.exe src/app/rosetta/rosetta_mainnet_signatures.exe src/app/rosetta/ocaml-signer/signer.exe src/app/rosetta/ocaml-signer/signer_testnet_signatures.exe src/app/rosetta/ocaml-signer/signer_mainnet_signatures.exe --profile=$(DUNE_PROFILE)
	$(info Build complete)

build_intgtest: ocaml_checks
	$(info Starting Build)
	dune build --profile=$(DUNE_PROFILE) src/app/test_executive/test_executive.exe src/app/logproc/logproc.exe
	$(info Build complete)

client_sdk: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/client_sdk/client_sdk.bc.js
	$(info Build complete)

client_sdk_test_sigs: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/client_sdk/tests/test_signatures.exe --profile=mainnet
	$(info Build complete)

client_sdk_test_sigs_nonconsensus: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/client_sdk/tests/test_signatures_nonconsensus.exe --profile=nonconsensus_mainnet
	$(info Build complete)

snarkyjs: ocaml_checks
	$(info Starting Build)
	(ulimit -s 65532) && (ulimit -n 10240 || true) \
	&& bash ./src/lib/snarkyjs/src/bindings/scripts/build-snarkyjs-node.sh
	$(info Build complete)

snarkyjs_no_types: ocaml_checks
	$(info Starting Build)
	((ulimit -s 65532) || true) && (ulimit -n 10240 || true) \
	&& bash ./src/lib/snarkyjs/src/bindings/scripts/build-snarkyjs-node-artifacts.sh
	$(info Build complete)

rosetta_lib_encodings: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/lib/rosetta_lib/test/test_encodings.exe --profile=mainnet
	$(info Build complete)

rosetta_lib_encodings_nonconsensus: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/nonconsensus/rosetta_lib/test/test_encodings.exe --profile=nonconsensus_mainnet
	$(info Build complete)

dhall_types: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/dhall_types/dump_dhall_types.exe --profile=dev
	$(info Build complete)

replayer: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/replayer/replayer.exe --profile=devnet
	$(info Build complete)

delegation_compliance: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/delegation_compliance/delegation_compliance.exe --profile=testnet_postake_medium_curves
	$(info Build complete)

missing_blocks_auditor: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/missing_blocks_auditor/missing_blocks_auditor.exe --profile=testnet_postake_medium_curves
	$(info Build complete)

extract_blocks: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/extract_blocks/extract_blocks.exe --profile=testnet_postake_medium_curves
	$(info Build complete)

archive_blocks: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/archive_blocks/archive_blocks.exe --profile=testnet_postake_medium_curves
	$(info Build complete)

patch_archive_test: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/patch_archive_test/patch_archive_test.exe --profile=testnet_postake_medium_curves
	$(info Build complete)

genesis_ledger_from_tsv: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/genesis_ledger_from_tsv/genesis_ledger_from_tsv.exe --profile=testnet_postake_medium_curves
	$(info Build complete)

swap_bad_balances: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/swap_bad_balances/swap_bad_balances.exe --profile=testnet_postake_medium_curves
	$(info Build complete)

heap_usage: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/heap_usage/heap_usage.exe --profile=devnet
	$(info Build complete)

zkapp_limits: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/zkapp_limits/zkapp_limits.exe --profile=devnet
	$(info Build complete)

dev: build

macos-portable:
	@rm -rf _build/coda-daemon-macos/
	@rm -rf _build/coda-daemon-macos.zip
	@./scripts/macos-portable.sh _build/default/src/app/cli/src/mina.exe src/app/libp2p_helper/result/bin/libp2p_helper _build/coda-daemon-macos
	@cp -a package/keys/. _build/coda-daemon-macos/keys/
	@cd _build/coda-daemon-macos && zip -r ../coda-daemon-macos.zip .
	@echo Find coda-daemon-macos.zip inside _build/

update-graphql:
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build --profile=$(DUNE_PROFILE) graphql_schema.json

########################################
## Lint

reformat: ocaml_checks
	dune exec --profile=$(DUNE_PROFILE) src/app/reformat/reformat.exe -- -path .

reformat-diff:
	@ocamlformat --doc-comments=before --inplace $(shell git status -s | cut -c 4- | grep '\.mli\?$$' | while IFS= read -r f; do stat "$$f" >/dev/null 2>&1 && echo "$$f"; done) || true

check-format: ocaml_checks
	dune exec --profile=$(DUNE_PROFILE) src/app/reformat/reformat.exe -- -path . -check

check-snarky-submodule:
	./scripts/check-snarky-submodule.sh

check-proof-systems-submodule:
	./scripts/check-proof-systems-submodule.sh

#######################################
## Environment setup

macos-setup-download:
	./scripts/macos-setup-brew.sh

########################################
## Artifacts

publish-macos:
	@./scripts/publish-macos.sh

deb:
	./scripts/rebuild-deb.sh
	./scripts/archive/build-release-archives.sh
	@mkdir -p /tmp/artifacts
	@cp _build/mina*.deb /tmp/artifacts/.

deb_optimized:
	./scripts/rebuild-deb.sh "optimized"
	./scripts/archive/build-release-archives.sh
	@mkdir -p /tmp/artifacts
	@cp _build/mina*.deb /tmp/artifacts/.

test_executive_deb:
	./scripts/rebuild_test_executive_deb.sh

build_pv_keys: ocaml_checks
	$(info Building keys)
	ulimit -s 65532 && (ulimit -n 10240 || true) && env MINA_COMMIT_SHA1=$(GITLONGHASH) dune exec --profile=$(DUNE_PROFILE) src/lib/snark_keys/gen_keys/gen_keys.exe -- --generate-keys-only
	$(info Keys built)

build_or_download_pv_keys: ocaml_checks
	$(info Building keys)
	ulimit -s 65532 && (ulimit -n 10240 || true) && env MINA_COMMIT_SHA1=$(GITLONGHASH) dune exec --profile=$(DUNE_PROFILE) src/lib/snark_keys/gen_keys/gen_keys.exe -- --generate-keys-only
	$(info Keys built)

publish_deb:
	@./scripts/publish-deb.sh

publish_debs:
	@./buildkite/scripts/publish-deb.sh

genesiskeys:
	@mkdir -p /tmp/artifacts
	@cp _build/default/src/lib/key_gen/sample_keypairs.ml /tmp/artifacts/.
	@cp _build/default/src/lib/key_gen/sample_keypairs.json /tmp/artifacts/.

##############################################
## Genesis ledger in OCaml from running daemon

genesis-ledger-ocaml:
	@./scripts/generate-genesis-ledger.py .genesis-ledger.ml.jinja

########################################
## Tests

test-ppx:
	$(MAKE) -C src/lib/ppx_mina/tests

########################################
## Benchmarks

benchmarks: ocaml_checks
	dune build src/app/benchmarks/benchmarks.exe

########################################
# Coverage testing and output

test-coverage: SHELL := /bin/bash
test-coverage: libp2p_helper
	scripts/create_coverage_profiles.sh

# we don't depend on test-coverage, which forces a run of all unit tests
coverage-html:
ifeq ($(shell find _build/default -name bisect\*.out),"")
	echo "No coverage output; run make test-coverage"
else
	bisect-ppx-report html --source-path=_build/default --coverage-path=_build/default
endif

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

doc_diagram_sources=$(addprefix docs/res/,*.dot *.tex *.conv.tex)
doc_diagram_sources+=$(addprefix rfcs/res/,*.dot *.tex *.conv.tex)
doc_diagrams: $(addsuffix .png,$(wildcard $(doc_diagram_sources)))

########################################
# Generate odoc documentation

ml-docs: ocaml_checks
	dune build --profile=$(DUNE_PROFILE) @doc

########################################
# To avoid unintended conflicts with file names, always add new targets to .PHONY
# unless there is a reason not to.
# https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html
# HACK: cat Makefile | egrep '^\w.*' | sed 's/:/ /' | awk '{print $1}' | grep -v myprocs | sort | xargs

.PHONY: all build check-format clean deb dev mina-docker reformat doc_diagrams ml-docs macos-setup macos-setup-download setup-opam libp2p_helper dhall_types replayer missing_blocks_auditor extract_blocks archive_blocks genesis_ledger_from_tsv ocaml_version ocaml_word_size ocaml_checks
