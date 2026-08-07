##@ Debian packages

########################################
# Debian packages

# Helper function for building Debian packages
define build_debian_package
	$(info 🏗️  Building Debian package $(1) with profile $(DUNE_PROFILE) and commit $(GITLONGHASH) and codename $(CODENAME))
	BUILD_DIR="${PWD}/_build" \
	DUNE_PROFILE=$(DUNE_PROFILE) \
	MINA_DEB_CODENAME="$(CODENAME)" \
	BRANCH_NAME="$(BRANCH_NAME)" \
	./scripts/debian/build.sh $(1)  \
		&& echo "✅ Build complete"
endef

.PHONY: debian-build-archive-devnet
debian-build-archive-devnet: ## Build the Debian archive package for devnet
	$(call build_debian_package,archive_devnet)

.PHONY: debian-build-archive
debian-build-archive: ## Build the Debian archive package for mainnet
	$(call build_debian_package,archive_mainnet)

.PHONY: debian-build-daemon-devnet-generic
debian-build-daemon-devnet-generic: ## Build the Debian daemon package for devnet-generic
	$(call build_debian_package,daemon_devnet_generic)

.PHONY: debian-build-daemon-devnet
debian-build-daemon-devnet: ## Build the Debian daemon package for devnet
	$(call build_debian_package,daemon_devnet)

.PHONY: debian-build-daemon-mainnet
debian-build-daemon-mainnet: ## Build the Debian daemon package for mainnet
	$(call build_debian_package,daemon_mainnet)

.PHONY: debian-build-daemon-mainnet-generic
debian-build-daemon-mainnet-generic: ## Build the Debian daemon package for mainnet-generic
	$(call build_debian_package,daemon_mainnet_generic)

.PHONY: debian-build-daemon-devnet-prefork
debian-build-daemon-devnet-prefork: ## Build the Debian daemon package for automote devnet pre hardfork
	$(call build_debian_package,daemon_devnet_prefork)

.PHONY: debian-build-daemon-mainnet-prefork
debian-build-daemon-mainnet-prefork: ## Build the Debian daemon package for automote mainnet pre hardfork
	$(call build_debian_package,daemon_mainnet_prefork)

.PHONY: debian-build-config-mainnet
debian-build-config-mainnet: ## Build the Debian config package for mainnet
	$(call build_debian_package,daemon_mainnet_config)

.PHONY: debian-build-logproc
debian-build-logproc: ## Build the Debian logproc package
	$(call build_debian_package,logproc)

.PHONY: debian-build-functional-tests
debian-build-functional-tests: ## Build the Debian Functional tests package
	$(call build_debian_package,functional_test_suite)

.PHONY: debian-build-prefork-genesis-ledger
debian-build-prefork-genesis-ledger: ## Build the Debian Create Legacy Genesis package
	$(call check_env_var,NETWORK_NAME)
	$(call build_debian_package,prefork_$(NETWORK_NAME)_genesis_ledger)

.PHONY: debian-build-rosetta-generic
debian-build-rosetta-generic: ## Build the Debian Rosetta generic package
	$(call build_debian_package,rosetta_generic)

.PHONY: debian-build-tx-tools
debian-build-tx-tools: ## Build the Debian tx-tools package (batch_txn + zkapp_test_transaction)
	$(call build_debian_package,tx_tools)

.PHONY: debian-build-rosetta-devnet
debian-build-rosetta-devnet: ## Build the Debian Rosetta package for devnet
	$(call build_debian_package,rosetta_devnet)

.PHONY: debian-build-rosetta-mainnet
debian-build-rosetta-mainnet: ## Build the Debian Rosetta package for mainnet
	$(call build_debian_package,rosetta_mainnet)

.PHONY: debian-build-daemon-devnet-postfork
debian-build-daemon-devnet-postfork: ## Build the Debian daemon package for automote devnet post hardfork
	$(call build_debian_package,daemon_devnet_postfork)

.PHONY: debian-build-daemon-mainnet-postfork
debian-build-daemon-mainnet-postfork: ## Build the Debian daemon package for automote mainnet post hardfork
	$(call build_debian_package,daemon_mainnet_postfork)

.PHONY: debian-daemon-storage-toolbox
debian-daemon-storage-toolbox: ## Build the Debian daemon storage toolbox package
	$(call build_debian_package,daemon_storage_toolbox)

.PHONY: debian-download-create-legacy-hardfork
debian-download-create-legacy-hardfork: ## Download and create legacy hardfork Debian packages
	$(info 📦 Downloading legacy hardfork Debian packages for debian $(CODENAME))
	$(call check_env_var,NETWORK_NAME)

	@./buildkite/scripts/release/manager.sh pull --artifacts mina-create-$(NETWORK_NAME)-prefork-genesis  --from-special-folder legacy/debians/$(CODENAME)  --backend hetzner --target _build

.PHONY: debian-reversion
debian-reversion: ## Reversion a .deb package (DEB, NEW_VERSION required; NEW_SUITE, NEW_NAME, OUTPUT optional)
	$(call check_env_var,DEB)
	$(call check_env_var,NEW_VERSION)
	@./scripts/debian/reversion.sh "$(DEB)" "$(NEW_VERSION)" \
		$(if $(NEW_SUITE),--suite "$(NEW_SUITE)") \
		$(if $(NEW_NAME),--name "$(NEW_NAME)") \
		$(if $(OUTPUT),--output "$(OUTPUT)")

########################################
# Release management

.PHONY: cache-get-prefork-debians
cache-get-prefork-debians: ## Download debian packages for prefork genesis creation
	$(info 📦 Downloading prefork Debian packages for debian $(CODENAME))

	$(call check_env_var,NETWORK_NAME)

	@./buildkite/scripts/release/manager.sh pull --artifacts mina-$(NETWORK_NAME)-prefork  --from-special-folder berkeley/debians/$(CODENAME)  --backend hetzner --target _build

.PHONY: cache-get-create-prefork-genesis-debians
cache-get-create-prefork-genesis-debians: ## Download debian packages for prefork genesis creation
	$(info 📦 Downloading prefork genesis creation Debian packages for debian $(CODENAME))
	$(call check_env_var,NETWORK_NAME)
	@./buildkite/scripts/release/manager.sh pull --artifacts mina-$(NETWORK_NAME)-create-genesis-ledger  --from-special-folder berkeley/debians/$(CODENAME)  --backend hetzner --target _build

.PHONY: cache-put-debian
cache-put-debian: ## Upload debian packages for prefork genesis creation
	$(info 📦 Uploading Debian packages for debian $(CODENAME) to CI cache)
	$(call check_env_var,TARGET)
	$(call check_env_var,DEB_PATH)
	@./buildkite/scripts/release/manager.sh persist --codename $(CODENAME)  --target $(TARGET)  --backend hetzner --local-debian-path $(DEB_PATH)

