#!/usr/bin/env bash

# Mina Hard Fork Dry Run Ledger Generator
# Generates test ledgers for hard fork testing with configurable parameters.
# Use --help or -h for detailed usage information and examples.

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Check required dependencies
check_basic_dependencies() {
    local missing_deps=()
    
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    if ! command -v date >/dev/null 2>&1; then
        missing_deps+=("date")
    fi
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}" >&2
        echo "Please install the missing dependencies and try again." >&2
        echo "  - jq: JSON processor (required for configuration generation)" >&2
        exit 1
    fi
}

check_nix_if_needed() {
    local need_nix=false
    
    # Check if we need to build mina binary
    if [[ -z "$MINA_BINARY" ]] || [[ ! -x "$MINA_BINARY" ]]; then
        need_nix=true
    fi
    
    # Check if we need to build runtime_genesis_ledger binary
    if [[ -z "$RUNTIME_GENESIS_LEDGER_BINARY" ]] || [[ ! -x "$RUNTIME_GENESIS_LEDGER_BINARY" ]]; then
        need_nix=true
    fi
    
    if [[ "$need_nix" == "true" ]] && ! command -v nix >/dev/null 2>&1; then
        echo "Error: nix is required to build missing binaries but is not installed" >&2
        echo "Either install nix or provide paths to existing binaries using:" >&2
        echo "  --mina-binary PATH" >&2
        echo "  --runtime-genesis-ledger-binary PATH" >&2
        exit 1
    fi
}

check_basic_dependencies

STAKING_SEED="${STAKING_SEED:-2vahsgRV5nDPmtgr2Xo2Uq2dkngfSgvg7d1TKqQbY3wUS2ZDxCC3}"
NEXT_SEED="${NEXT_SEED:-2vbH4D8B76WMYPRFgeuVvdWVhv6tAFoCJtg83yuJT1dud3QVSiZn}"

# Default configuration
DEFAULT_GENESIS_TIMESTAMP="$(date -u -d "$(date -u +%Y-%m-%d) $(( $(date -u +%H) + 1 )):00:00" +%Y-%m-%dT%H:%M:%SZ)"
DEFAULT_BP_KEYS=2
DEFAULT_PLAIN_KEYS=4
DEFAULT_EXTRA_BALANCE=100000000
DEFAULT_EXTRA_KEYS=1
DEFAULT_PREFIX="itn-testbed"
DEFAULT_OUTPUT_DIR="$PWD"

# Initialize variables with defaults
GENESIS_TIMESTAMP="$DEFAULT_GENESIS_TIMESTAMP"
BP_KEYS="$DEFAULT_BP_KEYS"
PLAIN_KEYS="$DEFAULT_PLAIN_KEYS"
EXTRA_BALANCE="$DEFAULT_EXTRA_BALANCE"
EXTRA_KEYS="$DEFAULT_EXTRA_KEYS"
PREFIX="$DEFAULT_PREFIX"
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
MINA_BINARY=""
RUNTIME_GENESIS_LEDGER_BINARY=""
PAD_APP_STATE=""

export MINA_PRIVKEY_PASS="${MINA_PRIVKEY_PASS:-}"

