#!/usr/bin/env bash
# /usr/lib/mina/bin/mina-dispatch
#
# =============================================================================
# MINA DISPATCHER
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
#   6. Only "daemon" gets hardfork-aware argument rewriting. "client", "libp2p"
#      and "--version" are forwarded to the selected runtime as-is. Any other
#      subcommand is rejected and must be run by invoking the runtime binary
#      directly (mina-berkeley, mina-mesa, or the full /usr/lib/mina/... path).
#
# RUNTIME SELECTION:
#   - MINA_HARDFORK_STATE_DIR absent  -> berkeley runtime (pre-hardfork)
#   - MINA_HARDFORK_STATE_DIR present -> mesa runtime (post-hardfork)
#
# ARGUMENT PROCESSING (mesa runtime, daemon only):
#   - "-config-file <path>" is KEPT and MESA_CONFIG is appended as the last -config-file
#   - "--genesis-ledger-dir <path>" is rewritten to use MESA_LEDGERS_DIR
#   - "--hardfork-handling <value>" is REMOVED (not supported in mesa)
#   - If --genesis-ledger-dir is not provided, it is appended with MESA_LEDGERS_DIR
#   - Auto-hardfork daemon config (-config-file MESA_CONFIG) is always appended last
#
# ARGUMENT PROCESSING (berkeley runtime, daemon only):
#   - If "--hardfork-handling" is not provided, "--hardfork-handling migrate-exit"
#     is appended (installing the automode package implies automode). If the user
#     provides their own "--hardfork-handling", arguments are left untouched.
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
#   Set MINA_DISPATCHER_DRYRUN=1 in environment to print the exec command instead
#   of executing it. Useful for debugging argument processing and runtime
#   selection.
#   Example:
#     MINA_DISPATCHER_DRYRUN=1 mina daemon --peer-list-url ...
#   Output (to stderr):
#     mina-dispatch DRYRUN: exec /path/to/binary arg1 arg2 ...
#
# JSON MODE:
#   Set MINA_DISPATCHER_JSON=1 to emit a single machine-readable JSON object on
#   stdout instead of human-readable text, so callers can parse the dispatch
#   decision/errors with jq rather than scraping stderr. Implies dry-run (the
#   command is described, not exec'd). Examples:
#     resolved command:
#       {"runtime":"mesa","binary":"/usr/lib/mina/mesa/mina",
#        "args":["daemon","-config-file","..."],"command":"/usr/lib/mina/mesa/mina daemon ..."}
#     error:
#       {"error":"config_directory_discrepancy","exit_code":1,"message":"..."}
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
# JSON mode: emit machine-readable output instead of human-readable text, so
# callers (e.g. the dispatcher tests) can parse decisions/errors with jq rather
# than substring-matching. Implies dry-run for the success path (we describe the
# command instead of exec'ing it). Off by default; production behaviour is
# unchanged when MINA_DISPATCHER_JSON=0.
MINA_DISPATCHER_JSON=${MINA_DISPATCHER_JSON:-0}

# =============================================================================
# Output Helpers (human-readable vs JSON)
# =============================================================================

# Escape a string for embedding in a JSON double-quoted value.
json_escape() {
  local s="$1" out="" i c
  for (( i = 0; i < ${#s}; i++ )); do
    c="${s:i:1}"
    case "$c" in
      '"') out+=$'\\"' ;;
      \\) out+=$'\\\\' ;;
      $'\n') out+='\n' ;;
      $'\t') out+='\t' ;;
      $'\r') out+='\r' ;;
      *) out+="$c" ;;
    esac
  done
  printf '%s' "$out"
}

# Emit a JSON array of the given strings: ["a","b",...]
json_array() {
  local first=1 elem
  printf '['
  for elem in "$@"; do
    if [[ $first -eq 1 ]]; then first=0; else printf ','; fi
    printf '"%s"' "$(json_escape "$elem")"
  done
  printf ']'
}

# True when the dispatcher should describe (not execute) the command: either an
# explicit dry-run, or JSON mode (which always describes rather than exec's).
dryrun_active() {
  [[ "${MINA_DISPATCHER_DRYRUN:-0}" -ne 0 || "${MINA_DISPATCHER_JSON:-0}" -ne 0 ]]
}

