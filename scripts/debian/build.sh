#!/bin/bash

# Script collects binaries and keys and builds deb archives.
# Supports parallel builds via MINA_DEB_JOBS (default: nproc, fallback 1).

set -eou pipefail

# Respect pre-existing SCRIPTPATH (allows test suites to source build.sh).
SCRIPTPATH="${SCRIPTPATH:-$( cd "$(dirname "$0")" ; pwd -P )}"
BUILD_DIR=${BUILD_DIR:-"${SCRIPTPATH}/../../_build"}

# Check if BUILD_DIR exists
if [[ ! -d "$BUILD_DIR" ]]; then
  echo "Error: BUILD_DIR '$BUILD_DIR' does not exist."
  echo "This means the build process has not been completed successfully or the directory is incorrect."
  echo "Please ensure you have built the applications first, or check if:"
  echo "  - You are running this script from the correct directory (if not using BUILD_DIR, run it from the root of the project)"
  echo "  - BUILD_DIR environment variable is set correctly (if using BUILD_DIR)"
  echo "  - The build process completed successfully"
  exit 1
fi

source "${SCRIPTPATH}"/../export-git-env-vars.sh

# shellcheck disable=SC1090
BUILD_DIR="${BUILD_DIR}" source "${SCRIPTPATH}/builder-helpers.sh"

# ---------------------------------------------------------------------------
# Token → output mapping
# ---------------------------------------------------------------------------

# resolve_deb_output: maps a build token to the **debian package name**
# (without version/arch suffix) that it produces.
# Prints the package name to stdout. Exits non-zero for unknown tokens.
resolve_deb_output() {
  local token="$1"

  case "$token" in
    # Simple single-name packages
    runtime)               local _sfx="${DEB_SUFFIX#-}"
                           echo "mina-runtime-${RUNTIME_CODENAME:-develop}${_sfx:+-${_sfx}}" ;;
    logproc)               echo "mina-logproc" ;;
    minimina)              echo "minimina" ;;
    tx_tools)              echo "mina-tx-tools" ;;
    test_executive)        echo "mina-test-executive" ;;
    functional_test_suite) echo "mina-test-suite" ;;
    delegation_verify)     echo "mina-delegation-verify" ;;
    daemon_storage_toolbox) echo "mina-daemon-storage-toolbox" ;;

    # Rosetta packages
    rosetta_mainnet) echo "mina-rosetta-mainnet${DEB_SUFFIX}" ;;
    rosetta_devnet)  echo "mina-rosetta-devnet${DEB_SUFFIX}" ;;

    # Archive packages
    archive_mainnet) echo "mina-archive-mainnet${DEB_SUFFIX}" ;;
    archive_devnet)  echo "${MINA_ARCHIVE_DEB_NAME}" ;;

    # Daemon L2 packages
    daemon_mainnet) echo "mina-mainnet" ;;
    daemon_devnet)  echo "mina-devnet" ;;

    # Hardfork config packages (own the mina-<network>-config name; the
    # regular config packages are retired — their content lives in the daemon
    # L2 packages now.)
    daemon_mainnet_hardfork_config) echo "mina-mainnet-config" ;;
    daemon_devnet_hardfork_config)  echo "mina-devnet-config" ;;

    # Prefork / postfork / automode
    daemon_mainnet_prefork)  echo "mina-mainnet-prefork-${POSTFORK_CODENAME:-mesa}" ;;
    daemon_devnet_prefork)   echo "mina-devnet-prefork-${POSTFORK_CODENAME:-mesa}" ;;
    daemon_mainnet_postfork) echo "mina-mainnet-postfork-${POSTFORK_CODENAME:-mesa}" ;;
    daemon_devnet_postfork)  echo "mina-devnet-postfork-${POSTFORK_CODENAME:-mesa}" ;;
    daemon_mainnet_automode) echo "mina-mainnet-automode" ;;
    daemon_devnet_automode)  echo "mina-devnet-automode" ;;

    # Profile packages
    profile_mainnet) echo "mina-mainnet-profile" ;;
    profile_devnet)  echo "mina-devnet-profile" ;;
    profile_lightnet) echo "mina-lightnet" ;;
    profile_dev)      echo "mina-dev" ;;

    # Prefork genesis ledger packages
    prefork_mainnet_genesis_ledger) echo "mina-create-mainnet-prefork-genesis-ledger" ;;
    prefork_devnet_genesis_ledger)  echo "mina-create-devnet-prefork-genesis-ledger" ;;

    *)
      echo "Unsupported token '${token}' — cannot resolve to a known .deb package name" >&2
      return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Package dispatch (unchanged logic, extracted to function)
