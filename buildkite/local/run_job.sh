#!/usr/bin/env bash

# Run a Buildkite job locally by name.
#
# This script sets up the full environment (mimicking what the Buildkite agent does),
# generates pipeline YAMLs from Dhall, syncs the legacy cache from Hetzner, and
# runs the specified job's commands.
#
# Usage:
#   ./run_job.sh [options] <job-name>
#
# Examples:
#   ./run_job.sh --list
#   ./run_job.sh --dry-run RosettaDevnetConnect
#   ./run_job.sh --env-file ./env.sh --step "build-deb-pkg-noble" RosettaDevnetConnect

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDKITE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MINA_ROOT="$(cd "$BUILDKITE_DIR/.." && pwd)"

# ==============================================================================
# Configuration
# ==============================================================================
HETZNER_KEY="${HETZNER_KEY:-$HOME/work/secrets/storagebox.key}"
HETZNER_USER="${HETZNER_USER:-u434410}"
HETZNER_HOST="${HETZNER_HOST:-u434410-sub2.your-storagebox.de}"
CI_CACHE_ROOT="${CI_CACHE_ROOT:-/home/o1labs-generic/pvc-4d294645-6466-4260-b933-1b909ff9c3a1}"
LOCAL_STORAGEBOX="${CACHE_BASE_URL:-/var/storagebox}"

# ==============================================================================
# Defaults
# ==============================================================================
JOB_NAME=""
DRY_RUN=false
SKIP_DUMP=false
SKIP_SYNC=false
STEP_FILTER=""
START_FROM=""
JOBS_DIR=""
ENV_FILE=""
BUILD_ID=""
LIST_JOBS=false
LIST_STEPS=false

# Populated by load_env_file, used by patch_docker_command
USER_ENV_DOCKER_FLAGS=""
USER_ENV_VARS=()

# ==============================================================================
# Logging & Display
# ==============================================================================
log()  { echo -e "\033[1;34m=== $* ===\033[0m"; }
warn() { echo -e "\033[1;33mWARN: $*\033[0m"; }
err()  { echo -e "\033[1;31mERROR: $*\033[0m" >&2; }

# Draw a colored box with arbitrary lines of text.
# Usage: draw_box <ansi_color_code> <line1> [<line2> ...]
draw_box() {
  local color="$1"; shift
  echo ""
  echo -e "\033[1;${color}m╔══════════════════════════════════════════════════════════════════════════════╗\033[0m"
  for line in "$@"; do
    echo -e "\033[1;${color}m║  ${line}\033[0m"
  done
  echo -e "\033[1;${color}m╚══════════════════════════════════════════════════════════════════════════════╝\033[0m"
  echo ""
}

step_banner() {
  draw_box 35 "STEP $1: $2" "Started at: $(date '+%H:%M:%S')"
}

substep_banner() {
  echo ""
  echo -e "\033[1;36m┌──────────────────────────────────────────────────────────────────────────────┐\033[0m"
  echo -e "\033[1;36m│  ▶ RUNNING STEP [$1/$2]: $3\033[0m"
  echo -e "\033[1;36m│    Key: $4 | Time: $(date '+%H:%M:%S')\033[0m"
  echo -e "\033[1;36m└──────────────────────────────────────────────────────────────────────────────┘\033[0m"
}

skip_banner() {
  echo -e "\033[1;33m  ⏭  SKIP [$1/$2]: $3 (key: $4)\033[0m"
}

substep_complete() {
  echo ""
  echo -e "\033[1;32m  ✓ COMPLETED [$1/$2]: $3 at $(date '+%H:%M:%S')\033[0m"
}

final_banner() {
  draw_box 32 "✓ JOB COMPLETED: $1" "Finished at: $(date '+%H:%M:%S')"
}

# ==============================================================================
# Utility functions
# ==============================================================================
gen_uuid() {
  if command -v uuidgen &>/dev/null; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  elif [[ -f /proc/sys/kernel/random/uuid ]]; then
    cat /proc/sys/kernel/random/uuid
  else
    od -x /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}'
  fi
}

