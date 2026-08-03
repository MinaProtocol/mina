##@ Lint & format

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
	hadolint --ignore DL3008 --ignore DL3002 --ignore DL3013 --ignore DL3007 --ignore DL3006 --ignore DL3028 dockerfiles/Dockerfile-* dockerfiles/toolchain/* dockerfiles/stages/1-base-deps dockerfiles/stages/daemon/* dockerfiles/stages/archive/* dockerfiles/stages/rosetta/*
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
		dockerfiles/toolchain/* \
		dockerfiles/stages/1-base-deps \
		dockerfiles/stages/daemon/* \
		dockerfiles/stages/archive/* \
		dockerfiles/stages/rosetta/*
endif

