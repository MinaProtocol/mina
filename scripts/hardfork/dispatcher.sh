#!/usr/bin/env bash
# /usr/lib/mina/bin/mina-dispatch
#
# =============================================================================
# MINA DISPATCHER - Production Critical Component
# =============================================================================
#
# PURPOSE:
#   This script acts as a runtime dispatcher for Mina blockchain binaries,
#   transparently routing commands to the appropriate runtime version
#   (berkeley or mesa) based on the current hardfork activation state.
#
# OVERVIEW:
#   During a hardfork transition, nodes need to switch from the pre-fork
#   binary (berkeley) to the post-fork binary (mesa). This dispatcher enables
#   seamless switching without requiring changes to systemd services, scripts,
#   or user workflows.
#
# HOW IT WORKS:
#   1. The dispatcher is installed as a symlink (e.g., /usr/local/bin/mina -> mina-dispatch)
#   2. When invoked, it checks for an activation state file
#   3. If the state file exists, mesa runtime is used; otherwise berkeley
#   4. Arguments are processed and modified as needed for the target runtime
#   5. The actual binary is exec'd with the processed arguments
#   6. Not all subcommand are supported in. Main focus is on "daemon" command. Other commands might require explicit invocation of the runtime binary (mina-berkeley, mina-mesa).
#
# RUNTIME SELECTION:
#   - MINA_HARDFORK_STATE_DIR absent  -> berkeley runtime (pre-hardfork)
#   - MINA_HARDFORK_STATE_DIR present -> mesa runtime (post-hardfork)
#
# ARGUMENT PROCESSING (mesa runtime only):
#   - "-config-file <path>" is rewritten to use MESA_CONFIG
#   - "--genesis-ledger-dir <path>" is rewritten to use MESA_LEDGERS_DIR
#   - "--hardfork-handling <value>" is REMOVED (not supported in mesa)
#   - If --genesis-ledger-dir is not provided, it is appended with MESA_LEDGERS_DIR
#
# REQUIRED ENVIRONMENT (via SOURCE_FILE):
#   MINA_NETWORK          - Network identifier (e.g., mainnet, devnet)
#   MINA_PROFILE          - Profile name for configuration paths
#   RUNTIMES_BASE_PATH    - Base path where runtime binaries are installed
#   MINA_LIBP2P_ENVVAR_NAME - Environment variable name for libp2p helper path
#
# REQUIRED ENVIRONMENT VARIABLES :
#   MINA_HARDFORK_STATE_DIR="${HOME}/.mina-config"
#
# DIRECTORY STRUCTURE:
#   ${RUNTIMES_BASE_PATH}/
#   ├── berkeley/
#   │   ├── mina
#   │   ├── coda-libp2p_helper
#   │   └── ...
#   └── mesa/
#       ├── mina
#       ├── coda-libp2p_helper
#       └── ...
#
# INVOCATION METHODS:
#   1. Via symlink (normal operation):
#      /usr/local/bin/mina daemon --peer-list-url ...
#
#   2. Direct invocation (debugging):
#      mina-dispatch mina daemon --peer-list-url ...
#
# FILES:
#   SOURCE_FILE (default: /etc/default/mina-dispatch)
#     - Configuration file sourced at startup
#     - Must define required environment variables
#
#   MINA_HARDFORK_STATE_DIR (default: ${MESA_CONFIG_ROOT}/activated)
#     - Presence indicates mesa runtime should be used
#     - Created by hardfork activation process
#
# EXIT CODES:
#   0   - Success (binary exec'd successfully)
#   1   - Configuration error (missing file, undefined variable)
#   127 - Binary not found or not executable
#
# DRYRUN MODE:
#   Set DRYRUN=1 in environment to print the exec command instead of executing it.
#   Useful for debugging argument processing and runtime selection.
#   Example:
#     DRYRUN=1 mina daemon --peer-list-url ...
#   Output:
#     mina-dispatch DRYRUN: exec /path/to/binary arg1 arg2 ...
# SECURITY CONSIDERATIONS:
#   - SOURCE_FILE must be owned by root and not world-writable
#   - Binary paths are constructed from trusted configuration only
#   - No user input is used in path construction
#   - Array operations use safe indexing to prevent injection
#
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration Loading
# =============================================================================

SOURCE_FILE=${SOURCE_FILE:-"/etc/default/mina-dispatch"}
MINA_DISPATCHER_DEBUG=${MINA_DISPATCHER_DEBUG:-0}
MINA_DISPATCHER_DRYRUN=${MINA_DISPATCHER_DRYRUN:-0}

# Validate source file exists before sourcing
if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "mina-dispatch ERROR: source file not found: $SOURCE_FILE" >&2
  echo "  Installation is incomplete or corrupted." >&2
  echo "  Expected configuration at: $SOURCE_FILE" >&2
  exit 1
fi

