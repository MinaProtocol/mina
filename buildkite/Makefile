# Use gsed on macOS (gnu-sed is enforced)
ifeq ($(shell uname -s),Darwin)
    SED := gsed
else
    SED := sed
endif

.PHONY: help
help: ## Show this help
	@echo "Available targets:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: check_syntax
check_syntax: ## Check dhall syntax for all files
	# globstar doesn't work on macOS bash :facepalm:, so we can't glob
	# xargs will short-circuit if a command fails with code 255
	find ./src/ -name "*.dhall" -print0 | xargs -I{} -0 -n1 bash -c 'echo "{}" &&  dhall --file {} > /dev/null || exit 255'

.PHONY: convert_backticks_to_ifs
convert_backticks_to_ifs:
	$(SED) -i 's/`if` =/if =/g' src/Command/Base.dhall

.PHONY: convert_ifs_to_backticks
convert_ifs_to_backticks:
	$(SED) -i 's/if =/`if` =/g' src/Command/Base.dhall

.PHONY: check_lint
check_lint: convert_backticks_to_ifs ## Check dhall lint for all files
	find ./src/ -name "*.dhall" -print0 | xargs -I{} -0 -n1 bash -c 'echo "{}" && dhall --ascii lint --check --inplace {} || exit 255'

.PHONY: check_format
check_format: convert_backticks_to_ifs ## Check dhall format for all files
	@echo "Dhall version: $$(dhall --version)"
	find ./src/ -name "*.dhall" -print0 | xargs -I{} -0 -n1 bash -c 'echo "{} format" && dhall --ascii format --check --inplace {} || exit 255'

.PHONY: lint
lint: ## Lint all dhall files in place
	find ./src/ -name "*.dhall" -print0 | xargs -I{} -0 -n1 bash -c 'echo "{}" && dhall --ascii lint --inplace {} || exit 255'
	$(MAKE) convert_ifs_to_backticks

.PHONY: format
format: ## Format all dhall files in place
	find ./src/ -name "*.dhall" -print0 | xargs -I{} -0 -n1 bash -c 'echo "{}" && dhall --ascii format --inplace {} || exit 255'
	$(MAKE) convert_ifs_to_backticks

.PHONY: dump_pipelines
dump_pipelines: ## Dump dhall pipelines to temporary directory
	$(eval TMP := $(shell mktemp -d))
	./scripts/dhall/dump_dhall_to_pipelines.sh ./src "$(TMP)"

.PHONY: check_deps
check_deps: dump_pipelines ## Check pipeline dependencies
	python3 scripts/dhall/checker.py --root "$(TMP)" deps

.PHONY: check_dirty
check_dirty: dump_pipelines ## Check dirty-when configurations
	python3 scripts/dhall/checker.py --root "$(TMP)" dirty-when  --repo "$(PWD)/../"

.PHONY: check_dups
check_dups: dump_pipelines ## Check for duplicate pipelines
	python3 scripts/dhall/checker.py --root "$(TMP)" dups

.PHONY: check_names
check_names: dump_pipelines ## Check pipeline names
	python3 scripts/dhall/checker.py --root "$(TMP)" names

.PHONY: test_monorepo
test_monorepo: ## Run monorepo tests
	./scripts/test_monorepo.sh

.PHONY: all
all: check_syntax lint format check_deps check_dirty check_dups check_names test_monorepo ## Run all checks