to_lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Exit with an error if a directory doesn't exist or isn't writable.
# Usage: require_dir_writable <path> <description>
require_dir_writable() {
  local dir="$1" desc="$2"
  if [[ ! -d "$dir" ]]; then
    err "$desc does not exist: $dir"
    err "Create it with:"
    err "  sudo mkdir -p $dir && sudo chown \$(id -u):\$(id -g) $dir"
    exit 1
  fi
  if [[ ! -w "$dir" ]]; then
    err "$desc is not writable: $dir"
    err "Fix with:"
    err "  sudo chown \$(id -u):\$(id -g) $dir"
    exit 1
  fi
}

# Print job names from pipeline YAML files in a directory.
# Usage: list_jobs <jobs_dir>
list_jobs() {
  local jobs_dir="$1"
  for file in "$jobs_dir"/*.yml; do
    local name
    name=$(yq -r '.spec.name // ""' "$file" 2>/dev/null)
    if [[ -n "$name" && "$name" != "null" ]]; then
      echo "  $name"
    else
      echo "  $(basename "$file" .yml)"
    fi
  done
}

# Print steps from a job YAML file.
# Usage: list_steps <job_file> <step_count>
list_steps() {
  local job_file="$1" step_count="$2"
  for i in $(seq 0 $((step_count - 1))); do
    local key label
    key=$(yq -r ".pipeline.steps[$i].key // \"step-$i\"" "$job_file")
    label=$(yq -r ".pipeline.steps[$i].label // \"Step $i\"" "$job_file")
    printf "  %2d. %-30s  (key: %s)\n" "$((i+1))" "$label" "$key"
  done
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] <job-name>

Run a Buildkite job locally by name.

Prerequisites:
  The following directories must exist and be writable by the current user.
  This is required because the script stores build artifacts and shared state
  without using sudo. Run these commands once to set up:

    sudo mkdir -p /var/storagebox && sudo chown \$(id -u):\$(id -g) /var/storagebox
    sudo mkdir -p /var/buildkite/shared && sudo chown \$(id -u):\$(id -g) /var/buildkite/shared

Options:
  --dry-run          Print commands without executing
  --skip-dump        Skip pipeline generation (reuse --jobs-dir)
  --skip-sync        Skip legacy folder sync from hetzner
  --jobs-dir DIR     Path to pre-generated pipeline YAMLs
  --step KEY         Run only the step matching this key (substring match)
  --start-from KEY   Start execution from this step (skip all previous steps)
  --build-id ID      Reuse a specific BUILDKITE_BUILD_ID (for resuming/debugging)
  --env-file FILE    File with KEY=VALUE pairs passed to all commands (including Docker)
  --list             List available job names and exit
  --list-steps       List steps in the job and exit (requires job name)
  -h, --help         Show this help

Examples:
  $(basename "$0") --list
  $(basename "$0") --list --jobs-dir /tmp/pipelines       # List jobs without regenerating
  $(basename "$0") --list-steps MyJob                     # List steps (generates pipelines)
  $(basename "$0") --list-steps --jobs-dir /tmp/pipelines MyJob  # List steps (reuses pipelines)
  $(basename "$0") --dry-run RosettaDevnetConnect
  $(basename "$0") --env-file ./env.sh RosettaDevnetConnect
  $(basename "$0") --skip-dump --jobs-dir /tmp/pipelines --step "build-deb" RosettaDevnetConnect
  $(basename "$0") --start-from "upload-ledger" RosettaDevnetConnect
  $(basename "$0") --build-id abc123-def456 --start-from "step-3" MyJob  # Resume from specific build
EOF
}

# ==============================================================================
# Core workflow functions
# ==============================================================================

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)    DRY_RUN=true; shift;;
      --skip-dump)  SKIP_DUMP=true; shift;;
      --skip-sync)  SKIP_SYNC=true; shift;;
      --jobs-dir)   JOBS_DIR="$2"; shift 2;;
      --step)       STEP_FILTER="$2"; shift 2;;
      --start-from) START_FROM="$2"; shift 2;;
      --build-id)   BUILD_ID="$2"; shift 2;;
      --env-file)   ENV_FILE="$2"; shift 2;;
      --list)       LIST_JOBS=true; shift;;
      --list-steps) LIST_STEPS=true; shift;;
      -h|--help)    usage; exit 0;;
      -*)           err "Unknown option: $1"; usage; exit 1;;
      *)            JOB_NAME="$1"; shift;;
    esac
  done

  if [[ "$LIST_JOBS" == false && -z "$JOB_NAME" ]]; then
    err "Job name is required (or use --list)"
    usage
    exit 1
  fi

  if [[ "$LIST_STEPS" == true && -z "$JOB_NAME" ]]; then
    err "--list-steps requires a job name"
    usage
    exit 1
  fi
}

# Parse --env-file: export variables and collect Docker --env flags.
load_env_file() {
  [[ -z "$ENV_FILE" ]] && return

  if [[ ! -f "$ENV_FILE" ]]; then
    err "Env file not found: $ENV_FILE"
    exit 1
  fi

  echo "Loading env file: $ENV_FILE"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" != *"="* ]] && continue
    local key="${line%%=*}" value="${line#*=}"
    [[ -z "$key" || "$key" =~ [[:space:]] ]] && continue
    export "$key=$value"
    USER_ENV_DOCKER_FLAGS+=" --env $key"
    USER_ENV_VARS+=("$key")
  done < "$ENV_FILE"
  echo "User env vars: ${USER_ENV_VARS[*]:-none}"
}

# Step 1: Source env-file & export all Buildkite environment variables.
setup_environment() {
  step_banner "1/5" "Setting up environment"

  load_env_file

  # --- Git-derived vars ---
  export BUILDKITE_BRANCH="${BUILDKITE_BRANCH:-$(git -C "$MINA_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")}"
  export BUILDKITE_COMMIT="${BUILDKITE_COMMIT:-$(git -C "$MINA_ROOT" rev-parse HEAD 2>/dev/null || echo "unknown")}"
  export BUILDKITE_MESSAGE="${BUILDKITE_MESSAGE:-$(git -C "$MINA_ROOT" log -1 --format=%s 2>/dev/null || echo "Local run")}"
  export BUILDKITE_BUILD_AUTHOR="${BUILDKITE_BUILD_AUTHOR:-$(git -C "$MINA_ROOT" log -1 --format=%an 2>/dev/null || echo "")}"
  export BUILDKITE_BUILD_AUTHOR_EMAIL="${BUILDKITE_BUILD_AUTHOR_EMAIL:-$(git -C "$MINA_ROOT" log -1 --format=%ae 2>/dev/null || echo "")}"
  export BUILDKITE_TAG="${BUILDKITE_TAG:-$(git -C "$MINA_ROOT" tag --points-at HEAD 2>/dev/null | head -1 || echo "")}"
  export BUILDKITE_REPO="${BUILDKITE_REPO:-$(git -C "$MINA_ROOT" remote get-url origin 2>/dev/null || echo "")}"

  # --- Per-run identifiers ---
  if [[ -n "$BUILD_ID" ]]; then
    export BUILDKITE_BUILD_ID="$BUILD_ID"
    echo "Using provided build ID: $BUILD_ID"
  else
    export BUILDKITE_BUILD_ID="${BUILDKITE_BUILD_ID:-$(gen_uuid)}"
  fi
  export BUILDKITE_JOB_ID="${BUILDKITE_JOB_ID:-$(gen_uuid)}"
  export BUILDKITE_AGENT_ID="${BUILDKITE_AGENT_ID:-$(gen_uuid)}"
  export BUILDKITE_BUILD_NUMBER="${BUILDKITE_BUILD_NUMBER:-$(date +%s)}"

  # --- Static CI constants ---
  export BUILDKITE="${BUILDKITE:-true}"
  export CI="${CI:-true}"
  export GIT_LFS_SKIP_SMUDGE=1
  export SKIP_DOCKER_PRUNE=1
  export BUILDKIT_PROGRESS="${BUILDKIT_PROGRESS:-plain}"
  export BUILDKITE_COMMIT_RESOLVED="${BUILDKITE_COMMIT_RESOLVED:-true}"
  export BUILDKITE_ORGANIZATION_SLUG="${BUILDKITE_ORGANIZATION_SLUG:-o-1-labs-2}"
  export BUILDKITE_ORGANIZATION_ID="${BUILDKITE_ORGANIZATION_ID:-7177201d-da06-437c-9246-e2b19acd1456}"
  export BUILDKITE_PIPELINE_PROVIDER="${BUILDKITE_PIPELINE_PROVIDER:-github}"
  export BUILDKITE_PIPELINE_DEFAULT_BRANCH="${BUILDKITE_PIPELINE_DEFAULT_BRANCH:-develop}"
  export BUILDKITE_SOURCE="${BUILDKITE_SOURCE:-local}"
  export BUILDKITE_PULL_REQUEST="${BUILDKITE_PULL_REQUEST:-false}"
  export BUILDKITE_PULL_REQUEST_BASE_BRANCH="${BUILDKITE_PULL_REQUEST_BASE_BRANCH:-}"
  export BUILDKITE_PULL_REQUEST_REPO="${BUILDKITE_PULL_REQUEST_REPO:-}"
  export BUILDKITE_PULL_REQUEST_LABELS="${BUILDKITE_PULL_REQUEST_LABELS:-}"
  export BUILDKITE_REBUILT_FROM_BUILD_ID="${BUILDKITE_REBUILT_FROM_BUILD_ID:-}"
  export BUILDKITE_REBUILT_FROM_BUILD_NUMBER="${BUILDKITE_REBUILT_FROM_BUILD_NUMBER:-}"
  export BUILDKITE_TRIGGERED_FROM_BUILD_ID="${BUILDKITE_TRIGGERED_FROM_BUILD_ID:-}"
  export BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER="${BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER:-}"
  export BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG="${BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG:-}"
  export BUILDKITE_RETRY_COUNT="${BUILDKITE_RETRY_COUNT:-0}"
  export BUILDKITE_COMPUTE_TYPE="${BUILDKITE_COMPUTE_TYPE:-self-hosted}"
  export BUILDKITE_AGENT_META_DATA_QUEUE="${BUILDKITE_AGENT_META_DATA_QUEUE:-default}"
  export BUILDKITE_AGENT_META_DATA_SIZE="${BUILDKITE_AGENT_META_DATA_SIZE:-generic}"
  export BUILDKITE_PROJECT_PROVIDER="${BUILDKITE_PROJECT_PROVIDER:-github}"

  # --- Derived vars ---
  export BUILDKITE_PIPELINE_SLUG="${BUILDKITE_PIPELINE_SLUG:-mina-o-1-labs}"
  export BUILDKITE_PIPELINE_NAME="${BUILDKITE_PIPELINE_NAME:-Mina O(1)Labs}"
  export BUILDKITE_PIPELINE_ID="${BUILDKITE_PIPELINE_ID:-8f4b7485-ef17-469a-bec2-221aef440bff}"
  export BUILDKITE_PROJECT_SLUG="${BUILDKITE_PROJECT_SLUG:-${BUILDKITE_ORGANIZATION_SLUG}/${BUILDKITE_PIPELINE_SLUG}}"
  export BUILDKITE_BUILD_URL="${BUILDKITE_BUILD_URL:-https://buildkite.com/${BUILDKITE_ORGANIZATION_SLUG}/${BUILDKITE_PIPELINE_SLUG}/builds/${BUILDKITE_BUILD_NUMBER}}"
  export BUILDKITE_BUILD_CREATOR="${BUILDKITE_BUILD_CREATOR:-$(git -C "$MINA_ROOT" config user.name 2>/dev/null || echo "local")}"
  export BUILDKITE_BUILD_CREATOR_EMAIL="${BUILDKITE_BUILD_CREATOR_EMAIL:-$(git -C "$MINA_ROOT" config user.email 2>/dev/null || echo "local@localhost")}"
  export BUILDKITE_AGENT_NAME="${BUILDKITE_AGENT_NAME:-$(hostname)}"
  export BUILDKITE_BUILD_CHECKOUT_PATH="${BUILDKITE_BUILD_CHECKOUT_PATH:-$MINA_ROOT}"
  export BUILDKITE_ARTIFACT_PATHS="${BUILDKITE_ARTIFACT_PATHS:-}"
  export BUILDKITE_TIMEOUT="${BUILDKITE_TIMEOUT:-false}"
  export LOCAL_BK_RUN="${LOCAL_BK_RUN:-1}"

  echo "BUILDKITE_BUILD_CHECKOUT_PATH=$BUILDKITE_BUILD_CHECKOUT_PATH"
  echo "BUILDKITE_BUILD_ID=$BUILDKITE_BUILD_ID"
  echo "BUILDKITE_BRANCH=$BUILDKITE_BRANCH"
  echo "BUILDKITE_COMMIT=$BUILDKITE_COMMIT"
}

# Step 2: Generate pipeline YAMLs from Dhall (or reuse existing ones).
generate_pipelines() {
  step_banner "2/5" "Generating pipeline YAMLs"

  # Auto-enable skip-dump when listing with --jobs-dir provided
  if [[ ( "$LIST_JOBS" == true || "$LIST_STEPS" == true ) && -n "$JOBS_DIR" ]]; then
    SKIP_DUMP=true
  fi

  if [[ "$SKIP_DUMP" == true ]]; then
    if [[ -z "$JOBS_DIR" ]]; then
      err "--skip-dump requires --jobs-dir"
      exit 1
    fi
    if [[ ! -d "$JOBS_DIR" ]]; then
      err "Jobs directory not found: $JOBS_DIR"
      exit 1
    fi
    echo "Skipping pipeline dump, using: $JOBS_DIR"
  else
    JOBS_DIR="${JOBS_DIR:-$(mktemp -d)}"
    echo "Dumping pipelines to: $JOBS_DIR"
    # Run from buildkite dir with relative ./src path (matches Makefile invocation)
    # This avoids Dhall parse errors in .dirtywhen generation caused by absolute paths
    (cd "$BUILDKITE_DIR" && ./scripts/dhall/dump_dhall_to_pipelines.sh ./src "$JOBS_DIR")
    echo ""
    echo "Reuse with: --skip-dump --jobs-dir $JOBS_DIR"
  fi
}

# Step 3: Sync the legacy cache folder from Hetzner via rsync.
sync_legacy_cache() {
  step_banner "3/5" "Syncing legacy folder from Hetzner"

  if [[ "$SKIP_SYNC" == true ]]; then
    echo "Skipping legacy sync"
    return
  fi

  if [[ ! -f "$HETZNER_KEY" ]]; then
    err "Hetzner key not found at: $HETZNER_KEY"
    err "Set HETZNER_KEY env var or place the key at ~/work/secrets/storagebox.key"
    exit 1
  fi

  require_dir_writable "$LOCAL_STORAGEBOX" "Local storagebox directory"

  echo "Syncing $HETZNER_USER@$HETZNER_HOST:$CI_CACHE_ROOT/legacy/ -> $LOCAL_STORAGEBOX/legacy/"
  rsync -avz --progress \
    -e "ssh -p 23 -i $HETZNER_KEY -o StrictHostKeyChecking=no" \
    "$HETZNER_USER@$HETZNER_HOST:$CI_CACHE_ROOT/legacy/" \
    "$LOCAL_STORAGEBOX/legacy/"
  echo "Legacy sync complete"
}

# Step 4: Ensure local storagebox and shared directories are usable.
validate_directories() {
  step_banner "4/5" "Validating local directories"

  require_dir_writable "$LOCAL_STORAGEBOX" "Local storagebox directory"

  # Create per-build directory (world-writable so Docker's opam user can write)
  mkdir -p "$LOCAL_STORAGEBOX/$BUILDKITE_BUILD_ID"
  chmod 777 "$LOCAL_STORAGEBOX/$BUILDKITE_BUILD_ID"
  mkdir -p "$LOCAL_STORAGEBOX/legacy"

  require_dir_writable "/var/buildkite/shared" "Shared buildkite state directory"

  # Check ownership of _build if it was created by a previous Docker run as a
  # different UID (e.g. root). Stale ownership causes permission errors inside
  # the container which bind-mounts the workdir.
  if [[ -d "$MINA_ROOT/_build" ]]; then
    local build_owner
    build_owner=$(stat -c '%u' "$MINA_ROOT/_build")
    if [[ "$build_owner" != "$(id -u)" ]]; then
      err "_build directory is owned by UID $build_owner (you are $(id -u))"
      err "Fix with:"
      err "  sudo chown -R \$(id -u):\$(id -g) $MINA_ROOT/_build"
      exit 1
    fi

    # dune-build-root files cache absolute paths. Stale host paths (instead of
    # /workdir) cause cargo to fail inside the container. Remove them so dune
    # regenerates with the correct container paths.
    local stale
    stale=$(find "$MINA_ROOT/_build" -name dune-build-root -exec grep -L '^/workdir' {} + 2>/dev/null || true)
    if [[ -n "$stale" ]]; then
      warn "Removing stale dune-build-root files (contain host paths instead of /workdir)"
      echo "$stale" | xargs rm -f
    fi
  fi
}

# Extract commands from a pipeline step YAML node. Handles both array
# (.commands[]) and scalar (.command / .commands) forms.
# Outputs the joined command string on stdout.
# Usage: extract_step_commands <job_file> <step_index>
extract_step_commands() {
  local job_file="$1" idx="$2"
  yq -r "
    .pipeline.steps[$idx] |
    if .commands and (.commands | type == \"!!seq\") then .commands[]
    elif .command                                    then .command
    elif .commands                                   then .commands
    else \"\"
    end
  " "$job_file" 2>/dev/null || true
}

# Patch a command string for local Docker execution:
#  - Unescape Dhall's \$ → $ so shell variables expand correctly
#  - Inject extra --env flags for local overrides and user env vars
#  - Drop -t flag when no TTY is available
# Outputs patched command on stdout.
# Usage: patch_docker_command <command_string>
patch_docker_command() {
  local cmd="$1"

  cmd=$(printf '%s' "$cmd" | sed 's/\\\$/$/g')

  # Note: We intentionally do NOT use --user flag. The container runs as opam
  # (UID 1000) which typically matches the host user's UID, allowing sudo to
  # work inside the container for apt operations.
  local docker_flags="--env GIT_LFS_SKIP_SMUDGE=1 --env APTLY_ROOT=/tmp/aptly --env LOCAL_BK_RUN=${LOCAL_BK_RUN}${USER_ENV_DOCKER_FLAGS}"
  cmd=$(printf '%s\n' "$cmd" | sed "s|docker run -it|docker run -it ${docker_flags}|g")

  if ! [ -t 0 ]; then
    cmd=$(printf '%s\n' "$cmd" | sed 's|docker run -it |docker run -i |g')
  fi

  printf '%s' "$cmd"
}

# Execute (or dry-run) a single step's command string.
# Usage: execute_step <command> <step_label> <step_key>
execute_step() {
  local full_cmd="$1" step_label="$2" step_key="$3"

  if [[ "$DRY_RUN" == true ]]; then
    echo ""
    echo -e "\033[1;33m--- DRY RUN commands ---\033[0m"
    echo "$full_cmd"
    echo -e "\033[1;33m--- end ---\033[0m"
    return
  fi

  echo ""
  echo -e "\033[1;37m  ⚙ Executing commands...\033[0m"
  echo ""
  # Disable nounset (-u) inside eval: CI commands reference variables
  # (e.g. MINA_DOCKER_TAG) before they are set by later sourced scripts.
  #
  # Capture exit code via || so set -e doesn't kill the whole script
  # before we can print which step failed.
  local rc=0
  (cd "$BUILDKITE_BUILD_CHECKOUT_PATH" && set +u && set -x && eval "$full_cmd") || rc=$?
  if [[ $rc -ne 0 ]]; then
    echo ""
    err "Step '$step_label' (key: $step_key) failed with exit code $rc"
    exit $rc
  fi
}

# Find job YAML file by spec.name (case-insensitive) or filename.
# Sets the global JOB_FILE variable or exits with an error.
find_job_file() {
  JOB_FILE=""
  local job_name_lower
  job_name_lower=$(to_lower "$JOB_NAME")

  for file in "$JOBS_DIR"/*.yml; do
    local name
    name=$(yq -r '.spec.name // ""' "$file" 2>/dev/null)
    if [[ "$(to_lower "$name")" == "$job_name_lower" ]]; then
      JOB_FILE="$file"
      return
    fi
  done

  # Fallback: filename match
  local candidate="$JOBS_DIR/$JOB_NAME.yml"
  if [[ -f "$candidate" ]]; then
    JOB_FILE="$candidate"
    return
  fi

  err "Job '$JOB_NAME' not found in $JOBS_DIR"
  echo ""
  echo "Available jobs:"
  list_jobs "$JOBS_DIR"
  exit 1
}

# Step 5: Locate the job, iterate its steps, and execute them.
run_job() {
  if [[ "$LIST_STEPS" == true ]]; then
    step_banner "5/5" "Listing steps for '$JOB_NAME'"
  else
    step_banner "5/5" "Running job '$JOB_NAME'"
  fi

  if ! command -v yq &>/dev/null; then
    err "yq is required but not installed."
    err "Install from: https://github.com/mikefarah/yq"
    exit 1
  fi

  find_job_file
  echo "Found job: $JOB_FILE"
  echo ""

  local step_count
  step_count=$(yq '.pipeline.steps | length' "$JOB_FILE")

  if [[ "$LIST_STEPS" == true ]]; then
    echo ""
    log "Steps in job '$JOB_NAME' ($step_count total)"
    echo ""
    list_steps "$JOB_FILE" "$step_count"
    echo ""
    echo "Use --start-from <key> to start from a specific step"
    echo "Use --step <key> to run only steps matching the key"
    exit 0
  fi

  echo "Job has $step_count step(s)"

  local started=false
  [[ -z "$START_FROM" ]] && started=true

  for i in $(seq 0 $((step_count - 1))); do
    local step_key step_label
    step_key=$(yq -r ".pipeline.steps[$i].key // \"step-$i\"" "$JOB_FILE")
    step_label=$(yq -r ".pipeline.steps[$i].label // \"Step $i\"" "$JOB_FILE")

    # Handle --start-from filtering
    if [[ "$started" == false ]]; then
      if [[ "$step_key" == *"$START_FROM"* ]]; then
        started=true
        echo ""
        echo -e "\033[1;32m  ▶ Starting from step: $step_key\033[0m"
      else
        echo -e "\033[1;90m  ⏭  SKIP [$((i+1))/$step_count]: $step_label (before start-from)\033[0m"
        continue
      fi
    fi

    # Handle --step filtering
    if [[ -n "$STEP_FILTER" && "$step_key" != *"$STEP_FILTER"* ]]; then
      skip_banner "$((i+1))" "$step_count" "$step_label" "$step_key"
      continue
    fi

    substep_banner "$((i+1))" "$step_count" "$step_label" "$step_key"

    # Per-step environment
    export BUILDKITE_LABEL="$step_label"
    export BUILDKITE_STEP_KEY="$step_key"
    BUILDKITE_STEP_ID="$(gen_uuid)"; export BUILDKITE_STEP_ID
    export BUILDKITE_STEP_IDENTIFIER="$step_key"
    BUILDKITE_TIMEOUT=$(yq -r ".pipeline.steps[$i].timeout_in_minutes // \"false\"" "$JOB_FILE"); export BUILDKITE_TIMEOUT
    BUILDKITE_ARTIFACT_PATHS=$(yq -r ".pipeline.steps[$i].artifact_paths // \"\"" "$JOB_FILE"); export BUILDKITE_ARTIFACT_PATHS

    # Extract and patch commands
    local full_cmd
    full_cmd=$(extract_step_commands "$JOB_FILE" "$i")
    if [[ -z "$full_cmd" || "$full_cmd" == "null" ]]; then
      warn "No commands found for step $step_key, skipping"
      continue
    fi

    full_cmd=$(patch_docker_command "$full_cmd")
    export BUILDKITE_COMMAND="$full_cmd"
    export BUILDKITE_SCRIPT_PATH="$full_cmd"

    execute_step "$full_cmd" "$step_label" "$step_key"
    [[ "$DRY_RUN" == false ]] && substep_complete "$((i+1))" "$step_count" "$step_label"
  done

  # Warn if --start-from never matched any step
  if [[ -n "$START_FROM" && "$started" == false ]]; then
    err "Step matching '$START_FROM' was not found in job '$JOB_NAME'"
    echo ""
    echo "Available steps:"
    list_steps "$JOB_FILE" "$step_count"
    exit 1
  fi

  final_banner "$JOB_NAME"
}

# ==============================================================================
# Main
# ==============================================================================
parse_args "$@"
setup_environment
generate_pipelines

if [[ "$LIST_JOBS" == true ]]; then
  echo ""
  log "Available jobs"
  list_jobs "$JOBS_DIR"
  exit 0
fi

if [[ "$LIST_STEPS" != true ]]; then
  sync_legacy_cache
  validate_directories
fi

run_job
