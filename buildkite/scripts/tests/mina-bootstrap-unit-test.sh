#!/bin/bash

# Fast unit tests for the mina-bootstrap Go CLI (src/app/bootstrap).
#
# Runs `go vet` + `go test ./...` with a Go >= 1.21 toolchain. The CI build
# images ship Go 1.19, so we reuse scripts/ensure-go.sh (the same provisioning
# the `make build-mina-bootstrap` artifact step uses) to obtain a new-enough
# toolchain. Only the default (untagged) tests run here; the `integration`
# build-tag tests need Postgres + mina-archive-blocks and live in the dedicated
# MinaBootstrapCatchupIntegrationTest job.

set -euo pipefail

GO_BIN="$(scripts/ensure-go.sh)"
echo "Using Go: $("$GO_BIN" version) ($GO_BIN)"

cd src/app/bootstrap

echo "--- go vet"
"$GO_BIN" vet ./...

echo "--- go test"
"$GO_BIN" test ./... -v
