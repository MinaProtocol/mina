# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
Mina Protocol is a lightweight blockchain that maintains constant size by using recursive zk-SNARKs. The codebase is primarily written in OCaml (4.14.2) with additional components in Go (libp2p helper) and Rust (cryptographic implementations via proof-systems submodule).

## Build Commands

### Core Build Commands
- `make build` - Build the Mina daemon and core executables (requires 10GB+ RAM)
- `make build-archive` - Build the archive node
- `make build-rosetta` - Build Rosetta API components
- `make libp2p_helper` - Build the Go libp2p helper (required for networking)
- `make build-intgtest` - Build integration test tools
- `make build-mainnet-sigs` - Build mainnet signature variants
- `make build-devnet-sigs` - Build devnet signature variants
- `make build-daemon-utils` - Build daemon utilities
- `make build-archive-utils` - Build archive node and related utilities
- `make build-test-utils` - Build test utilities
- `make build-replayer` - Build the replayer tool
- `make build-logproc` - Build log processor

### Quick Development Commands
- `dune build @check` - Quick type-check without full build
- `make check` - Check that all OCaml packages build

### Installation Commands
- `make install` - Install binaries to OPAM switch
- `make uninstall` - Uninstall binaries

## Testing Commands

### Unit Tests
- `dune runtest src/lib/<library>` - Run tests for a specific library
- `dune runtest src/lib --profile=dev` - Run all tests under src/lib
- `dune exec src/lib/<library>/test/main.exe` - Run tests using explicit executable
- `./scripts/testone.sh <test-file> [test-name]` - Run a single test file

### CI Test Execution
- `./buildkite/scripts/unit-test.sh <profile> <path>` - Run tests as done in CI (builds first, retries failures once)

### Coverage Testing
- `make test-coverage` - Run tests with coverage instrumentation
- `make coverage-html` - Generate HTML coverage reports
- `make coverage-summary` - Generate coverage summary

### Other Test Commands
- `make test-ppx` - Test PPX extensions

Note: There is no `make test` target. Use `dune runtest` directly.

## Development Commands

### Code Formatting
- `make reformat` - Auto-format all OCaml code
- `make reformat-diff` - Format only modified files (runs automatically during `make build`)
- `make check-format` - Check formatting without changing files

### Code Quality
- `make check-bash` - Run shellcheck on bash scripts
- `make check-docker` - Run hadolint on Docker files

### Documentation
- `make ml-docs` - Generate OCaml documentation with odoc
- `make update-graphql` - Update GraphQL schema

### Dependency Management
- `./scripts/update-opam-switch.sh` - Update/create the opam switch

## Project Structure

### Core Applications (`src/app/`)
- `cli/` - Mina daemon and client CLI (main entry point)
- `archive/` - Archive node for storing historical blockchain data
- `rosetta/` - Rosetta API implementation
- `libp2p_helper/` - Go-based libp2p networking helper
- `test_executive/` - Integration test framework
- `generate_keypair/` / `validate_keypair/` - Keypair utilities
- `batch_txn_tool/` - Transaction load testing
- `zkapp_test_transaction/` - zkApp test transaction utility
- `zkapps_examples/` - zkApp example programs
- `replayer/` - Blockchain replay utility
- `missing_blocks_auditor/` - Audit for missing blocks
- `extract_blocks/` / `archive_blocks/` - Block extraction and archival
- `hardfork_test/` - Hard fork testing utilities
- `runtime_genesis_ledger/` - Runtime genesis ledger generator
- `logproc/` - Log processing utility
- `delegation_verify/` - Delegation verification

### Core Libraries (`src/lib/`)
- `mina_lib/` - Main daemon coordinator library
- `consensus/` - Proof-of-stake consensus implementation
- `transaction_snark/` - Transaction SNARK creation and verification
- `pickles/` - Recursive SNARK composition library (used for blockchain proofs)
- `crypto/` - Cryptographic primitives (fields, curves, hashing)
- `network_pool/` - P2P networking and gossip
- `ledger/` - Merkle tree ledger implementation
- `staged_ledger/` - Transaction processing pipeline

### Build Profiles (`src/config/`)
Profiles are defined as `.mlh` files in `src/config/` and selected via `--profile` in dune:
- `dev` - Development (default). Small ledger depth (10), proof_level=check, fast 2s blocks
- `devnet` - Devnet. Full ledger depth (35), proof_level=full, 3min blocks, testnet signatures
- `mainnet` - Production. Full ledger depth (35), proof_level=full, 3min blocks, mainnet signatures
- `lightnet` - Lightweight test network. Full ledger depth (35), proof_level=none, 20s blocks

