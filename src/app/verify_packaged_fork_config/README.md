# Mina Verify Packaged Fork Config

A comprehensive validation tool for verifying packaged Mina fork configurations against expected genesis ledgers and precomputed blocks.

## Overview

This application validates that an installed Mina package matches the expected configuration defined in a `fork_config.json` file. It performs extensive verification including:

- **Genesis ledger generation** in both legacy and new formats
- **Hash verification** between configs and precomputed blocks
- **Ledger export** from running daemon instances
- **RocksDB database comparison** for ledger integrity
- **Multi-source validation** (packaged, generated, and web-hosted ledgers)

## Architecture

The codebase is organized into modular components for maintainability:

### Core Modules

- **`types.ml`** - Domain types and type definitions
- **`constants.ml`** - Centralized constants, paths, and configuration defaults
- **`file_operations.ml`** - File system utilities with logging
- **`json_utils.ml`** - JSON parsing and hash extraction
- **`shell_operations.ml`** - Shell command execution with error handling
- **`rocksdb_utils.ml`** - RocksDB database scanning and comparison
- **`validation.ml`** - High-level validation orchestration
- **`verify_packaged_fork_config.ml`** - Main entry point and CLI

## Usage

### Basic Command

```bash
mina-verify-packaged-fork-config \
  --network-name mainnet \
  --fork-config /path/to/fork_config.json \
  --working-dir /tmp/verify-work \
  [--precomputed-block-prefix gs://custom-bucket/prefix]
```

### Required Arguments

- `--network-name` - Network identifier (e.g., `mainnet`, `devnet`)
- `--fork-config` - Path to the fork configuration JSON file
- `--working-dir` - Directory for temporary files and verification outputs

### Optional Arguments

- `--precomputed-block-prefix` - Custom GCS prefix for precomputed blocks
  - Default: `gs://mina_network_block_data/<network-name>`

## Environment Variables

The application supports extensive configuration via environment variables:

### Executable Paths

| Variable | Default | Description |
|----------|---------|-------------|
| `MINA_EXE` | `mina` (or `./_build/default/src/app/cli/src/mina.exe`) | Mina CLI executable |
| `MINA_GENESIS_EXE` | `mina-create-genesis` | Genesis ledger creation tool |
| `MINA_LEGACY_GENESIS_EXE` | `mina-create-legacy-genesis` | Legacy format genesis tool |
| `CREATE_RUNTIME_CONFIG` | `mina-hf-create-runtime-config` | Runtime config creation script |
| `GSUTIL` | `gsutil` (from PATH) | Google Cloud Storage utility |

### Configuration Paths

| Variable | Default | Description |
|----------|---------|-------------|
| `PACKAGED_DAEMON_CONFIG` | `/var/lib/coda/config_*.json` | Packaged daemon configuration file |
| `GENESIS_LEDGER_DIR` | `/var/lib/coda` | Genesis ledger directory |
| `FORKING_FROM_CONFIG_JSON` | `/var/lib/coda/mainnet.json` | Source network configuration |
| `PRECOMPUTED_FORK_BLOCK` | (fetched via gsutil) | Explicit precomputed block path |

### Network Parameters

| Variable | Default | Description |
|----------|---------|-------------|
| `SECONDS_PER_SLOT` | `180` | Network consensus parameter |
| `MINA_LOG_LEVEL` | `info` | Daemon log level during validation |
| `MINA_LEDGER_S3_BUCKET` | `https://s3-us-west-2.amazonaws.com/snark-keys-ro.o1test.net` | S3 bucket for ledger storage |

### Behavior Flags

| Variable | Effect |
|----------|--------|
| `NO_TEST_LEDGER_DOWNLOAD` | Skip ledger download testing if set (any value) |
| `MINA_LIBP2P_PASS` | Passphrase for libp2p key (empty by default) |

## Validation Process

The verification follows these steps:

### 1. Setup Phase
- Resolve all executable paths
- Validate packaged daemon config exists
- Create working directory structure
- Extract fork block metadata

### 2. Precomputed Block Acquisition
- Fetch or copy precomputed fork block
- Extract state hash and blockchain length
- Verify block availability

### 3. Keypair Generation
- Generate libp2p keypair if needed
- Set appropriate permissions on keys directory

### 4. Legacy Ledger Generation
- Create legacy format ledgers
- Generate hash file
- **Verify hashes match precomputed block**

