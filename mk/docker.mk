##@ Docker images

########################################
# Docker images

.PHONY: start-local-debian-repo
start-local-debian-repo: ## Stage locally-built debians into the docker build context
	$(info 📦 Staging local debians from _build into the dockerfiles/ build context)

	@# scripts/docker/build.sh stages any .deb files found in the docker build
	@# context (dockerfiles/) into dockerfiles/_debs and generates an apt index
	@# there, which the Dockerfiles install from. Make the locally-built debians
	@# available by copying them into the context.
	@cp -f _build/*.deb dockerfiles/ \
		&& echo "✅ Local debians staged"

# General function for building Docker images.
# $(1)=service  $(2)=network  $(3)=extra build.sh args (optional, e.g. --deb-suffix generic)
define build_docker_image
	$(info 🐳 Building Docker image for service $(1) with \
		codename $(CODENAME) \
		and version $$MINA_DEB_VERSION \
		and branch $$GITBRANCH \
		and network $(2))

	@export BUILD_DIR=./_build MINA_DEB_CODENAME=$(CODENAME) KEEP_MY_TAGS_INTACT=true && \
	. ./scripts/export-git-env-vars.sh \
	&& ./scripts/docker/build.sh \
		--deb-codename $(CODENAME) \
		--service $(1) \
		--version "$$MINA_DEB_VERSION" \
		--branch "$$GITBRANCH" \
		--deb-legacy-version "$${MINA_DEB_LEGACY_VERSION:-}" \
		--docker-registry "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo" \
		--network $(2) \
		$(3) \
		$(DOCKER_LOAD_ONLY_ARG) \
		$(DOCKER_NO_CACHE)

	$(info 📦 cleaning up staged local debians)
	@rm -f dockerfiles/*.deb
endef


.PHONY: docker-build-toolchain
docker-build-toolchain: ## Build the toolchain to be used in CI
	@BUILD_DIR=./_build \
		./scripts/docker/build.sh \
		--deb-codename $(CODENAME) \
		--service mina-toolchain \
		--version mina-toolchain-$(CODENAME)-$(GITHASH)

.PHONY: docker-build-archive-devnet
docker-build-archive-devnet: SHELL := /bin/bash
docker-build-archive-devnet: start-local-debian-repo ## Build the archive Docker image for devnet
	$(call build_docker_image,mina-archive,devnet)

.PHONY: docker-build-archive-mainnet
docker-build-archive-mainnet: SHELL := /bin/bash
docker-build-archive-mainnet: start-local-debian-repo ## Build the archive Docker image for mainnet
	$(call build_docker_image,mina-archive,mainnet)

.PHONY: docker-build-daemon-devnet-generic
docker-build-daemon-devnet-generic: SHELL := /bin/bash
docker-build-daemon-devnet-generic: start-local-debian-repo ## Build the daemon Docker image
	$(call build_docker_image,mina-daemon,devnet-generic)

.PHONY: docker-build-daemon-devnet
docker-build-daemon-devnet: SHELL := /bin/bash
docker-build-daemon-devnet: start-local-debian-repo ## Build the daemon Docker image for devnet
	$(call build_docker_image,mina-daemon,devnet,--deb-suffix generic)

.PHONY: docker-build-daemon-mainnet
docker-build-daemon-mainnet: SHELL := /bin/bash
docker-build-daemon-mainnet: start-local-debian-repo ## Build the daemon Docker image for mainnet
	$(call build_docker_image,mina-daemon,mainnet,--deb-suffix generic)


.PHONY: docker-build-daemon-devnet-automode-hardfork
docker-build-daemon-devnet-automode-hardfork: SHELL := /bin/bash
docker-build-daemon-devnet-automode-hardfork: start-local-debian-repo ## Build the daemon Docker image for automode devnet post hardfork
	$(call build_docker_image,mina-daemon-auto-hardfork,devnet)

.PHONY: docker-build-daemon-mainnet-automode-hardfork
docker-build-daemon-mainnet-automode-hardfork: SHELL := /bin/bash
docker-build-daemon-mainnet-automode-hardfork: start-local-debian-repo ## Build the daemon Docker image for automode mainnet post hardfork
	$(call build_docker_image,mina-daemon-auto-hardfork,mainnet)

.PHONY: docker-build-rosetta
docker-build-rosetta-devnet-generic: SHELL := /bin/bash
docker-build-rosetta-devnet-generic: start-local-debian-repo ## Build the Rosetta Docker image
	$(call build_docker_image,mina-rosetta,devnet-generic)

.PHONY: docker-build-rosetta-devnet
docker-build-rosetta-devnet: SHELL := /bin/bash
docker-build-rosetta-devnet: start-local-debian-repo ## Build the Rosetta Docker image for devnet
	$(call build_docker_image,mina-rosetta,devnet,--deb-suffix generic)

.PHONY: docker-build-rosetta-mainnet
docker-build-rosetta-mainnet: SHELL := /bin/bash
docker-build-rosetta-mainnet: start-local-debian-repo ## Build the Rosetta Docker image for mainnet
	$(call build_docker_image,mina-rosetta,mainnet,--deb-suffix generic)

.PHONY: docker-build-base
docker-build-base: SHELL := /bin/bash
docker-build-base: ## Build the shared mina-base image (no mina debs required)
	$(call build_docker_image,mina-base,$(NETWORK))

########################################
# Aggregate local build of all staged docker images

# Package the full debian closure the staged base/archive/daemon/rosetta images
# install from the local build context. This PACKAGES already-compiled binaries
# from _build/ (run the relevant make build* targets first) -- it does not
# compile. Select codename via CODENAME= and network via NETWORK=.
.PHONY: debian-build-all
debian-build-all: ## Package the deb closure for the staged images (CODENAME/NETWORK)
	$(info 📦 Packaging deb closure for network $(NETWORK) / codename $(CODENAME) from _build)
	BUILD_DIR="$(PWD)/_build" \
	DUNE_PROFILE=$(NETWORK) \
	MINA_DEB_CODENAME="$(CODENAME)" \
	BRANCH_NAME="$(BRANCH_NAME)" \
	./scripts/debian/build.sh \
		logproc \
		daemon_storage_toolbox \
		daemon_$(NETWORK)_generic \
		archive_generic \
		archive_$(NETWORK) \
		rosetta_generic \
		rosetta_$(NETWORK) \
		profile_$(NETWORK)

# Build every staged docker image (base, archive, daemon, rosetta) for one
# CODENAME/NETWORK, packaging the deb closure first. Set LOAD_ONLY=1 for a
# purely local build (load into local docker, no registry push).
# DOCKER_NO_CACHE is cleared for the whole run so the base-deps layer these
# images share is built once and reused, rather than three times; pass
# DOCKER_NO_CACHE=--no-cache to force the from-scratch behaviour back on.
.PHONY: docker-build-all
docker-build-all: SHELL := /bin/bash
docker-build-all: ## Build ALL staged docker images for CODENAME/NETWORK (packages debs first)
	$(MAKE) debian-build-all CODENAME=$(CODENAME) NETWORK=$(NETWORK)
	$(MAKE) docker-build-base CODENAME=$(CODENAME) NETWORK=$(NETWORK) LOAD_ONLY=$(LOAD_ONLY) DOCKER_NO_CACHE=
	$(MAKE) docker-build-archive-$(NETWORK) CODENAME=$(CODENAME) LOAD_ONLY=$(LOAD_ONLY) DOCKER_NO_CACHE=
	$(MAKE) docker-build-daemon-$(NETWORK) CODENAME=$(CODENAME) LOAD_ONLY=$(LOAD_ONLY) DOCKER_NO_CACHE=
	$(MAKE) docker-build-rosetta-$(NETWORK) CODENAME=$(CODENAME) LOAD_ONLY=$(LOAD_ONLY) DOCKER_NO_CACHE=

########################################
# Generate hardfork packages

.PHONY: debian-build-hardfork-config
debian-build-hardfork-config: SHELL := /bin/bash
debian-build-hardfork-config: #ocaml_checks ## Generate hardfork packages
	$(info 📦 Generating hardfork debian packages for network $(NETWORK_NAME))

	$(call check_env_var,NETWORK_NAME)
	$(call check_env_var,CODENAME)
	$(call check_env_var,BRANCH_NAME)

	@BUILD_DIR=./_build \
	MINA_DEB_CODENAME=$(CODENAME) \
	BRANCH_NAME=$(BRANCH_NAME) \
	KEEP_MY_TAGS_INTACT=true \
	./scripts/hardfork/release/build-packages.sh daemon_$(NETWORK_NAME)_hardfork_config



.PHONY: docker-build-daemon-hardfork-docker
docker-build-daemon-hardfork-docker: SHELL := /bin/bash
docker-build-daemon-hardfork-docker: ## Generate hardfork packages
	$(info 📦 Generating hardfork docker for network $(NETWORK_NAME))

	$(call check_env_var,NETWORK_NAME)
	$(call check_env_var,CODENAME)
	$(call check_env_var,BRANCH_NAME)

	$(MAKE) debian-build-config-$(NETWORK_NAME)
	$(MAKE) start-local-debian-repo

	@export BUILD_DIR=./_build && \
	export MINA_DEB_CODENAME=$(CODENAME) && \
	export KEEP_MY_TAGS_INTACT=true && \
	. ./scripts/export-git-env-vars.sh && \
	./scripts/docker/build.sh \
		--deb-codename $(CODENAME) \
		--service mina-daemon \
		--version "$$MINA_DOCKER_TAG" \
		--deb-version "$$MINA_DEB_VERSION" \
		--branch $(BRANCH_NAME) \
		--network $(NETWORK_NAME) \
		--deb-suffix generic \
		--custom-suffix generic \
		--load-only
		--no-cache

	cp _build/mina-devnet-config_*.deb .

	@export BUILD_DIR=./_build && \
	export MINA_DEB_CODENAME=$(CODENAME) && \
	export KEEP_MY_TAGS_INTACT=true && \
	. ./scripts/export-git-env-vars.sh && \
	./scripts/docker/build.sh \
		--deb-codename $(CODENAME) \
		--service mina-daemon-config \
		--version "$$MINA_DOCKER_TAG" \
		--deb-version "$$MINA_DEB_VERSION" \
		--branch $(BRANCH_NAME) \
		--network $(NETWORK_NAME) \
		--custom-suffix configured \
		--no-cache \
		--load-only

	$(info 📦 cleaning up staged local debians)
	@rm -f dockerfiles/*.deb

.PHONY: docker-build-hardfork-rosetta-docker
docker-build-hardfork-rosetta-docker: SHELL := /bin/bash
docker-build-hardfork-rosetta-docker: ## Generate hardfork packages
	$(info 📦 Generating hardfork docker for network $(NETWORK_NAME))
	$(call check_env_var,NETWORK_NAME)
	$(call check_env_var,CODENAME)
	$(call check_env_var,BRANCH_NAME)

	$(MAKE) debian-build-config-$(NETWORK_NAME)
	$(MAKE) start-local-debian-repo

	@export BUILD_DIR=./_build && \
	export MINA_DEB_CODENAME=$(CODENAME) && \
	export KEEP_MY_TAGS_INTACT=true && \
	. ./scripts/export-git-env-vars.sh && \
	./scripts/docker/build.sh \
		--deb-codename $(CODENAME) \
		--service mina-rosetta \
		--version "$$MINA_DOCKER_TAG" \
		--deb-version "$$MINA_DEB_VERSION" \
		--branch $(BRANCH_NAME) \
		--network $(NETWORK_NAME) \
		--deb-suffix generic \
		--custom-suffix generic \
		--load-only \
		--no-cache

	cp _build/mina-devnet-config_*.deb .

	@export BUILD_DIR=./_build && \
	export MINA_DEB_CODENAME=$(CODENAME) && \
	export KEEP_MY_TAGS_INTACT=true && \
	. ./scripts/export-git-env-vars.sh && \
	./scripts/docker/build.sh \
		--deb-codename $(CODENAME) \
		--service mina-rosetta-config \
		--version "$$MINA_DOCKER_TAG" \
		--deb-version "$$MINA_DEB_VERSION" \
		--branch $(BRANCH_NAME) \
		--network $(NETWORK_NAME) \
		--custom-suffix configured \
		--custom-arg "--build-arg image_name=mina-rosetta" \
		--no-cache \
		--load-only


	$(info 📦 cleaning up staged local debians)
	@rm -f dockerfiles/*.deb

########################################
# Generate odoc documentation

.PHONY: ml-docs
ml-docs: ocaml_checks ## Generate OCaml documentation
	dune build --profile=$(DUNE_PROFILE) @doc


########################################
# PostgreSQL, used for the archive node

.PHONY: postgres-setup
postgres-setup: ## Set up PostgreSQL database for archive node
	@echo "Setting up PostgreSQL database: ${PG_DB} with user: ${PG_USER}"
	@sudo -u postgres createuser -d -r -s $(PG_USER) 2>/dev/null || true
	@sudo -u postgres psql -c "ALTER USER $(PG_USER) PASSWORD '$(PG_PW)'" 2>/dev/null || true
	@sudo -u postgres createdb -O $(PG_USER) $(PG_DB) 2>/dev/null || true
	@sudo -u postgres createdb -O $(PG_USER) $(PG_USER) 2>/dev/null || true
	@echo "PostgreSQL setup complete"

.PHONY: postgres-login
postgres-login: ## Login to PostgreSQL database
	@echo "Connecting to PostgreSQL database: ${PG_DB} as user: ${PG_USER}"
	@PGPASSWORD=$(PG_PW) psql -h $(PG_HOST) -p $(PG_PORT) -U $(PG_USER) -d $(PG_DB)

.PHONY: postgres-clean
postgres-clean:
	@echo "Dropping DB: ${PG_DB} and user: ${PG_USER}"
	@sudo -u postgres psql -c "DROP DATABASE IF EXISTS ${PG_DB}"
	@sudo -u postgres psql -c "DROP DATABASE IF EXISTS ${PG_USER}"
	@sudo -u postgres psql -c "DROP ROLE IF EXISTS ${PG_USER}"
	@echo "Cleanup complete."

.PHONY: regenerate-archive
regenerate-archive: ## Regenerate archive database with test data
	@echo "Regenerating archive database using configured PG variables"
	@PG_USER=$(PG_USER) PG_PW=$(PG_PW) PG_DB=$(PG_DB) PG_HOST=$(PG_HOST) PG_PORT=$(PG_PORT) \
	./scripts/regenerate-archive.sh