# Security check: warn if source file has problematic permissions
if [[ -w "$SOURCE_FILE" ]] && [[ ! -O "$SOURCE_FILE" ]]; then
  echo "mina-dispatch WARNING: source file is writable by current user but not owned by them" >&2
  echo "  This could be a security risk: $SOURCE_FILE" >&2
fi

# shellcheck source=/etc/default/mina-dispatch
source "${SOURCE_FILE}"

if [[ "$MINA_DISPATCHER_DEBUG" -ne 0 ]]; then
  echo "DEBUG: Loaded configuration from $SOURCE_FILE" >&2
  echo "DEBUG: MINA_NETWORK=$MINA_NETWORK, MINA_PROFILE=$MINA_PROFILE" >&2
  echo "DEBUG: RUNTIMES_BASE_PATH=$RUNTIMES_BASE_PATH" >&2
fi

# =============================================================================
# Required Variable Validation
# =============================================================================

declare -a required_vars=(
  "MINA_NETWORK"
  "MINA_PROFILE"
  "RUNTIMES_BASE_PATH"
  "MINA_LIBP2P_ENVVAR_NAME"
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "mina-dispatch ERROR: $var is not defined" >&2
    echo "  This variable should be set in: $SOURCE_FILE" >&2
    exit 1
  fi
done

if [[ -z "$MINA_HARDFORK_STATE_DIR" ]]; then
  echo "mina-dispatch ERROR: MINA_HARDFORK_STATE_DIR is not defined" >&2
  echo "  This variable should be set in your environment and point" >&2
  echo "  to the mina config directory (usually ${HOME}/.mina-config)." >&2

  exit 1
fi

# =============================================================================
# Path Configuration
# =============================================================================

MESA_HARDFORK_STATE_PARENT_FOLDER="${MINA_HARDFORK_STATE_DIR}/auto-fork-${MINA_NETWORK}-${MINA_PROFILE}"
MESA_CONFIG="${MESA_HARDFORK_STATE_PARENT_FOLDER}/daemon.json"
MESA_LEDGERS_DIR=${MESA_LEDGERS_DIR:-"${MESA_HARDFORK_STATE_PARENT_FOLDER}/genesis"}
STATE_FILE=${OVERRIDE_STATE_FILE:-"${MESA_HARDFORK_STATE_PARENT_FOLDER}/activated"}

# =============================================================================
# Runtime Selection
# =============================================================================

if [[ -f "$STATE_FILE" ]]; then
  runtime="mesa"
else
  runtime="berkeley"
fi

if [[ "$MINA_DISPATCHER_DEBUG" -ne 0 ]]; then
  echo "DEBUG: Selected runtime: $runtime" >&2
  echo "DEBUG: Input arguments: $*" >&2
fi

# =============================================================================
# Command Resolution
# =============================================================================

cmd="$(basename "$0")"

# Handle direct invocation for debugging: mina-dispatch mina --help
if [[ "$cmd" == "mina-dispatch" ]]; then
  if [[ $# -lt 1 ]]; then
    echo "mina-dispatch ERROR: no command provided" >&2
    echo "  Usage: mina-dispatch <command> [arguments...]" >&2
    echo "  Example: mina-dispatch mina daemon --help" >&2
    exit 1
  fi
  cmd="$1"
  shift
fi

# Validate command name contains only safe characters
if [[ ! "$cmd" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "mina-dispatch ERROR: invalid command name: $cmd" >&2
  exit 1
fi

# =============================================================================
# Binary Resolution
# =============================================================================

bin="${RUNTIMES_BASE_PATH}/${runtime}/${cmd}"

if [[ ! -f "$bin" ]]; then
  echo "mina-dispatch ERROR: binary not found: $bin" >&2
  exit 127
fi

if [[ ! -x "$bin" ]]; then
  echo "mina-dispatch ERROR: binary not executable: $bin" >&2
  exit 127
fi

# =============================================================================
# libp2p Helper Configuration (mina command only)
# =============================================================================

if [[ "$cmd" == "mina" ]]; then
  helper="${RUNTIMES_BASE_PATH}/${runtime}/coda-libp2p_helper"
  if [[ ! -x "$helper" ]]; then
    echo "mina-dispatch ERROR: coda-libp2p_helper not found or not executable: $helper" >&2
    exit 127
  fi
  export "${MINA_LIBP2P_ENVVAR_NAME}=${helper}"
fi

# =============================================================================
# Argument Processing
# =============================================================================

# Copy arguments to a new array for processing
# Handle empty arguments case safely with set -u
if [[ $# -gt 0 ]]; then
  args=("$@")
else
  args=()
fi

first_arg="${args[0]}"

if [[ "$first_arg" != "daemon" ]]; then
  echo "mina-dispatch ERROR: unsupported subcommand '$first_arg' for automatic hardfork handling" >&2
  echo "  Automatic argument adjustments are only implemented for the 'daemon' subcommand." >&2
  echo "  Please ensure you are invoking the correct runtime binary directly if needed." >&2
  echo "  For example, use 'mina-berkeley' or 'mina-mesa' instead of relying on the dispatcher (mina)." >&2
fi

if [[ "$runtime" == "mesa" ]]; then
  # Build a new argument array to ensure continuous indices
  # This is safer than unsetting elements which creates sparse arrays
  new_args=()
  found_genesis_ledger_dir=false
  skip_next=false

  i=0
  
  while [[ $i -lt ${#args[@]} ]]; do
    arg="${args[$i]}"

    # Check if we should skip this argument (marked by previous iteration)
    if [[ "$skip_next" == true ]]; then
      skip_next=false
      ((i++)) || true
      continue
    fi

    # Calculate next index safely
    next_i=$((i + 1))
    has_next_arg=false
    if [[ $next_i -lt ${#args[@]} ]]; then
      has_next_arg=true
    fi


    case "$arg" in
      -config-file|--config-file)
        # Rewrite config file path to mesa config
        if [[ "$has_next_arg" == true ]]; then
          config_file_arg_used=true
        else
          # No value provided, pass through as-is (will error at runtime)
          new_args+=("$arg")
        fi
        ;;

      -config-directory|--config-directory)
        # Check config directory provided as next arg is equal to MINA_HARDFORK_STATE_PARENT_FOLDER
        if [[ "$has_next_arg" == true ]]; then
          provided_dir="${args[$next_i]}"
          if [[ "$provided_dir" != "$MESA_HARDFORK_STATE_PARENT_FOLDER" ]]; then
            echo "mina-dispatch ERROR: Discrepancy between provided --config-directory ($provided_dir) and expected ($MESA_HARDFORK_STATE_PARENT_FOLDER)" >&2
            echo " Those must match for auto hardfork mode correct behavior." >&2
            echo " Please adjust your invocation accordingly." >&2
            exit 1
          fi
        fi
        new_args+=("$arg")
        ;;

      --genesis-ledger-dir|-genesis-ledger-dir)
        # Alter arguments only for "daemon" subcommand
        if [[ "$first_arg" == "daemon" ]]; then
          # Rewrite genesis ledger directory to mesa ledgers
          if [[ "$has_next_arg" == true ]]; then
            new_args+=("$arg" "$MESA_LEDGERS_DIR")
            found_genesis_ledger_dir=true
            skip_next=true
          else
            # No value provided, pass through as-is
            new_args+=("$arg")
            found_genesis_ledger_dir=true
          fi
        fi
        ;;

      --hardfork-handling|-hardfork-handling)
        # Remove this argument entirely for mesa runtime
        if [[ "$has_next_arg" == true ]]; then
          skip_next=true
        fi
        # Don't add to new_args - effectively removes the argument
        ;;

      *)
        # Pass through all other arguments unchanged
        new_args+=("$arg")
        ;;
    esac

    ((i++)) || true
  done

  # Append genesis ledger dir if not provided
  if [[ "$first_arg" == "daemon" ]]; then
    if [[ "$found_genesis_ledger_dir" == false ]]; then
      new_args+=("--genesis-ledger-dir" "$MESA_LEDGERS_DIR")
    fi

    if [[ "$config_file_arg_used" == true ]]; then
      # Prepend config file argument if not already provided
      # This ensures mesa uses the correct config file
      # As mina daemon subcommand accepts more than one config argument,
      # we always append ours at end to override genesis ledger part.
      new_args+=("-config-file" "$MESA_CONFIG")
    fi
  fi
  # Replace args with the processed continuous array
  args=("${new_args[@]}")
fi

# =============================================================================
# Execution
# =============================================================================


# DRYRUN: If set, print the exec command and exit
if [[ "${MINA_DISPATCHER_DRYRUN:-0}" -ne 0 ]]; then
  if [[ ${#args[@]} -gt 0 ]]; then
    echo "mina-dispatch DRYRUN: exec $bin ${args[*]}" >&2
  else
    echo "mina-dispatch DRYRUN: exec $bin" >&2
  fi
  exit 0
fi

# Execute the binary with processed arguments
# Handle empty args array safely for bash strict mode
if [[ ${#args[@]} -gt 0 ]]; then
  if [[ "$MINA_DISPATCHER_DEBUG" -ne 0 ]]; then
    echo "DEBUG: Executing $bin with arguments: ${args[*]}" >&2
  fi
  if [[ "${MINA_DISPATCHER_DRYRUN}" -ne 0 ]]; then
    echo "$bin ${args[*]}"
  else
    exec "$bin" "${args[@]}"
  fi
else
  if [[ "$MINA_DISPATCHER_DEBUG" -ne 0 ]]; then
    echo "DEBUG: Executing $bin with no arguments" >&2
  fi
  if [[ "${MINA_DISPATCHER_DRYRUN}" -ne 0 ]]; then
    echo "$bin"
  else
    exec "$bin"
  fi
fi
