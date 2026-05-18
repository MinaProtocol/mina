export HOST_UID := $(shell id -u)
export HOST_GID := $(shell id -g)

REPO_ROOT := $(realpath $(dir $(lastword $(MAKEFILE_LIST)))/..)
DEVCONTAINER_SRC := devcontainer-template
# Installed under a "mina" subdirectory rather than at the top of
# .devcontainer/ so it coexists cleanly with any other devcontainer.json
# the user may already have at .devcontainer/devcontainer.json or
# .devcontainer/<other-name>/devcontainer.json. VS Code will list both as
# labeled options in "Reopen in Container".
DEVCONTAINER_DST := $(REPO_ROOT)/.devcontainer/mina

all:
	docker compose up -d
	@sleep 1
	@docker compose logs mina --tail=20
	@echo
	@echo "Container is running. Connect with: make ssh"

rebuild:
	docker compose down --volumes
	docker compose build --no-cache
	docker compose up -d
	@sleep 1
	@docker compose logs mina --tail=20
	@echo
	@echo "Container is running. Connect with: make ssh"

ssh:
	docker exec -u opam -it -w "/mina" mina /bin/bash

# Opt-in VS Code Dev Container setup. Copies the template from
# dev/devcontainer-template/ to <repo>/.devcontainer/ so that VS Code's
# "Reopen in Container" workflow lights up. .devcontainer/ is gitignored,
# so the user's copy can be customized without affecting the canonical
# template.
devcontainer:
	@if [ -e "$(DEVCONTAINER_DST)" ]; then \
		echo "$(DEVCONTAINER_DST) already exists; not overwriting."; \
		echo "Delete it and re-run \`make devcontainer\` to refresh from the template."; \
		exit 1; \
	fi
	@mkdir -p "$(DEVCONTAINER_DST)"
	@cp "$(DEVCONTAINER_SRC)/devcontainer.json" "$(DEVCONTAINER_DST)/devcontainer.json"
	@cp "$(DEVCONTAINER_SRC)/init.sh" "$(DEVCONTAINER_DST)/init.sh"
	@chmod +x "$(DEVCONTAINER_DST)/init.sh"
	@echo "Created $(DEVCONTAINER_DST) from dev/$(DEVCONTAINER_SRC)/."
	@echo "Open the repo in VS Code and run 'Dev Containers: Reopen in Container'."

.PHONY: all rebuild ssh devcontainer