# Help function
show_help() {
    cat << EOF
=============================================================================
Mina Hard Fork Dry Run Ledger Generator
=============================================================================

This script generates test ledgers for Mina hard fork testing. It creates
a series of three consecutive ledgers (epoch ledger, next epoch ledger, and
genesis ledger) with configurable parameters to simulate mainnet conditions
for hard fork procedure testing.

The script uses mainnet ledger distribution as a base to keep testing as
close as possible to real mainnet conditions, which is crucial for validating
that hard fork procedures will work correctly on mainnet.

USAGE:
  ./generate-ledger-hf-dryrun.sh [OPTIONS]

OPTIONS:
  -t, --timestamp TIMESTAMP    Genesis timestamp (ISO 8601 format)
                               Default: $DEFAULT_GENESIS_TIMESTAMP

  -p, --bp-keys NUM           Number of block producer keys to generate
                               Default: $DEFAULT_BP_KEYS
                               Range: 1-50 (recommended: 2-10)

  -k, --plain-keys NUM        Number of plain keys to generate
                               Default: $DEFAULT_PLAIN_KEYS
                               Range: 1-100 (recommended: 4-20)

  -b, --balance AMOUNT        Balance in MINA for each of extra keys
                               Default: $DEFAULT_EXTRA_BALANCE ($((DEFAULT_EXTRA_BALANCE / 1000000)) million MINA)
                               Note: Large balances can distort mainnet-like
                               distribution and may exceed system limits

  -e, --extra-keys NUM        Number of extra keys (affects prepare-test-ledger)
                               Default: $DEFAULT_EXTRA_KEYS
                               This determines how many of the generated keys
                               are treated as plain keys vs block producer keys

  --prefix PREFIX             Key file prefix
                               Default: $DEFAULT_PREFIX
                               Generated files: PREFIX-bp1, PREFIX-bp2, etc.


  --output-dir DIR            Output directory for generated files
                               Default: $DEFAULT_OUTPUT_DIR

  --mina-binary PATH          Path to mina binary (builds if not specified or missing)

  --runtime-genesis-ledger-binary PATH
                               Path to runtime_genesis_ledger binary (builds if not specified or missing)

  --pad-app-state             Pad app state when generating ledger hashes
                               (passed to runtime_genesis_ledger)

  -h, --help                  Show this help message

EXAMPLES:
  # Basic usage with defaults ($DEFAULT_BP_KEYS BP keys, $DEFAULT_PLAIN_KEYS plain keys)
  ./generate-ledger-hf-dryrun.sh

  # Generate more keys for larger test network
  ./generate-ledger-hf-dryrun.sh --bp-keys 5 --plain-keys 10

  # Custom timestamp and smaller balance
  ./generate-ledger-hf-dryrun.sh -t "2024-12-01T10:00:00Z" -b 50000000

  # Full customization
  ./generate-ledger-hf-dryrun.sh \\
    --timestamp "2024-11-15T14:30:00Z" \\
    --bp-keys 3 \\
    --plain-keys 6 \\
    --balance 75000000 \\
    --prefix "my-test" \\
    --output-dir "./test-output"

IMPORTANT CONSIDERATIONS:
  - Balance Distribution: Large balances (>100M MINA) can distort the
    mainnet-like stake distribution. Use with care to maintain realistic
    testing conditions.

  - System Limits: Too many keys with large balances may exceed the maximum
    total stake limit, making the runtime config unusable.

  - Mainnet Similarity: The script modifies mainnet ledgers minimally to
    preserve realistic stake distribution among block producers.

  - Key Allocation: By default, generated plain keys are not in the ledger
    (equivalent to zero balance). The script explicitly allocates balances
    to BP keys (in the amount of \$KEY_BALANCE or 1000 MINA per key) and
    specified balance with -b option to extra keys. Extra keys are always
    the first few plain keys.
    
  - Stake Distribution: The existing mainnet stake is split equally between
    BP keys and extra keys through delegation. However, extra keys may end up
    with higher effective stake than BP keys due to the additional balance
    assigned via the -b flag, which increases their total stake beyond the
    delegated portion.

OUTPUT FILES NEEDED FOR HF DRYRUN:
  - PREFIX/ directory                     Generated ledger directory
  - PREFIX-bp*.pub, PREFIX-bp*            Block producer key pairs
  - PREFIX-plain*.pub, PREFIX-plain*      Plain key pairs
  - runtime_config.json                   Final runtime configuration

OUTPUT FILES WHICH ARE NOT NEEDED FOR HF DRYRUN (can be deleted):
  - runtime_config_full.json              Verbose runtime configuration, with json ledger definitions
  - hashes.json                           Ledger hashes file
  - genesis.json, staking.json,
    next.json, next-staking-<epoch>.json,
    staking-<epoch>.json                  Mainnet ledger files

=============================================================================
EOF
}

# Validation functions
validate_timestamp() {
    if ! date -d "$1" >/dev/null 2>&1; then
        echo "Error: Invalid timestamp format: $1" >&2
        echo "Expected ISO 8601 format, e.g., 2024-08-01T12:00:00Z" >&2
        exit 1
    fi
}

