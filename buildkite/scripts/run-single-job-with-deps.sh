#!/usr/bin/env bash

# Run a single Buildkite job plus its dependency chain. This script handles !ci-single-me {job}
# You can use it to run a specific job and all its prerequisites in the correct order.
# IMPORTANT: This script assumes that the job pipelines have already been generated
# (e.g. via dhall) and are available in the specified --jobs directory.
# In order to get job name visit dhall file in buildkite/src/Jobs and look for spec.name field.
# Flow:
# - Reads generated job pipeline YAMLs in --jobs.
# - Resolves the requested job by name (case-insensitive).
# - Walks step dependencies to find prerequisite jobs (shared with monorepo triage).
# - Orders jobs topologically and uploads each pipeline.

set -euo pipefail

# Get the directory of this script and source the shared dependency-resolution
# helpers (build_step_index, job_dependency_files) so the walk logic lives in one
# place and stays consistent with the monorepo triage.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/monorepo_lib.sh
source "$SCRIPT_DIR/monorepo_lib.sh"

show_help() {
  cat << EOF
Usage: $(basename "$0") --job-name NAME --jobs DIR [--debug] [--dry-run]

Options:
  --job-name        STRING  Name of the job to run
  --jobs            PATH    Path to generated job pipelines (e.g. buildkite/src/gen)
  --debug                   Enable debug output
  --dry-run                 Print jobs to run without uploading
  -h, --help                Show this help message
EOF
}

JOB_NAME=""
JOBS_DIR=""
DEBUG=false
DRY_RUN=false

# Parse CLI args.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --job-name)
      JOB_NAME="$2"; shift 2;;
    --jobs)
      JOBS_DIR="$2"; shift 2;;
    --debug)
      DEBUG=true; shift;;
    --dry-run)
      DRY_RUN=true; shift;;
    -h|--help)
      show_help; exit 0;;
    *)
      echo "Unknown option: $1" >&2
      show_help; exit 1;;
  esac
done

# Basic input validation.
if [[ -z "$JOB_NAME" || -z "$JOBS_DIR" ]]; then
  echo "Error: --job-name and --jobs are required." >&2
  show_help
  exit 1
fi

if [[ ! -d "$JOBS_DIR" ]]; then
  echo "Error: jobs directory not found: $JOBS_DIR" >&2
  exit 1
fi

# Optional debug logging.
if [[ "$DEBUG" == true ]]; then
  echo "Debug: JOB_NAME=$JOB_NAME"
  echo "Debug: JOBS_DIR=$JOBS_DIR"
  echo "Debug: DRY_RUN=$DRY_RUN"
fi

# Lowercase helper for case-insensitive comparisons
to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

# Ensure yq is available for YAML parsing.
# Check if yq is installed, if not install it
if ! command -v yq &> /dev/null; then
  echo "yq not found, installing..."
  if command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y wget
    sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
    sudo chmod +x /usr/local/bin/yq
  else
    echo "Error: yq is not installed and automatic installation is not supported on this system. Please install yq manually."
    exit 1
  fi
fi

mapfile -t job_files < <(find "$JOBS_DIR" -type f -name "*.yml" | sort)

if [[ ${#job_files[@]} -eq 0 ]]; then
  echo "Error: no job pipeline files found in $JOBS_DIR" >&2
  exit 1
fi

# Index job files by name (for resolving the requested job) and build the shared
# step-key -> file index used by job_dependency_files.
declare -A file_by_name_key
declare -A display_by_name_key

for file in "${job_files[@]}"; do
  job_name=$(yq -r '.spec.name' "$file")
  if [[ -z "$job_name" || "$job_name" == "null" ]]; then
    job_name=$(basename "$file")
    job_name="${job_name%.yml}"
  fi

  name_key=$(to_lower "$job_name")
  if [[ -n "${file_by_name_key[$name_key]-}" && "${display_by_name_key[$name_key]}" != "$job_name" ]]; then
    echo "Error: job name collision (case-insensitive): '${display_by_name_key[$name_key]}' and '$job_name'." >&2
    exit 1
  fi
  file_by_name_key["$name_key"]="$file"
  display_by_name_key["$name_key"]="$job_name"
done

build_step_index "$JOBS_DIR"

# Resolve the requested job name to a file.
name_key=$(to_lower "$JOB_NAME")
if [[ -z "${file_by_name_key[$name_key]-}" ]]; then
  candidate="$JOBS_DIR/$JOB_NAME.yml"
  if [[ -f "$candidate" ]]; then
    resolved_name=$(yq -r '.spec.name' "$candidate")
    if [[ -z "$resolved_name" || "$resolved_name" == "null" ]]; then
      resolved_name=$(basename "$candidate")
      resolved_name="${resolved_name%.yml}"
    fi
    name_key=$(to_lower "$resolved_name")
    JOB_NAME="$resolved_name"
  fi
fi

if [[ -z "${file_by_name_key[$name_key]-}" ]]; then
  echo "Error: job '$JOB_NAME' not found in $JOBS_DIR" >&2
  exit 1
fi

start_file="${file_by_name_key[$name_key]}"

# Depth-first walk for topological ordering with cycle detection, using the
# shared job_dependency_files helper for immediate dependencies.
declare -A temp_mark
declare -A perm_mark
declare -a ordered_files

visit_file() {
  local file="$1"
  if [[ -n "${perm_mark[$file]-}" ]]; then
    return
  fi
  if [[ -n "${temp_mark[$file]-}" ]]; then
    echo "Error: circular dependency detected at job '$(yq -r '.spec.name' "$file")'." >&2
    exit 1
  fi

  temp_mark["$file"]=1

  while IFS= read -r dep_file; do
    [[ -z "$dep_file" ]] && continue
    visit_file "$dep_file"
  done < <(job_dependency_files "$file")

  perm_mark["$file"]=1
  ordered_files+=("$file")
}

visit_file "$start_file"

if [[ "$DEBUG" == true ]]; then
  echo "Debug: upload order: ${ordered_files[*]}"
fi

# Upload pipelines in dependency order (or print in dry-run).
for file in "${ordered_files[@]}"; do
  display_name=$(yq -r '.spec.name' "$file")
  if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: would upload job '$display_name' from $file"
    continue
  fi
  if [[ "$DEBUG" == true ]]; then
    echo "Uploading job '$display_name' from $file"
  fi
  yq '.pipeline' "$file" | buildkite-agent pipeline upload
done
