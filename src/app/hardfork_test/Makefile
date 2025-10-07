.PHONY: build clean test

APP_NAME := hardfork_test
BUILD_DIR := ./bin

build:
	@echo "Building $(APP_NAME)..."
	@mkdir -p $(BUILD_DIR)
	@go build -o $(BUILD_DIR)/$(APP_NAME) ./cmd

test:
	@go test ./...

clean:
	@echo "Cleaning..."
	@rm -rf $(BUILD_DIR)

install: build
	@echo "Installing $(APP_NAME)..."
	@install -m 755 $(BUILD_DIR)/$(APP_NAME) /usr/local/bin/

.DEFAULT_GOAL := build