validate_positive_integer() {
    local value="$1"
    local name="$2"
    local max="${3:-}"
    
    if ! [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: $name must be a positive integer, got: $value" >&2
        exit 1
    fi
    
    if [[ -n "$max" ]] && (( value > max )); then
        echo "Error: $name must be <= $max, got: $value" >&2
        exit 1
    fi
}

validate_balance() {
    if ! [[ "$1" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: Balance must be a positive integer (MINA units), got: $1" >&2
        exit 1
    fi
    
    if (( $1 > 1000000000 )); then
        echo "Warning: Balance $1 MINA is very large and may distort mainnet-like distribution" >&2
        echo "Consider using a smaller value to maintain realistic testing conditions" >&2
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--timestamp)
            GENESIS_TIMESTAMP="$2"
            validate_timestamp "$GENESIS_TIMESTAMP"
            shift 2
            ;;
        -p|--bp-keys)
            BP_KEYS="$2"
            validate_positive_integer "$BP_KEYS" "BP keys" 50
            shift 2
            ;;
        -k|--plain-keys)
            PLAIN_KEYS="$2"
            validate_positive_integer "$PLAIN_KEYS" "Plain keys" 100
            shift 2
            ;;
        -b|--balance)
            EXTRA_BALANCE="$2"
            validate_balance "$EXTRA_BALANCE"
            shift 2
            ;;
        -e|--extra-keys)
            EXTRA_KEYS="$2"
            validate_positive_integer "$EXTRA_KEYS" "Extra keys" 50
            shift 2
            ;;
        --prefix)
            PREFIX="$2"
            if [[ ! "$PREFIX" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                echo "Error: Prefix must contain only alphanumeric characters, hyphens, and underscores" >&2
                exit 1
            fi
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            if [[ ! -d "$OUTPUT_DIR" ]]; then
                echo "Error: Output directory does not exist: $OUTPUT_DIR" >&2
                exit 1
            fi
            shift 2
            ;;
        --mina-binary)
            MINA_BINARY="$2"
            shift 2
            ;;
        --runtime-genesis-ledger-binary)
            RUNTIME_GENESIS_LEDGER_BINARY="$2"
            shift 2
            ;;
        --pad-app-state)
            PAD_APP_STATE="--pad-app-state"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Validate configuration after parsing arguments
if (( EXTRA_KEYS > PLAIN_KEYS )); then
    echo "Error: Extra keys ($EXTRA_KEYS) cannot exceed plain keys ($PLAIN_KEYS)" >&2
    echo "Either increase --plain-keys or decrease --extra-keys" >&2
    exit 1
fi

# Check if nix is needed after parsing arguments
check_nix_if_needed

# Change to output directory
cd "$OUTPUT_DIR"

# Display configuration
echo "=== Mina Hard Fork Dry Run Ledger Generator ==="
echo "Configuration:"
echo "  Genesis Timestamp: $GENESIS_TIMESTAMP"
echo "  Block Producer Keys: $BP_KEYS"
echo "  Plain Keys: $PLAIN_KEYS"
echo "  Balance for each extra key: $EXTRA_BALANCE MINA"
echo "  Extra Keys: $EXTRA_KEYS"
echo "  Key Prefix: $PREFIX"
echo "  Staking Seed: $STAKING_SEED"
echo "  Next Seed: $NEXT_SEED"
echo "  Output Directory: $OUTPUT_DIR"
echo "  Mina Binary: ${MINA_BINARY:-"(will build if needed)"}"
echo "  Runtime Genesis Ledger Binary: ${RUNTIME_GENESIS_LEDGER_BINARY:-"(will build if needed)"}"
echo "  Pad App State: ${PAD_APP_STATE:-"disabled"}"
echo

