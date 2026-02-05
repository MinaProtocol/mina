#!/usr/bin/env bash

# Run a Buildkite job locally by name.
#
# This script sets up the full environment (mimicking what the Buildkite agent does),
# generates pipeline YAMLs from Dhall, ensures buildkite-agent is installed,
# syncs the legacy cache from Hetzner, and runs the specified job's commands.
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
# Hetzner / Cache config
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

# ==============================================================================
# Helpers
# ==============================================================================
log()  { echo -e "\033[1;34m=== $* ===\033[0m"; }
warn() { echo -e "\033[1;33mWARN: $*\033[0m"; }
err()  { echo -e "\033[1;31mERROR: $*\033[0m" >&2; }

# Step banner - more prominent visual separator for major steps
step_banner() {
  local step_num="$1"
  local step_title="$2"
  local timestamp
  timestamp=$(date '+%H:%M:%S')
  echo ""
  echo -e "\033[1;35m╔══════════════════════════════════════════════════════════════════════════════╗\033[0m"
  echo -e "\033[1;35m║  STEP $step_num: $step_title\033[0m"
  echo -e "\033[1;35m║  Started at: $timestamp\033[0m"
  echo -e "\033[1;35m╚══════════════════════════════════════════════════════════════════════════════╝\033[0m"
  echo ""
}

# Sub-step banner for pipeline steps within Step 5
substep_banner() {
  local index="$1"
  local total="$2"
  local label="$3"
  local key="$4"
  local timestamp
  timestamp=$(date '+%H:%M:%S')
  echo ""
  echo -e "\033[1;36m┌──────────────────────────────────────────────────────────────────────────────┐\033[0m"
  echo -e "\033[1;36m│  ▶ RUNNING STEP [$index/$total]: $label\033[0m"
  echo -e "\033[1;36m│    Key: $key\033[0m"
  echo -e "\033[1;36m│    Time: $timestamp\033[0m"
  echo -e "\033[1;36m└──────────────────────────────────────────────────────────────────────────────┘\033[0m"
}

# Skip banner for filtered steps
skip_banner() {
  local index="$1"
  local total="$2"
  local label="$3"
  local key="$4"
  echo -e "\033[1;33m  ⏭  SKIP [$index/$total]: $label (key: $key)\033[0m"
}

# Success indicator after substep completes
substep_complete() {
  local index="$1"
  local total="$2"
  local label="$3"
  local timestamp
  timestamp=$(date '+%H:%M:%S')
  echo ""
  echo -e "\033[1;32m  ✓ COMPLETED [$index/$total]: $label at $timestamp\033[0m"
}

# Final completion banner
final_banner() {
  local job_name="$1"
  local timestamp
  timestamp=$(date '+%H:%M:%S')
  echo ""
  echo -e "\033[1;32m╔══════════════════════════════════════════════════════════════════════════════╗\033[0m"
  echo -e "\033[1;32m║  ✓ JOB COMPLETED: $job_name\033[0m"
  echo -e "\033[1;32m║  Finished at: $timestamp\033[0m"
  echo -e "\033[1;32m╚══════════════════════════════════════════════════════════════════════════════╝\033[0m"
}

gen_uuid() {
  if command -v uuidgen &>/dev/null; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  elif [[ -f /proc/sys/kernel/random/uuid ]]; then
    cat /proc/sys/kernel/random/uuid
  else
    # fallback: pseudo-random hex
    od -x /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}'
  fi
}

to_lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

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
# Parse arguments
# ==============================================================================
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

# ==============================================================================
# Step 1: Source env-file & compute environment
# ==============================================================================
step_banner "1/5" "Setting up environment"

# Parse user-provided env file. Variables are:
#  - Exported to the shell environment (for non-Docker commands)
#  - Collected into USER_ENV_DOCKER_FLAGS (for Docker --env flags)
USER_ENV_DOCKER_FLAGS=""
USER_ENV_VARS=()

