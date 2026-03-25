# Hardfork Pipeline Runner

A robust Go-based tool for running and monitoring the hardfork package generation pipeline on Buildkite with custom environment variables.

## Features

- ✅ **Single binary** - No dependencies, just compile and run
- ✅ **Real-time monitoring** - Watch build progress with live updates
- ✅ **Color-coded output** - Easy to see job states at a glance
- ✅ **Duration tracking** - See how long each job runs
- ✅ **Signal handling** - Graceful shutdown with Ctrl+C
- ✅ **Exit codes** - Proper exit codes for CI/CD integration
- ✅ **Hardfork-specific** - Tailored for hardfork package generation with all required parameters

## Building

### Quick build:
```bash
cd buildkite/scripts/pipeline
make build
```

The binary will be created at `./bin/hardfork-runner`

### Install system-wide:
```bash
make install
```

### Build for all platforms:
```bash
make build-all
```

## Usage

### Set up API token:
```bash
export BUILDKITE_API_TOKEN="your_token_here"
```

### Basic usage (create build without monitoring):
```bash
./bin/hardfork-runner \
    --version "3.3.0-beta1-dkijania-do-not-rebuild-on-hf-pipeline-d62d701" \
    --codename "Noble" \
    --branch develop
```

### Create and monitor build:
```bash
./bin/hardfork-runner \
    --version "3.3.0-beta1-dkijania-do-not-rebuild-on-hf-pipeline-d62d701" \
    --codename "Noble" \
    --config-url "https://storage.googleapis.com/o1labs-gitops-infrastructure/pre-mesa/pre-mesa-1-hardfork-3NLwn2BxDnq6QZsj2XDaQ5joofJhvvCijk6brHYpuJfnh4yszsNz.gz" \
    --genesis-timestamp "2025-12-02T16:00:00Z" \
    --precomputed-prefix "gs://mesa-hf-precomputed-blocks/hetzner-pre-mesa-1" \
    --use-artifacts-from "019b038f-b7c9-4669-ae8e-97a120b23126" \
    --branch develop \
    --monitor \
    --poll-interval 10
```

## Command-line Options

| Flag | Description | Default |
|------|-------------|---------|
| `--version` | VERSION environment variable (required) | - |
| `--codename` | CODENAMES environment variable | Noble |
| `--config-url` | CONFIG_JSON_GZ_URL environment variable | - |
| `--genesis-timestamp` | GENESIS_TIMESTAMP environment variable | - |
| `--network` | NETWORK environment variable | Devnet |
| `--repo` | REPO environment variable | Nightly |
| `--precomputed-prefix` | PRECOMPUTED_FORK_BLOCK_PREFIX environment variable | - |
| `--use-artifacts-from` | USE_ARTIFACTS_FROM_BUILDKITE_BUILD environment variable | - |
| `--ledger-bucket` | MINA_LEDGER_S3_BUCKET environment variable | https://s3-us-west-2.amazonaws.com/snark-keys.o1test.net |
| `--branch` | Git branch to build | develop |
| `--pipeline` | Pipeline in format org/pipeline | minaprotocol/mina |
| `--message` | Build message | Custom pipeline run |
| `--monitor` | Monitor build progress in real-time | false |
| `--poll-interval` | Polling interval in seconds | 10 |
| `--show-all-updates` | Show all job states, not just changes | false |
| `--api-token` | Buildkite API token | $BUILDKITE_API_TOKEN |

## Exit Codes

- `0` - Build passed
- `1` - Build failed
- `2` - Build was canceled
- `3` - Build in unknown state
- `130` - Interrupted by user (Ctrl+C)

## Sample Output

```
Creating build on branch 'develop'...
Environment variables:
  CODENAMES: Noble
  VERSION: 3.3.0-beta1-dkijania-do-not-rebuild-on-hf-pipeline-d62d701
  NETWORK: Devnet
  REPO: Nightly
  ...

Build created successfully!
Build ID: abc-123-def-456
Build Number: 12345
URL: https://buildkite.com/minaprotocol/mina/builds/12345

================================================================================
Monitoring build #12345
================================================================================

14:23:45 [SCHEDULED] promote packages (not started)
14:23:50 [RUNNING] promote packages (5s)
14:25:30 [RUNNING] promote packages (1m 45s)
14:28:15 [PASSED] promote packages (4m 30s)

================================================================================
Build #12345 finished
================================================================================
State: PASSED
Duration: 4m 30s
URL: https://buildkite.com/minaprotocol/mina/builds/12345

Job Summary:
  [PASSED] promote packages (4m 30s)
================================================================================
```

## Integration Examples

### Use in CI/CD:
```bash
#!/bin/bash
set -e

# Trigger build and monitor
./bin/hardfork-runner \
    --version "$VERSION" \
    --codename "Noble" \
    --monitor

# Exit code will indicate success/failure
if [ $? -eq 0 ]; then
    echo "Pipeline passed!"
else
    echo "Pipeline failed!"
    exit 1
fi
```

### Use in scripts:
```bash
#!/bin/bash

# Trigger without monitoring to get build number
BUILD_OUTPUT=$(./bin/hardfork-runner --version "1.0.0")
BUILD_NUMBER=$(echo "$BUILD_OUTPUT" | grep "Build Number:" | cut -d: -f2 | tr -d ' ')

echo "Build #$BUILD_NUMBER started"

# Do other work...

# Monitor later
./bin/hardfork-runner --monitor --build-number $BUILD_NUMBER
```

## Advantages over Bash/Python

1. **Single binary** - No Python/pip/venv needed, no bash version issues
2. **Fast** - Compiled Go is much faster than interpreted languages
3. **Type-safe** - Catch errors at compile time
4. **Concurrent** - Better concurrency support for future enhancements
5. **Cross-platform** - Easy to build for Linux, macOS, Windows
6. **No dependencies** - Only uses Go standard library

## Development

### Run without building:
```bash
go run run-hardfork-pipeline.go --version "1.0.0" --monitor
```

### Format code:
```bash
go fmt run-hardfork-pipeline.go
```

### Run tests:
```bash
make test
```
