# Deploy and check the Cloud Function that reads the "!ci-..." PR comments.
#
# The function is deployed by hand. In July 2026 a deploy was made from a
# working copy that held changes which were never committed, so the function
# that ran held a command (!ci-single-me) that was in no commit, and a deploy
# from the repository would have deleted it. The `check` target finds that
# situation, and `deploy` refuses to run with a dirty working tree.

SHELL := /bin/bash

PROJECT  ?= o1labs-192920
REGION   ?= us-central1
FUNCTION ?= githubWebhookHandler
ENTRY    ?= githubWebhookHandler
MEMORY   ?= 128MB

SOURCE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Keep the runtime of the function that is deployed. A deploy that names
# another runtime than the one in use is a change nobody asked for, and the
# runtime in the README (nodejs10) is no longer offered by Google.
RUNTIME ?= $(shell gcloud functions describe $(FUNCTION) \
	--project $(PROJECT) --region $(REGION) \
	--format='value(runtime)' 2>/dev/null)

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}'

.PHONY: describe
describe: ## Show the deployed function
	@gcloud functions describe $(FUNCTION) \
		--project $(PROJECT) --region $(REGION) \
		--format='table(name.basename(), status, runtime, entryPoint, updateTime)'

.PHONY: test
test: ## Run the unit tests (no dependencies needed)
	@node $(SOURCE_DIR)test/safe-input.test.js
	@node $(SOURCE_DIR)test/artifacts.test.js

.PHONY: check
check: ## Compare the deployed function with this directory
	@$(SOURCE_DIR)check-deployed-parity.sh \
		--project $(PROJECT) --region $(REGION) --function $(FUNCTION)

.PHONY: check-env
check-env:
	@if [ -z "$$GITHUB_SECRET" ]; then \
		echo "Error: GITHUB_SECRET is not set. Take it from the AWS secret store (us-west-2)." >&2; exit 1; fi
	@if [ -z "$$BUILDKITE_API_ACCESS_TOKEN" ]; then \
		echo "Error: BUILDKITE_API_ACCESS_TOKEN is not set. Take it from the AWS secret store (us-west-2)." >&2; exit 1; fi
	@if [ -z "$(RUNTIME)" ]; then \
		echo "Error: cannot read the runtime of the deployed function." >&2; \
		echo "       Check your gcloud login, or give one: make deploy RUNTIME=nodejs20" >&2; exit 1; fi

.PHONY: check-clean
check-clean:
	@if [ -n "$$ALLOW_DIRTY" ]; then \
		echo "⚠️  ALLOW_DIRTY is set: deploying a working tree that may hold changes that are not committed."; \
	elif [ -n "$$(git -C $(SOURCE_DIR) status --porcelain -- $(SOURCE_DIR))" ]; then \
		echo "Error: this directory holds changes that are not committed." >&2; \
		git -C $(SOURCE_DIR) status --short -- $(SOURCE_DIR) >&2; \
		echo "" >&2; \
		echo "       Deploying now would put code in production that is in no commit," >&2; \
		echo "       which is how the July 2026 difference was made. Commit first, or" >&2; \
		echo "       use 'make deploy ALLOW_DIRTY=1' if you accept that." >&2; \
		exit 1; \
	fi

.PHONY: deploy
deploy: test check-env check-clean ## Deploy this directory to Google Cloud
	@echo "Deploying $(FUNCTION) to $(PROJECT)/$(REGION) with runtime $(RUNTIME)"
	@echo "From commit: $$(git -C $(SOURCE_DIR) rev-parse --short HEAD)"
	cd $(SOURCE_DIR) && gcloud functions deploy $(FUNCTION) \
		--project $(PROJECT) \
		--region $(REGION) \
		--trigger-http \
		--runtime $(RUNTIME) \
		--memory $(MEMORY) \
		--entry-point $(ENTRY) \
		--source . \
		--set-env-vars GITHUB_SECRET=$$GITHUB_SECRET,BUILDKITE_API_ACCESS_TOKEN=$$BUILDKITE_API_ACCESS_TOKEN
	@echo ""
	@echo "Checking that the function which is deployed is now this directory:"
	@$(MAKE) --no-print-directory check