if [[ -n "$ENV_FILE" ]]; then
  if [[ -f "$ENV_FILE" ]]; then
    echo "Loading env file: $ENV_FILE"
    while IFS= read -r line || [[ -n "$line" ]]; do
      # Skip empty lines and comments
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      # Skip lines without =
      [[ "$line" != *"="* ]] && continue
      # Extract key (everything before first =) and value (everything after)
      key="${line%%=*}"
      value="${line#*=}"
      # Skip if key is empty or contains spaces
      [[ -z "$key" || "$key" =~ [[:space:]] ]] && continue
      # Export the variable
      export "$key=$value"
      # Add to Docker flags
      USER_ENV_DOCKER_FLAGS+=" --env $key"
      USER_ENV_VARS+=("$key")
    done < "$ENV_FILE"
    echo "User env vars: ${USER_ENV_VARS[*]:-none}"
  else
    err "Env file not found: $ENV_FILE"
    exit 1
  fi
fi

# --- Git-derived vars (Category 1) ---
export BUILDKITE_BRANCH="${BUILDKITE_BRANCH:-$(git -C "$MINA_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")}"
export BUILDKITE_COMMIT="${BUILDKITE_COMMIT:-$(git -C "$MINA_ROOT" rev-parse HEAD 2>/dev/null || echo "unknown")}"
export BUILDKITE_MESSAGE="${BUILDKITE_MESSAGE:-$(git -C "$MINA_ROOT" log -1 --format=%s 2>/dev/null || echo "Local run")}"
export BUILDKITE_BUILD_AUTHOR="${BUILDKITE_BUILD_AUTHOR:-$(git -C "$MINA_ROOT" log -1 --format=%an 2>/dev/null || echo "")}"
export BUILDKITE_BUILD_AUTHOR_EMAIL="${BUILDKITE_BUILD_AUTHOR_EMAIL:-$(git -C "$MINA_ROOT" log -1 --format=%ae 2>/dev/null || echo "")}"
export BUILDKITE_TAG="${BUILDKITE_TAG:-$(git -C "$MINA_ROOT" tag --points-at HEAD 2>/dev/null | head -1 || echo "")}"
export BUILDKITE_REPO="${BUILDKITE_REPO:-$(git -C "$MINA_ROOT" remote get-url origin 2>/dev/null || echo "")}"

# --- Generated per-run vars (Category 2) ---
# Use --build-id if provided, otherwise generate a new UUID
if [[ -n "$BUILD_ID" ]]; then
  export BUILDKITE_BUILD_ID="$BUILD_ID"
  echo "Using provided build ID: $BUILD_ID"
else
  export BUILDKITE_BUILD_ID="${BUILDKITE_BUILD_ID:-$(gen_uuid)}"
fi
export BUILDKITE_JOB_ID="${BUILDKITE_JOB_ID:-$(gen_uuid)}"
export BUILDKITE_AGENT_ID="${BUILDKITE_AGENT_ID:-$(gen_uuid)}"
export BUILDKITE_BUILD_NUMBER="${BUILDKITE_BUILD_NUMBER:-$(date +%s)}"

# --- Static constants (Category 4) ---
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

# --- Derived vars (Category 5) ---
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

# Local overrides for testing
export LOCAL_BK_RUN="${LOCAL_BK_RUN:-1}"


echo "BUILDKITE_BUILD_CHECKOUT_PATH=$BUILDKITE_BUILD_CHECKOUT_PATH"
echo "BUILDKITE_BUILD_ID=$BUILDKITE_BUILD_ID"
echo "BUILDKITE_BRANCH=$BUILDKITE_BRANCH"
echo "BUILDKITE_COMMIT=$BUILDKITE_COMMIT"

# ==============================================================================
# Step 2: Generate pipeline YAMLs
# ==============================================================================
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

