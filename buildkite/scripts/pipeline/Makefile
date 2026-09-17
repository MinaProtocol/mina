.PHONY: build install clean test fmt lint vet check

BUILD_DIR=./bin

BINARIES=hardfork-runner nightly-promoter

build:
	@echo "Building all binaries..."
	@mkdir -p $(BUILD_DIR)
	@go build -o $(BUILD_DIR)/hardfork-runner ./cmd/hardfork-runner
	@go build -o $(BUILD_DIR)/nightly-promoter ./cmd/nightly-promoter
	@echo "Build complete: $(BUILD_DIR)/"

build-hardfork-runner:
	@mkdir -p $(BUILD_DIR)
	@go build -o $(BUILD_DIR)/hardfork-runner ./cmd/hardfork-runner

build-nightly-promoter:
	@mkdir -p $(BUILD_DIR)
	@go build -buildvcs=false -o $(BUILD_DIR)/nightly-promoter ./cmd/nightly-promoter

install: build
	@echo "Installing binaries to /usr/local/bin..."
	@sudo cp $(BUILD_DIR)/hardfork-runner /usr/local/bin/
	@sudo cp $(BUILD_DIR)/nightly-promoter /usr/local/bin/
	@echo "Installed successfully"

clean:
	@echo "Cleaning..."
	@rm -rf $(BUILD_DIR)
	@echo "Clean complete"

test:
	@go test -v ./...

fmt:
	@echo "Formatting Go code..."
	@go fmt ./...
	@echo "Format complete"

vet:
	@echo "Running go vet..."
	@go vet ./...
	@echo "Vet complete"

lint:
	@echo "Running linter..."
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run; \
	else \
		echo "golangci-lint not found, skipping. Install with: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"; \
	fi

check: fmt vet lint
	@echo "All checks complete"

build-all:
	@echo "Building for multiple platforms..."
	@mkdir -p $(BUILD_DIR)
	@for bin in $(BINARIES); do \
		GOOS=linux GOARCH=amd64 go build -o $(BUILD_DIR)/$$bin-linux-amd64 ./cmd/$$bin; \
		GOOS=linux GOARCH=arm64 go build -o $(BUILD_DIR)/$$bin-linux-arm64 ./cmd/$$bin; \
		GOOS=darwin GOARCH=amd64 go build -o $(BUILD_DIR)/$$bin-darwin-amd64 ./cmd/$$bin; \
		GOOS=darwin GOARCH=arm64 go build -o $(BUILD_DIR)/$$bin-darwin-arm64 ./cmd/$$bin; \
	done
	@echo "Build complete for all platforms"