# ---------------------------------------------------------------------------

resolve_and_build_package() {
  local package="$1"

  # TODO: consider further refactor on dhall's side so we can remove the name
  # resolving logic
  if [[ $(type -t "build_${package}_deb") == function ]]; then
    "build_${package}_deb"
    return
  fi

  if [[ "$package" =~ ^(archive|rosetta)_(mainnet|devnet)$ ]]; then
    "build_${BASH_REMATCH[1]}_deb" "${BASH_REMATCH[2]}"
    return
  fi

  if [[ "$package" =~ ^daemon_(mainnet|devnet)$ ]]; then
    build_daemon_deb "${BASH_REMATCH[1]}"
    return
  fi

  if [[ "$package" =~ ^daemon_(mainnet|devnet)_(hardfork_config|prefork|postfork|automode)$ ]]; then
    "build_daemon_${BASH_REMATCH[2]}_deb" "${BASH_REMATCH[1]}"
    return
  fi

  if [[ "$package" =~ ^prefork_(mainnet|devnet)_genesis_ledger$ ]]; then
    build_prefork_genesis_ledger_deb "${BASH_REMATCH[1]}"
    return
  fi

  if [[ "$package" =~ ^profile_(mainnet|devnet|lightnet|dev)$ ]]; then
    "build_profile_deb" "${BASH_REMATCH[1]}"
    return
  fi

  echo "Invalid debian package name '$package'"
  exit 1
}

# ---------------------------------------------------------------------------
# Duplicate-output validation
# ---------------------------------------------------------------------------

# validate_unique_outputs: checks that every token in the given array resolves
# to a unique .deb package name.  Exits non-zero on the first collision.
#
# Usage:  validate_unique_outputs targets_array
validate_unique_outputs() {
  local -n _tokens=$1
  local -A seen
  local pkg

  for t in "${_tokens[@]}"; do
    if ! pkg=$(resolve_deb_output "$t"); then
      echo "ERROR: Cannot resolve token '${t}' to a .deb package. Aborting." >&2
      return 1
    fi
    if [[ -n "${seen[$pkg]:-}" ]]; then
      echo "ERROR: Duplicate .deb output detected!" >&2
      echo "  Token '${t}' and token '${seen[$pkg]}' both produce package '${pkg}'" >&2
      echo "  Each requested token must produce a unique .deb file." >&2
      echo "  Remove one of these tokens from the build invocation." >&2
      return 1
    fi
    seen[$pkg]="$t"
  done
}

# ---------------------------------------------------------------------------
# Build execution
# ---------------------------------------------------------------------------

default_targets=(
  runtime
  profile_devnet
  profile_mainnet
  profile_lightnet
  logproc
  archive_devnet
  archive_mainnet
  tx_tools
  daemon_mainnet
  daemon_devnet
  rosetta_mainnet
  rosetta_devnet
  test_executive
  functional_test_suite
  delegation_verify
)

_build_one() {
  local token="$1"
  echo "--- Building: ${token} ($(basename "$BUILDDIR"))"
  resolve_and_build_package "$token"
}

