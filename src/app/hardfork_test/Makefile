.PHONY: build clean test nix-build

APP_NAME := hardfork_test
BUILD_DIR := bin

build:
	@echo "Building $(APP_NAME)..."
	@mkdir -p $(BUILD_DIR)
	@( cd src && go build -o ../$(BUILD_DIR)/$(APP_NAME) ./cmd )

test:
	@( cd src && go test ./... )

clean:
	@echo "Cleaning..."
	@rm -rf $(BUILD_DIR)

.DEFAULT_GOAL := build