### CI/CD (`buildkite/`)
- Pipeline defined in **Dhall** (typed configuration language) in `buildkite/src/`
- Jobs organized under `buildkite/src/Jobs/{Test,Release,Lint,Bench}/`
- Constants (artifacts, networks, profiles, codenames) in `buildkite/src/Constants/`
- Monorepo triage system: `buildkite/scripts/monorepo.sh` determines which jobs to run based on changed files
- Monorepo tests: `cd buildkite && make test_monorepo`

### Debian Packaging (`scripts/debian/`)
- `build.sh` - Main build orchestrator, builds all or specific packages
- `builder-helpers.sh` - Core library with package building functions
- `tests/test_builder_helpers.sh` - Unit tests for the builder helpers
- Key env vars: `MINA_DEB_CODENAME`, `MINA_DEB_VERSION`, `DUNE_PROFILE`, `MINA_DEB_RELEASE`
- Supported codenames: bullseye, focal, noble, jammy, bookworm
- Package naming is profile-aware (lightnet suffix) and instrumentation-aware

### Docker (`scripts/docker/`)
- `build.sh` - Docker image builder with service/network/platform options
- `helper.sh` - Tag generation and base image selection helpers
- Dockerfiles in `dockerfiles/` directory
- Supports multiarch builds (amd64, arm64) via `docker buildx`

### Release Management
- `buildkite/scripts/release/manager.sh` - Main tool for publishing, promoting, and verifying releases
- Workflow: Build -> Unstable -> Alpha -> Beta -> Stable
- Supports Debian repos, GCR, and docker.io
- Uses `deb-s3` for Debian repository operations

## Architecture Notes

### Layered Architecture
1. **Daemon Layer** (`mina_lib/`) - Coordinates all subsystems
2. **Consensus Layer** - Handles proof-of-stake consensus and chain selection
3. **SNARK Layer** - Creates and verifies recursive proofs
4. **Network Layer** - P2P communication via libp2p
5. **Ledger Layer** - Maintains account balances and state

### Key Concepts
- **Staged Ledger**: Pipeline for processing transactions in parallel
- **Scan State**: Tree structure tracking pending SNARK work
- **Transition Frontier**: Recent blocks kept in memory
- **Protocol State**: Consensus-critical blockchain state
- **Transaction Pool**: Mempool for pending transactions

### Important Constraints
- OCaml 4.14.2 is required (not compatible with OCaml 5)
- Dune 3.1+ required
- System ulimits need adjustment for builds: `ulimit -s 65532; ulimit -n 10240`
- Builds require significant RAM (10GB+)
- Git submodules must be initialized: `git submodule update --init --recursive`

## Development Workflow

### Before Building
1. Set up the opam switch: `make switch`
2. Initialize git submodules: `git submodule update --init --recursive`
3. Build libp2p helper: `make libp2p_helper`

### Running Tests
```bash
# Run tests for a specific library
dune runtest src/lib/mina_lib

# Run tests with proper limits
(ulimit -s 65532 || true) && (ulimit -n 10240 || true) && dune runtest src/lib

# Run a single test
./scripts/testone.sh src/lib/mina_lib/test.ml
```

### Adding Dependencies
1. Add to relevant `.opam` file in `src/`
2. Run `make switch` to update the opam switch
3. Commit both changes together

### Code Formatting
Always format code before committing:
```bash
make reformat-diff  # Format only changed files
# or
make reformat      # Format all files
```

### Using Dune for Development
```bash
# Build specific target
dune build src/app/cli/src/mina.exe

# Watch mode for development
dune build -w @check

# Build and run inline tests
dune runtest src/lib/mina_lib
```

## Debian Repositories
- `nightly.apt.packages.minaprotocol.com` - Signed, for nightly packages
- `unstable.apt.packages.minaprotocol.com` - Signed, for alpha/beta packages
- `stable.apt.packages.minaprotocol.com` - Signed, for releases
- `packages.o1test.net` - Unsigned, legacy multichannel repo

## CI/PR Process
- Full CI run need `!ci-nightly-me` comment for CI to run
- PRs from main repo need `!ci-build-me` label
- Code must be formatted with `make reformat` before commits
- CI uses Docker images from `europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/`