print_worker_log() {
  local token="$1"
  local log_file="$2"
  local status="$3"

  echo "--- [worker:${token}] output (exit ${status})"
  if [[ -f "$log_file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      printf '%s\n' "$line"
    done < "$log_file"
  else
    echo "ERROR: Missing worker log file: ${log_file}" >&2
  fi
  echo "--- [worker:${token}] output end"
}

main() {
  local -a targets
  targets=("$@")
  if [ $# -eq 0 ]; then
    echo "No arguments supplied. Building all known debian packages"
    targets=("${default_targets[@]}")
  fi

  # Phase 1: Validate unique outputs.
  validate_unique_outputs targets

  # Phase 2: Build.
  local mina_deb_jobs
  mina_deb_jobs="${MINA_DEB_JOBS:-$(nproc 2>/dev/null || echo 1)}"

  if [[ "$mina_deb_jobs" -le 1 ]]; then
    echo "--- Building ${#targets[@]} debian package(s) serially (MINA_DEB_JOBS=${mina_deb_jobs})"
    local safe_token
    for t in "${targets[@]}"; do
      safe_token="${t//[^a-zA-Z0-9_-]/_}"
      BUILDDIR="${BUILD_DIR}/deb-build/${safe_token}"
      export BUILDDIR
      mkdir -p "$BUILDDIR"
      _build_one "$t" || exit 1
    done
  else
    echo "--- Building ${#targets[@]} debian package(s) with up to ${mina_deb_jobs} parallel jobs"
    local safe_token worker_dir pid token log_dir log_file finished_pid status
    local -a pids=()
    local -A worker_tokens=()
    local -A worker_logs=()
    local failed=0

    log_dir="${BUILD_DIR}/deb-build/logs"
    mkdir -p "$log_dir"

    # Wait until one worker has finished, then report it in finished_pid and
    # its exit code in status.
    #
    # "wait -n -p finished_pid" gives both in one step, but the -p option needs
    # bash 5.1 and the CI agents have bash 5.0. So do it in two steps:
    #
    #   1. "wait -n" (bash 4.3) blocks until any worker ends. It gives the exit
    #      code but not the PID.
    #   2. Find which worker ended. bash takes a background child out of the
    #      process table as soon as it ends, so "kill -0" fails for that one
    #      only. "wait" on it then still gives its exit code, also after step 1
    #      has already collected it.
    #
    # This holds no delay and does not poll, so a worker is reported at the
    # moment it ends. A worker that an external signal stops, for example the
    # out-of-memory killer, is found in the same way.
    reap_finished_worker() {
      local candidate
      finished_pid=""
      while [[ -z "$finished_pid" ]]; do
        # "|| true" because this script runs under "set -e" and a worker that
        # fails makes "wait -n" give its non-zero exit code. The code is read
        # again below, for the worker that is known.
        wait -n || true
        for candidate in "${pids[@]}"; do
          if ! kill -0 "$candidate" 2>/dev/null; then
            finished_pid="$candidate"
            break
          fi
        done
      done

      if wait "$finished_pid"; then
        status=0
      else
        status=$?
      fi

      token="${worker_tokens[$finished_pid]}"
      log_file="${worker_logs[$finished_pid]}"
      print_worker_log "$token" "$log_file" "$status"

      if [[ "$status" -ne 0 ]]; then
        echo "ERROR: Worker for token '${token}' (PID ${finished_pid}) failed" >&2
        failed=1
      fi

      local -a remaining=()
      for pid in "${pids[@]}"; do
        if [[ "$pid" != "$finished_pid" ]]; then
          remaining+=("$pid")
        fi
      done
      pids=("${remaining[@]}")
      unset 'worker_tokens[$finished_pid]'
      unset 'worker_logs[$finished_pid]'
    }

    for t in "${targets[@]}"; do
      while [[ "${#pids[@]}" -ge "$mina_deb_jobs" ]]; do
        reap_finished_worker
      done

      safe_token="${t//[^a-zA-Z0-9_-]/_}"
      worker_dir="${BUILD_DIR}/deb-build/${safe_token}"
      log_file="${log_dir}/${safe_token}.log"
      mkdir -p "$worker_dir"
      (
        export BUILDDIR="$worker_dir"
        echo "--- [worker] Building: ${t} ($(basename "$BUILDDIR"))"
        resolve_and_build_package "$t"
      ) > "$log_file" 2>&1 &
      pid=$!
      pids+=("$pid")
      worker_tokens[$pid]="$t"
      worker_logs[$pid]="$log_file"
    done

    while [[ "${#pids[@]}" -gt 0 ]]; do
      reap_finished_worker
    done

    if [[ $failed -ne 0 ]]; then
      echo "ERROR: One or more debian package builds failed. See above for details." >&2
      exit 1
    fi
    echo "--- All ${#targets[@]} debian packages built successfully."
  fi
}

# Only run main when executed directly (not sourced, e.g., in tests).
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
