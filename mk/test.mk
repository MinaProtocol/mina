##@ Test

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