### 5. New Ledger Generation
- Patch config to remove metadata fields
- Generate new format ledgers
- Create hash file

### 6. Runtime Config Creation
- Extract genesis timestamp from packaged config
- Create substituted config with updated values
- Generate override file for timestamp

### 7. Ledger Export (Multiple Sources)
- **Downloaded ledgers** - Export from packaged config with downloaded ledgers
- **Reference ledgers** - Export from substituted config with generated ledgers
- **Packaged ledgers** - Export from packaged config with installed ledgers
- Wait for daemon readiness (polls every 60 seconds)

### 8. Final Comparisons
- **Config hash comparison** - Verify substituted vs packaged config hashes
- **JSON ledger comparison** - Compare exported ledger JSON files
- **RocksDB comparison** - Compare database contents byte-by-byte

### 9. RocksDB Deep Verification
For each ledger tarball:
- Extract packaged, generated, and web-hosted versions
- Scan databases to hex representation
- Compare hex dumps for exact matches

## Exit Codes

- **0** - Validation successful, all checks passed
- **1** - Validation failed or error occurred

## Output

The tool provides:
- Detailed logging to stderr
- Progress indicators for long-running operations
- Comparison results for all validation steps
- Error messages with specific failure details

## Working Directory Structure

The working directory contains:

```
working-dir/
├── config.json                     # Patched config without metadata
├── config_orig.json                # Original fork config copy
├── config-substituted.json         # Runtime config with substitutions
├── precomputed_fork_block.json    # Fork block from GCS
├── legacy_hashes.json              # Hashes from legacy generation
├── hashes.json                     # Hashes from new generation
├── override-genesis-timestamp.json # Current timestamp override
├── downloaded-{staged,staking,next}.json  # Exported from downloaded
├── reference-{staged,staking,next}.json   # Exported from reference
├── packaged-{staged,staking,next}.json    # Exported from packaged
├── keys/
│   └── p2p                         # libp2p keypair
├── ledgers/                        # Generated ledger tarballs
├── ledgers-backup/                 # Temporary backup during export
├── ledgers-downloaded/             # Downloaded ledger tarballs
└── legacy_ledgers/                 # Legacy format ledgers
```

## Performance Notes

- **Execution time**: Typically >20 minutes due to:
  - Ledger generation and rehashing
  - Multiple daemon starts and exports
  - RocksDB database comparisons
- **Disk space**: Requires several GB for ledgers and databases
- **Network**: Downloads precomputed block and ledgers from GCS/S3

## Error Handling

The tool fails fast on critical errors:
- Missing executables or configuration files
- JSON parsing errors
- Hash mismatches during verification
- Daemon failures during export
- File comparison mismatches

All errors are logged with context and details for debugging.

## Development

### Building

```bash
dune build src/app/verify_packaged_fork_config
```

### Testing

```bash
# Run with test mode to skip ledger download validation
NO_TEST_LEDGER_DOWNLOAD=1 mina-verify-packaged-fork-config \
  --network-name devnet \
  --fork-config test_fork_config.json \
  --working-dir /tmp/verify-test
```

### Module Structure

The codebase uses a library + executable pattern:
- **Library** (`verify_packaged_fork_config_lib`) - Core logic and utilities
- **Executable** (`verify_packaged_fork_config`) - CLI interface and main loop

This separation enables:
- Unit testing of individual modules
- Reusability of validation logic
- Clear separation of concerns

## Logging

Structured logging throughout:
- **Info level** - Major steps and progress
- **Debug level** - Detailed operations and values
- **Error level** - Failures and validation errors

Set `MINA_LOG_LEVEL` to control daemon logging during export.

## Common Issues

### "gsutil not found"
Ensure `gsutil` is installed and in PATH, or set `GSUTIL` environment variable.

### "daemon died before exporting ledgers"
- Check daemon logs for startup errors
- Verify network configuration is valid
- Ensure sufficient disk space and memory

### "Hash mismatch"
- Verify fork config matches the actual network state
- Check precomputed block is correct for the fork
- Ensure all executables are from the same build

## Contributing

When modifying this codebase:
1. Add comprehensive documentation to new functions
2. Use the existing module structure
3. Centralize constants in `constants.ml`
4. Include logging at appropriate levels
5. Handle errors explicitly with Result types
6. Update this README for new features

## License

See the main Mina repository license.