# Ensure binaries are available
ensure_binary() {
    local binary_var="$1"
    local binary_path="${!binary_var}"
    local nix_target="$2"
    local binary_name="$3"
    
    if [[ -n "$binary_path" ]] && [[ -x "$binary_path" ]]; then
        echo "Using existing $binary_name: $binary_path"
        return 0
    fi
    
    if [[ -n "$binary_path" ]] && [[ ! -x "$binary_path" ]]; then
        echo "Error: Specified $binary_name not found or not executable: $binary_path" >&2
        exit 1
    fi
    
    echo "Building $binary_name..."
    local nix_result
    nix_result=$(nix build --no-link --print-out-paths "$(dirname "$SCRIPT_DIR")?submodules=1"#"$nix_target")
    local new_binary_path="$nix_result/bin/$binary_name"
    
    if [[ ! -x "$new_binary_path" ]]; then
        echo "Error: Built binary not found: $new_binary_path" >&2
        exit 1
    fi
    
    eval "$binary_var=\"$new_binary_path\""
    echo "Built $binary_name: $new_binary_path"
}

ensure_binary "MINA_BINARY" "devnet" "mina"
ensure_binary "RUNTIME_GENESIS_LEDGER_BINARY" "devnet.genesis" "runtime_genesis_ledger"

# Generate block producer keys
echo "Generating $BP_KEYS block producer keys..."
for ((i=1; i<=BP_KEYS; i++)); do
    if [[ -f "${PREFIX}-bp${i}" ]] && [[ -f "${PREFIX}-bp${i}.pub" ]]; then
        echo "  Skipping ${PREFIX}-bp${i} (already exists)..."
    else
        echo "  Generating ${PREFIX}-bp${i}..."
        "$MINA_BINARY" advanced generate-keypair --privkey-path "${PREFIX}-bp${i}"
    fi
done

# Generate plain keys
echo "Generating $PLAIN_KEYS plain keys..."
for ((i=1; i<=PLAIN_KEYS; i++)); do
    if [[ -f "${PREFIX}-plain${i}" ]] && [[ -f "${PREFIX}-plain${i}.pub" ]]; then
        echo "  Skipping ${PREFIX}-plain${i} (already exists)..."
    else
        echo "  Generating ${PREFIX}-plain${i}..."
        "$MINA_BINARY" advanced generate-keypair --privkey-path "${PREFIX}-plain${i}"
    fi
done

# Build key arguments for prepare-test-ledger script
echo "Preparing ledger with key allocations..."
KEY_ARGS=()

# Add all block producer keys (they get default balance from prepare-test-ledger)
for ((i=1; i<=BP_KEYS; i++)); do
    if [[ -f "${PREFIX}-bp${i}.pub" ]]; then
        KEY_ARGS+=("$(cat "${PREFIX}-bp${i}.pub")")
    else
        echo "Error: Block producer key file ${PREFIX}-bp${i}.pub not found" >&2
        exit 1
    fi
done

# Add extra keys (they are assigned specified balance)
for ((i=1; i<=EXTRA_KEYS; i++)); do
    if [[ -f "${PREFIX}-plain${i}.pub" ]]; then
        KEY_ARGS+=("$(cat "${PREFIX}-plain${i}.pub")")
    else
        echo "Error: Extra key file ${PREFIX}-plain${i}.pub not found" >&2
        exit 1
    fi
done

# Verify required scripts exist and are executable
if [[ ! -x "$SCRIPT_DIR/prepare-test-ledger-hf-dryrun.sh" ]]; then
    echo "Error: Required script not found or not executable: $SCRIPT_DIR/prepare-test-ledger-hf-dryrun.sh" >&2
    exit 1
fi

if [[ ! -x "$SCRIPT_DIR/prepare-test-ledger.sh" ]]; then
    echo "Error: Required script not found or not executable: $SCRIPT_DIR/prepare-test-ledger.sh" >&2
    exit 1
fi

# Call prepare-test-ledger script with all keys
echo "Calling prepare-test-ledger-hf-dryrun.sh with:"
echo "  Extra keys: $EXTRA_KEYS"
echo "  Balance for each extra key: $EXTRA_BALANCE MINA"
echo "  Total keys added to ledger: ${#KEY_ARGS[@]}"
echo "  Number of plain keys not put into ledger: $((PLAIN_KEYS - EXTRA_KEYS))"
# Print percentage of extra and bp keys of the total keys in ledger
PERCENTAGE_BP_KEYS=$(( (BP_KEYS * 10000) / ${#KEY_ARGS[@]} ))
PERCENTAGE_EXTRA_KEYS=$(( (EXTRA_KEYS * 10000) / ${#KEY_ARGS[@]} ))
PERCENTAGE_BP_KEYS_DISPLAY=$((PERCENTAGE_BP_KEYS / 100)).$((PERCENTAGE_BP_KEYS % 100))
PERCENTAGE_EXTRA_KEYS_DISPLAY=$((PERCENTAGE_EXTRA_KEYS / 100)).$((PERCENTAGE_EXTRA_KEYS % 100))
echo "  Target stake ownership by active stake (block producer keys): $PERCENTAGE_BP_KEYS_DISPLAY%"
echo "  Target stake ownership by inactive stake (plain keys): $PERCENTAGE_EXTRA_KEYS_DISPLAY%"

"$SCRIPT_DIR/prepare-test-ledger-hf-dryrun.sh" -e "$EXTRA_KEYS" -b "$EXTRA_BALANCE" "${KEY_ARGS[@]}"

# Verify expected output files were generated
if [[ ! -f "genesis.json" ]]; then
    echo "Error: Expected output file genesis.json was not generated by prepare script" >&2
    exit 1
fi

if [[ ! -f "staking.json" ]]; then
    echo "Error: Expected output file staking.json was not generated by prepare script" >&2
    exit 1
fi

if [[ ! -f "next.json" ]]; then
    echo "Error: Expected output file next.json was not generated by prepare script" >&2
    exit 1
fi

# Generate full runtime configuration
echo "Generating runtime configuration..."
JQ_FULL_EXPR='{ledger:{add_genesis_winner:false, accounts: $genesis[0]},epoch_data:{staking:{seed:"'"$STAKING_SEED"'", accounts:$staking[0]}, next:{seed:"'"$NEXT_SEED"'", accounts:$next[0]}}}'
jq --slurpfile genesis genesis.json --slurpfile staking staking.json --slurpfile next next.json -n "$JQ_FULL_EXPR" > runtime_config_full.json

# Validate cache directory can be created
echo "Validating temporary directory access..."
CACHE_BASE_DIR="${TMPDIR:-/tmp}"
CACHE_DIR="$CACHE_BASE_DIR/coda_cache_dir"
test_cache_dir="$CACHE_DIR/test-$(date +%s)-$$"
if ! mkdir -p "$test_cache_dir" 2>/dev/null; then
    echo "Error: Cannot create cache directory in $CACHE_DIR" >&2
    echo "This is required by the runtime_genesis_ledger binary." >&2
    echo "Please ensure $CACHE_BASE_DIR exists and is writable, or set TMPDIR to a writable directory." >&2
    exit 1
fi
rmdir "$test_cache_dir" 2>/dev/null || true
rmdir "$CACHE_DIR" 2>/dev/null || true

# Generate ledger hashes
echo "Generating ledger hashes..."
"$RUNTIME_GENESIS_LEDGER_BINARY" --config-file runtime_config_full.json --hash-output-file hashes.json --genesis-dir "$PREFIX" --ignore-missing $PAD_APP_STATE

# Generate final runtime configuration with timestamp
echo "Generating final runtime configuration..."
JQ_EXPR='{genesis:{genesis_state_timestamp:"'"$GENESIS_TIMESTAMP"'"},ledger:{add_genesis_winner:false},epoch_data:{staking:{seed:"'"$STAKING_SEED"'"}, next:{seed:"'"$NEXT_SEED"'"}}}' 
jq --slurpfile hashes hashes.json -n "$JQ_EXPR * \$hashes[0]" > runtime_config.json

echo
echo "=== Generation Complete ==="
echo "Generated files:"
echo "  Key files: ${PREFIX}-bp*.{pub,key}, ${PREFIX}-plain*.{pub,key}"
echo "  Configuration: runtime_config.json, runtime_config_full.json"
echo "  Hashes: hashes.json"
echo "  Ledger files: genesis.json, staking.json, next.json"
echo "  Ledger directory: $PREFIX/"
echo
echo "The generated ledgers are ready for hard fork testing."
echo "Use runtime_config.json as the configuration file for your test network."