# Report an error and exit. In JSON mode a single object is printed to stdout:
#   {"error":"<key>","exit_code":<n>,"message":"<joined message>"}
# Otherwise the provided lines are printed to stderr verbatim (preserving the
# original human-readable output) and the same exit code is used.
# Usage: dispatch_fail <exit_code> <error_key> <line> [line...]
dispatch_fail() {
  local code="$1" key="$2"
  shift 2
  if [[ "$MINA_DISPATCHER_JSON" -ne 0 ]]; then
    printf '{"error":"%s","exit_code":%s,"message":"%s"}\n' \
      "$(json_escape "$key")" "$code" "$(json_escape "$*")"
  else
    printf '%s\n' "$@" >&2
  fi
  exit "$code"
}

# Emit the resolved dry-run command. In JSON mode a single object is printed to
# stdout describing the runtime, binary and final argument vector:
#   {"runtime":"<rt>","binary":"<bin>","args":[...],"command":"<bin args>"}
# Otherwise the original human-readable line is printed to stderr.
# Usage: emit_dryrun <runtime> <binary> [arg...]
emit_dryrun() {
  local rt="$1" bin="$2"
  shift 2
  if [[ "$MINA_DISPATCHER_JSON" -ne 0 ]]; then
    local command="$bin"
    if [[ $# -gt 0 ]]; then
      command="$bin $*"
    fi
    printf '{"runtime":"%s","binary":"%s","args":%s,"command":"%s"}\n' \
      "$(json_escape "$rt")" \
      "$(json_escape "$bin")" \
      "$(json_array "$@")" \
      "$(json_escape "$command")"
  elif [[ $# -gt 0 ]]; then
    echo "mina-dispatch DRYRUN: exec $bin $*" >&2
  else
    echo "mina-dispatch DRYRUN: exec $bin" >&2
  fi
}

# Validate source file exists before sourcing
if [[ ! -f "$SOURCE_FILE" ]]; then
  dispatch_fail 1 source_file_not_found \
    "mina-dispatch ERROR: source file not found: $SOURCE_FILE" \
    "  Installation is incomplete or corrupted." \
    "  Expected configuration at: $SOURCE_FILE"
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
    dispatch_fail 1 required_var_undefined \
      "mina-dispatch ERROR: $var is not defined" \
      "  This variable should be set in: $SOURCE_FILE"
  fi
done

if [[ -z "${MINA_HARDFORK_STATE_DIR:-}" ]]; then
  dispatch_fail 1 missing_hardfork_state_dir \
    "mina-dispatch ERROR: MINA_HARDFORK_STATE_DIR is not defined" \
    "  This variable should be set in your environment and point" \
    "  to the mina config directory (usually ${HOME}/.mina-config)."
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
    dispatch_fail 1 no_command \
      "mina-dispatch ERROR: no command provided" \
      "  Usage: mina-dispatch <command> [arguments...]" \
      "  Example: mina-dispatch mina daemon --help"
  fi
  cmd="$1"
  shift
fi

# Validate command name contains only safe characters
if [[ ! "$cmd" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  dispatch_fail 1 invalid_command_name \
    "mina-dispatch ERROR: invalid command name: $cmd"
fi

# =============================================================================
# Binary Resolution
# =============================================================================

bin="${RUNTIMES_BASE_PATH}/${runtime}/${cmd}"

if [[ ! -f "$bin" ]]; then
  dispatch_fail 127 binary_not_found \
    "mina-dispatch ERROR: binary not found: $bin"
fi

if [[ ! -x "$bin" ]]; then
  dispatch_fail 127 binary_not_executable \
    "mina-dispatch ERROR: binary not executable: $bin"
fi

# =============================================================================
# libp2p Helper Configuration (mina command only)
# =============================================================================

if [[ "$cmd" == "mina" ]]; then
  helper="${RUNTIMES_BASE_PATH}/${runtime}/coda-libp2p_helper"
  if [[ ! -x "$helper" ]]; then
    dispatch_fail 127 libp2p_helper_not_found \
      "mina-dispatch ERROR: coda-libp2p_helper not found or not executable: $helper"
  fi
  export "${MINA_LIBP2P_ENVVAR_NAME}=${helper}"
fi

# =============================================================================
# Argument Processing
# =============================================================================

# Normalize a filesystem path for comparison purposes.
# Collapses trailing slashes, "." / ".." segments and (for any existing
# prefix) symlinks, so that paths that point to the same location compare
# equal even when written differently (e.g. "/a/b", "/a/b/", "/a/./b").
# The path does NOT need to exist (realpath -m is purely lexical for the
# non-existent tail). Falls back to the raw value if realpath is unavailable.
function normalize_path() {
  local path="$1"
  realpath -m -- "$path" 2>/dev/null || echo "$path"
}

# Detailed explanation of the argument processing logic
function print_argument_warning() {
  echo "  Automatic argument adjustments are only implemented for the 'daemon' subcommand." >&2
  echo "  Please ensure you are invoking the correct runtime binary directly if needed." >&2
  echo "  For example, use 'mina-berkeley' or 'mina-mesa' instead of relying on the dispatcher (mina)." >&2
  echo "  If you want to call others utility daemon apps using specific version need to be called by full path /usr/lib/mina/berkeley/... or /usr/lib/mina/mesa/..." >&2
}

first_arg=""

# Copy arguments to a new array for processing
# Handle empty arguments case safely with set -u
if [[ $# -gt 0 ]]; then
  args=("$@")
  first_arg="${args[0]}"
else
  args=()
fi

if [[ -z "$first_arg" ]]; then
  if [[ "$MINA_DISPATCHER_JSON" -ne 0 ]]; then
    dispatch_fail 1 no_subcommand \
      "mina-dispatch ERROR: no subcommand provided for automatic hardfork handling"
  fi
  echo "mina-dispatch ERROR: no subcommand provided for automatic hardfork handling" >&2
  print_argument_warning
  exit 1
fi

if [[ "$first_arg" == "--version" || "$first_arg" == "-version" ]]; then
  # Pass --version directly to the binary without argument processing
  if dryrun_active; then
    emit_dryrun "$runtime" "$bin" "$first_arg"
    exit 0
  fi
  exec "$bin" "$first_arg"
fi

if [[ "$first_arg" == "client" ]]; then
  # HACK: 'client' subcommands (e.g. 'mina client status') are always routed to
  # the mesa binary. This works only because the GraphQL schema exposed by the
  # daemon did not change between berkeley and mesa. If a future hard fork
  # changes the GraphQL schema, client commands must be dispatched to the
  # correct runtime binary instead of unconditionally using mesa.
  runtime="mesa"
  bin="${RUNTIMES_BASE_PATH}/${runtime}/${cmd}"
  if dryrun_active; then
    emit_dryrun "$runtime" "$bin" "${args[@]}"
    exit 0
  fi
  exec "$bin" "${args[@]}"
fi

if [[ "$first_arg" == "libp2p" ]]; then
  # 'libp2p' subcommands (e.g. 'mina libp2p generate-keypair') are hardfork
  # agnostic: they need none of the --genesis-ledger-dir / -config-file rewriting
  # that 'daemon' requires, so they are forwarded verbatim to the selected
  # runtime. The MINA_LIBP2P_HELPER_PATH export done earlier (for cmd == "mina")
  # is inherited by the exec'd process, so this works without manual setup.
  echo "mina-dispatch INFO: passing 'libp2p' through to ${runtime} runtime" >&2
  if [[ "${MINA_DISPATCHER_DRYRUN:-0}" -ne 0 ]]; then
    echo "mina-dispatch DRYRUN: exec $bin ${args[*]}" >&2
    exit 0
  fi
  exec "$bin" "${args[@]}"
fi

if [[ "$first_arg" != "daemon" ]]; then
  if [[ "$MINA_DISPATCHER_JSON" -ne 0 ]]; then
    dispatch_fail 1 unsupported_subcommand \
      "mina-dispatch ERROR: unsupported subcommand '$first_arg' for automatic hardfork handling"
  fi
  echo "mina-dispatch ERROR: unsupported subcommand '${first_arg:-<none>}' for automatic hardfork handling" >&2
  echo "  Only 'daemon' is rewritten; 'libp2p', 'client' and '--version' are passed through." >&2
  echo "  To run any other subcommand against a specific runtime, call the binary directly:" >&2
  echo "    ${RUNTIMES_BASE_PATH}/berkeley/mina <subcommand> ...   (pre-fork)" >&2
  echo "    ${RUNTIMES_BASE_PATH}/mesa/mina <subcommand> ...       (post-fork)" >&2
  exit 1
fi

if [[ "$runtime" == "mesa" ]]; then
  # Build a new argument array to ensure continuous indices
  # This is safer than unsetting elements which creates sparse arrays
  new_args=()
  found_genesis_ledger_dir=false
  config_file_arg_used=false
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
        # Keep user-provided config file, auto-hardfork config will be appended last
        if [[ "$has_next_arg" == true ]]; then
          config_file_arg_used=true
          echo "mina-dispatch INFO: User-provided config file detected: ${args[$next_i]}" >&2
          echo "  Auto-hardfork daemon config ($MESA_CONFIG) will be appended as the last -config-file argument." >&2
          new_args+=("$arg" "${args[$next_i]}")
          skip_next=true
        else
          # No value provided, pass through as-is (will error at runtime)
          new_args+=("$arg")
        fi
        ;;

      -config-directory|--config-directory)
        # Check config directory provided as next arg is equal to MINA_HARDFORK_STATE_PARENT_FOLDER
        if [[ "$has_next_arg" == true ]]; then
          provided_dir="${args[$next_i]}"
          # Compare as normalized paths, not raw strings, so that equivalent
          # spellings (trailing slash, "." / ".." segments) are accepted.
          if [[ "$(normalize_path "$provided_dir")" != "$(normalize_path "$MINA_HARDFORK_STATE_DIR")" ]]; then
            dispatch_fail 1 config_directory_discrepancy \
              "mina-dispatch ERROR: Discrepancy between provided --config-directory ($provided_dir) and expected ($MINA_HARDFORK_STATE_DIR)" \
              " Those must match for auto hardfork mode correct behavior." \
              " Please adjust your invocation accordingly."
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

    # Always append auto-hardfork daemon config as the last -config-file argument.
    # As mina daemon subcommand accepts more than one config argument,
    # we always append ours at end to override genesis ledger part.
    if [[ "$config_file_arg_used" == true ]]; then
      echo "mina-dispatch INFO: Appending auto-hardfork config as last -config-file argument" >&2
    fi
    new_args+=("-config-file" "$MESA_CONFIG")
  fi
  # Replace args with the processed continuous array
  args=("${new_args[@]}")
elif [[ "$first_arg" == "daemon" ]]; then
  # Berkeley (pre-fork) runtime. The automode package runs the pre-fork daemon
  # in migrate-exit mode by default: installing the automode package implies
  # automode, so there is no reason to make users pass --hardfork-handling
  # themselves (see https://github.com/MinaProtocol/MIPs/pull/32).
  #
  # If the user explicitly passes --hardfork-handling we assume they know what
  # they are doing and leave the arguments untouched.
  has_hardfork_handling=false
  for arg in "${args[@]}"; do
    if [[ "$arg" == "--hardfork-handling" || "$arg" == "-hardfork-handling" ]]; then
      has_hardfork_handling=true
      break
    fi
  done

  if [[ "$has_hardfork_handling" == false ]]; then
    args+=("--hardfork-handling" "migrate-exit")
  elif [[ "$MINA_DISPATCHER_DEBUG" -ne 0 ]]; then
    echo "mina-dispatch INFO: User-provided --hardfork-handling detected; leaving it untouched" >&2
  fi
fi

# =============================================================================
# Execution
# =============================================================================


# DRYRUN / JSON: describe the command instead of executing it, then exit.
if dryrun_active; then
  emit_dryrun "$runtime" "$bin" "${args[@]}"
  exit 0
fi

# Execute the binary with processed arguments
# Handle empty args array safely for bash strict mode
if [[ ${#args[@]} -gt 0 ]]; then
  if [[ "$MINA_DISPATCHER_DEBUG" -ne 0 ]]; then
    echo "DEBUG: Executing $bin with arguments: ${args[*]}" >&2
  fi
  exec "$bin" "${args[@]}"
else
  if [[ "$MINA_DISPATCHER_DEBUG" -ne 0 ]]; then
    echo "DEBUG: Executing $bin with no arguments" >&2
  fi
  exec "$bin"
fi