# ==============================================================================
# --list mode: print available jobs and exit
# ==============================================================================
if [[ "$LIST_JOBS" == true ]]; then
  echo ""
  log "Available jobs"
  for file in "$JOBS_DIR"/*.yml; do
    name=$(yq -r '.spec.name // ""' "$file" 2>/dev/null)
    if [[ -n "$name" && "$name" != "null" ]]; then
      echo "  $name"
    else
      basename "$file" .yml
    fi
  done
  exit 0
fi

# ==============================================================================
# Step 3: Sync legacy folder from hetzner
# ==============================================================================
# Skip sync and directory validation when just listing steps
if [[ "$LIST_STEPS" == true ]]; then
  echo "Skipping steps 3-4 (listing mode)"
else

step_banner "3/5" "Syncing legacy folder from Hetzner"

if [[ "$SKIP_SYNC" == true ]]; then
  echo "Skipping legacy sync"
else
  if [[ ! -f "$HETZNER_KEY" ]]; then
    err "Hetzner key not found at: $HETZNER_KEY"
    err "Set HETZNER_KEY env var or place the key at ~/work/secrets/storagebox.key"
    exit 1
  fi

  # Ensure LOCAL_STORAGEBOX is writable.
  # This directory mirrors the CI cache storage and receives rsync'd artifacts
  # from Hetzner. The script creates per-build subdirectories and writes build
  # outputs here, so it must be writable by the current user.
  if [[ ! -d "$LOCAL_STORAGEBOX" ]]; then
    err "Local storagebox directory does not exist: $LOCAL_STORAGEBOX"
    err ""
    err "This directory is used to cache build artifacts locally (mirroring CI cache)."
    err "Create it with:"
    err "  sudo mkdir -p $LOCAL_STORAGEBOX && sudo chown \$(id -u):\$(id -g) $LOCAL_STORAGEBOX"
    exit 1
  fi
  if [[ ! -w "$LOCAL_STORAGEBOX" ]]; then
    err "Local storagebox directory is not writable: $LOCAL_STORAGEBOX"
    err ""
    err "This directory is used to cache build artifacts locally (mirroring CI cache)."
    err "Fix with:"
    err "  sudo chown \$(id -u):\$(id -g) $LOCAL_STORAGEBOX"
    exit 1
  fi

  echo "Syncing $HETZNER_USER@$HETZNER_HOST:$CI_CACHE_ROOT/legacy/ -> $LOCAL_STORAGEBOX/legacy/"
  rsync -avz --progress \
    -e "ssh -p 23 -i $HETZNER_KEY -o StrictHostKeyChecking=no" \
    "$HETZNER_USER@$HETZNER_HOST:$CI_CACHE_ROOT/legacy/" \
    "$LOCAL_STORAGEBOX/legacy/"
  echo "Legacy sync complete"
fi

# ==============================================================================
# Step 4: Ensure local storagebox directories are usable
# ==============================================================================
step_banner "4/5" "Validating local directories"

# The cache manager (scripts/cache/manager.sh) writes build artifacts into
# $LOCAL_STORAGEBOX/$BUILDKITE_BUILD_ID/.  The base directory must be writable.

# Check LOCAL_STORAGEBOX is writable (may have been checked above, but needed if --skip-sync).
# The cache manager (scripts/cache/manager.sh) writes build artifacts into
# $LOCAL_STORAGEBOX/$BUILDKITE_BUILD_ID/ and expects subdirectories for legacy
# cache entries. Without write access, builds will fail when trying to store
# or retrieve cached artifacts.
if [[ ! -d "$LOCAL_STORAGEBOX" ]]; then
  err "Local storagebox directory does not exist: $LOCAL_STORAGEBOX"
  err ""
  err "This directory stores build artifacts and cached dependencies."
  err "Create it with:"
  err "  sudo mkdir -p $LOCAL_STORAGEBOX && sudo chown \$(id -u):\$(id -g) $LOCAL_STORAGEBOX"
  exit 1
fi
if [[ ! -w "$LOCAL_STORAGEBOX" ]]; then
  err "Local storagebox directory is not writable: $LOCAL_STORAGEBOX"
  err ""
  err "This directory stores build artifacts and cached dependencies."
  err "Fix with:"
  err "  sudo chown \$(id -u):\$(id -g) $LOCAL_STORAGEBOX"
  exit 1
fi

# Create build directories with world-writable permissions so Docker container
# (running as opam user) can create subdirectories like debians/noble/
mkdir -p "$LOCAL_STORAGEBOX/$BUILDKITE_BUILD_ID"
chmod 777 "$LOCAL_STORAGEBOX/$BUILDKITE_BUILD_ID"
mkdir -p "$LOCAL_STORAGEBOX/legacy"

# Check /var/buildkite/shared is writable.
# This directory is used by buildkite scripts for shared state between steps,
# including lock files and inter-step communication. Build steps expect to
# read and write files here during execution.
if [[ ! -d /var/buildkite/shared ]]; then
  err "Directory /var/buildkite/shared does not exist"
  err ""
  err "This directory is used for shared state between build steps (locks, temp files)."
  err "Create it with:"
  err "  sudo mkdir -p /var/buildkite/shared && sudo chown \$(id -u):\$(id -g) /var/buildkite/shared"
  exit 1
fi
if [[ ! -w /var/buildkite/shared ]]; then
  err "Directory /var/buildkite/shared is not writable"
  err ""
  err "This directory is used for shared state between build steps (locks, temp files)."
  err "Fix with:"
  err "  sudo chown \$(id -u):\$(id -g) /var/buildkite/shared"
  exit 1
fi

# Check ownership of _build if it was created by a previous Docker run as a
# different UID (e.g. root).  The container bind-mounts the workdir and the
# --user flag maps to the host UID, so stale ownership causes permission errors.
if [[ -d "$MINA_ROOT/_build" ]]; then
  BUILD_OWNER=$(stat -c '%u' "$MINA_ROOT/_build")
  if [[ "$BUILD_OWNER" != "$(id -u)" ]]; then
    err "_build directory is owned by UID $BUILD_OWNER (you are $(id -u))"
    err ""
    err "The _build directory contains compiled artifacts and is bind-mounted into"
    err "Docker containers. When owned by a different user, the container cannot"
    err "write build outputs, causing compilation failures."
    err ""
    err "Fix with:"
    err "  sudo chown -R \$(id -u):\$(id -g) $MINA_ROOT/_build"
    exit 1
  fi

  # dune-build-root files cache absolute paths (via realpath).  A host build
  # writes host paths; a container build writes /workdir paths.  Stale paths
  # from a host build cause cargo to fail inside the container.  Remove them
  # so dune regenerates with the correct container paths.
  stale=$(find "$MINA_ROOT/_build" -name dune-build-root -exec grep -L '^/workdir' {} +  2>/dev/null || true)
  if [[ -n "$stale" ]]; then
    warn "Removing stale dune-build-root files (contain host paths instead of /workdir)"
    echo "$stale" | xargs rm -f
  fi
fi

fi  # end of LIST_STEPS skip block

# ==============================================================================
# Step 5: Find and run the job
# ==============================================================================
if [[ "$LIST_STEPS" == true ]]; then
  step_banner "5/5" "Listing steps for '$JOB_NAME'"
else
  step_banner "5/5" "Running job '$JOB_NAME'"
fi

# Ensure yq is available
if ! command -v yq &>/dev/null; then
  err "yq is required but not installed."
  err "Install from: https://github.com/mikefarah/yq"
  exit 1
fi

# Find job YAML by spec.name (case-insensitive) or filename
JOB_FILE=""
job_name_lower=$(to_lower "$JOB_NAME")

for file in "$JOBS_DIR"/*.yml; do
  name=$(yq -r '.spec.name // ""' "$file" 2>/dev/null)
  if [[ "$(to_lower "$name")" == "$job_name_lower" ]]; then
    JOB_FILE="$file"
    break
  fi
done

# Fallback: filename match
if [[ -z "$JOB_FILE" ]]; then
  candidate="$JOBS_DIR/$JOB_NAME.yml"
  if [[ -f "$candidate" ]]; then
    JOB_FILE="$candidate"
  fi
fi

if [[ -z "$JOB_FILE" ]]; then
  err "Job '$JOB_NAME' not found in $JOBS_DIR"
  echo ""
  echo "Available jobs:"
  for file in "$JOBS_DIR"/*.yml; do
    name=$(yq -r '.spec.name // ""' "$file" 2>/dev/null)
    [[ -n "$name" && "$name" != "null" ]] && echo "  - $name"
  done
  exit 1
fi

echo "Found job: $JOB_FILE"
echo ""

# Extract and execute steps
STEP_COUNT=$(yq '.pipeline.steps | length' "$JOB_FILE")

# --list-steps mode: print steps in the job and exit
if [[ "$LIST_STEPS" == true ]]; then
  echo ""
  log "Steps in job '$JOB_NAME' ($STEP_COUNT total)"
  echo ""
  for i in $(seq 0 $((STEP_COUNT - 1))); do
    step_key=$(yq -r ".pipeline.steps[$i].key // \"step-$i\"" "$JOB_FILE")
    step_label=$(yq -r ".pipeline.steps[$i].label // \"Step $i\"" "$JOB_FILE")
    printf "  %2d. %-30s  (key: %s)\n" "$((i+1))" "$step_label" "$step_key"
  done
  echo ""
  echo "Use --start-from <key> to start from a specific step"
  echo "Use --step <key> to run only steps matching the key"
  exit 0
fi

echo "Job has $STEP_COUNT step(s)"

# Track whether we've reached the starting step (for --start-from)
STARTED=false
if [[ -z "$START_FROM" ]]; then
  STARTED=true
fi

for i in $(seq 0 $((STEP_COUNT - 1))); do
  STEP_KEY=$(yq -r ".pipeline.steps[$i].key // \"step-$i\"" "$JOB_FILE")
  STEP_LABEL=$(yq -r ".pipeline.steps[$i].label // \"Step $i\"" "$JOB_FILE")

  # Check if we've reached the start-from step
  if [[ "$STARTED" == false ]]; then
    if [[ "$STEP_KEY" == *"$START_FROM"* ]]; then
      STARTED=true
      echo ""
      echo -e "\033[1;32m  ▶ Starting from step: $STEP_KEY\033[0m"
    else
      echo -e "\033[1;90m  ⏭  SKIP [$((i+1))/$STEP_COUNT]: $STEP_LABEL (before start-from)\033[0m"
      continue
    fi
  fi

  # Apply step filter if set
  if [[ -n "$STEP_FILTER" && "$STEP_KEY" != *"$STEP_FILTER"* ]]; then
    skip_banner "$((i+1))" "$STEP_COUNT" "$STEP_LABEL" "$STEP_KEY"
    continue
  fi

  substep_banner "$((i+1))" "$STEP_COUNT" "$STEP_LABEL" "$STEP_KEY"

  # Set step-specific env vars (Category 3)
  export BUILDKITE_LABEL="$STEP_LABEL"
  export BUILDKITE_STEP_KEY="$STEP_KEY"
  BUILDKITE_STEP_ID="$(gen_uuid)"
  export BUILDKITE_STEP_ID
  export BUILDKITE_STEP_IDENTIFIER="$STEP_KEY"
  BUILDKITE_TIMEOUT=$(yq -r ".pipeline.steps[$i].timeout_in_minutes // \"false\"" "$JOB_FILE")
  export BUILDKITE_TIMEOUT
  BUILDKITE_ARTIFACT_PATHS=$(yq -r ".pipeline.steps[$i].artifact_paths // \"\"" "$JOB_FILE")
  export BUILDKITE_ARTIFACT_PATHS

  # Extract commands - handle both array (commands) and string (command)
  COMMANDS_TYPE=$(yq -r ".pipeline.steps[$i].commands | type" "$JOB_FILE" 2>/dev/null || echo "")

  FULL_CMD=""
  if [[ "$COMMANDS_TYPE" == "!!seq" ]]; then
    CMD_COUNT=$(yq ".pipeline.steps[$i].commands | length" "$JOB_FILE")
    for j in $(seq 0 $((CMD_COUNT - 1))); do
      line=$(yq -r ".pipeline.steps[$i].commands[$j]" "$JOB_FILE")
      if [[ -n "$FULL_CMD" ]]; then
        FULL_CMD+=$'\n'
      fi
      FULL_CMD+="$line"
    done
  else
    # Try single command field
    FULL_CMD=$(yq -r ".pipeline.steps[$i].command // \"\"" "$JOB_FILE" 2>/dev/null || echo "")
    if [[ -z "$FULL_CMD" || "$FULL_CMD" == "null" ]]; then
      FULL_CMD=$(yq -r ".pipeline.steps[$i].commands // \"\"" "$JOB_FILE" 2>/dev/null || echo "")
    fi
  fi

  if [[ -z "$FULL_CMD" || "$FULL_CMD" == "null" ]]; then
    warn "No commands found for step $STEP_KEY, skipping"
    continue
  fi

  # Dhall escapes $ as \$ (to avoid string interpolation). The YAML preserves
  # the backslash, but at execution time we need plain $ so the shell expands
  # variables like $BUILDKITE_BUILD_CHECKOUT_PATH in docker volume mounts.
  FULL_CMD=$(printf '%s' "$FULL_CMD" | sed 's/\\\$/$/g')

  # Patch docker commands for local execution:
  #  - GIT_LFS_SKIP_SMUDGE: not in the Dhall --env list, lfs ops fail without it
  #  - APTLY_ROOT: redirect aptly database to writable /tmp/aptly
  #  - USER_ENV_DOCKER_FLAGS: custom user variables from --env-file
  #
  # Note: We intentionally do NOT use --user flag. The container runs as opam (UID 1000)
  # which typically matches the host user's UID. This allows sudo to work inside the
  # container for apt operations. If your host UID differs from 1000, you may see
  # permission issues with _build directory (the script checks for this at startup).
  DOCKER_EXTRA_FLAGS="--env GIT_LFS_SKIP_SMUDGE=1 --env APTLY_ROOT=/tmp/aptly --env LOCAL_BK_RUN=${LOCAL_BK_RUN}${USER_ENV_DOCKER_FLAGS}"
  FULL_CMD=$(printf '%s\n' "$FULL_CMD" | sed "s|docker run -it|docker run -it ${DOCKER_EXTRA_FLAGS}|g")

  # Replace "docker run -it" with "docker run -i" when no TTY is available.
  # The -t flag allocates a pseudo-TTY which fails in non-interactive contexts.
  if ! [ -t 0 ]; then
    FULL_CMD=$(printf '%s\n' "$FULL_CMD" | sed 's|docker run -it |docker run -i |g')
  fi

  export BUILDKITE_COMMAND="$FULL_CMD"
  export BUILDKITE_SCRIPT_PATH="$FULL_CMD"

  if [[ "$DRY_RUN" == true ]]; then
    echo ""
    echo -e "\033[1;33m--- DRY RUN commands ---\033[0m"
    echo "$FULL_CMD"
    echo -e "\033[1;33m--- end ---\033[0m"
  else
    echo ""
    echo -e "\033[1;37m  ⚙ Executing commands...\033[0m"
    echo ""
    # Disable nounset (-u) inside eval.  CI commands reference variables
    # (e.g. MINA_DOCKER_TAG) in echo lines before they are set by later
    # sourced scripts; CI doesn't use `set -u` so this is expected.
    #
    # Capture exit code via `|| rc=$?` so that the parent's `set -e`
    # does not terminate the entire script when a step fails.  Without
    # this, any non-zero return/exit from a sourced script or command
    # inside the eval'd FULL_CMD propagates through the subshell and
    # immediately kills the whole pipeline — no error message, no
    # cleanup, and remaining steps never execute.
    rc=0
    (cd "$BUILDKITE_BUILD_CHECKOUT_PATH" && set +u && set -x && eval "$FULL_CMD") || rc=$?
    if [[ $rc -ne 0 ]]; then
      echo ""
      err "Step '$STEP_LABEL' (key: $STEP_KEY) failed with exit code $rc"
      exit $rc
    fi
    substep_complete "$((i+1))" "$STEP_COUNT" "$STEP_LABEL"
  fi
done

# Warn if --start-from was specified but never matched
if [[ -n "$START_FROM" && "$STARTED" == false ]]; then
  err "Step matching '$START_FROM' was not found in job '$JOB_NAME'"
  echo ""
  echo "Available steps:"
  for i in $(seq 0 $((STEP_COUNT - 1))); do
    step_key=$(yq -r ".pipeline.steps[$i].key // \"step-$i\"" "$JOB_FILE")
    step_label=$(yq -r ".pipeline.steps[$i].label // \"Step $i\"" "$JOB_FILE")
    printf "  %2d. %-30s  (key: %s)\n" "$((i+1))" "$step_label" "$step_key"
  done
  exit 1
fi

final_banner "$JOB_NAME"
