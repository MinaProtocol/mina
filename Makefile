# Mina's build system.
#
# Targets live in mk/*.mk, grouped by concern (build, test, lint, coverage,
# debian, docker). Run `make help` to list them by section. mk/config.mk is
# included first so its variables and functions are available to every other
# include.

.DEFAULT_GOAL := help

include mk/config.mk
include mk/build.mk
include mk/lint.mk
include mk/test.mk
include mk/coverage.mk
include mk/debian.mk
include mk/docker.mk

##@ General
.PHONY: help
help: ## Show this help, grouped by section
	@awk 'BEGIN {FS = ":.*##"} \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5); next } \
		/^[a-zA-Z0-9_%.-]+:.*##/ { printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2 }' \
		$(MAKEFILE_LIST)
