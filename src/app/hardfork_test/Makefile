.PHONY: build clean test nix-build

APP_NAME := hardfork_test
BUILD_DIR := bin
GO ?= go

# -buildvcs=false: the CI toolchain checks out the repo under a different owner,
# so Go's VCS stamping fails ("error obtaining VCS status: exit status 128");
# these builds don't need the stamp.
build:
	@echo "Building $(APP_NAME)..."
	@mkdir -p $(BUILD_DIR)
	@( cd src && $(GO) build -buildvcs=false -o ../$(BUILD_DIR)/$(APP_NAME) ./cmd )

# Build every package first so a compile break is a distinct, fast failure,
# then run the Go unit tests. Run from the module root (src/, where go.mod is).
test:
	@echo "Testing $(APP_NAME)..."
	@( cd src && $(GO) build -buildvcs=false ./... && $(GO) test -buildvcs=false ./... )

clean:
	@echo "Cleaning..."
	@rm -rf $(BUILD_DIR)

.DEFAULT_GOAL := build
