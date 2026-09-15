#!/usr/bin/env bash

# Run a single Buildkite job plus its dependency chain. This script handles !ci-single-me {job}
# You can use it to run a specific job and all its prerequisites in the correct order.
# IMPORTANT: This script assumes that the job pipelines have already been generated
# (e.g. via dhall) and are available in the specified --jobs directory.
# In order to get job name visit dhall file in buildkite/src/Jobs and look for spec.name field.
# Flow:
# - Reads generated job pipeline YAMLs in --jobs.
# - Resolves the requested job by name (case-insensitive).
# - Walks step dependencies to find prerequisite jobs.
# - Orders jobs topologically and uploads each pipeline.

set -euo pipefail

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

# Index job files by name and map step keys to job names.
declare -A step_key_to_job
declare -A job_file_by_name
declare -A job_display_by_name

mapfile -t job_files < <(find "$JOBS_DIR" -type f -name "*.yml" | sort)

if [[ ${#job_files[@]} -eq 0 ]]; then
  echo "Error: no job pipeline files found in $JOBS_DIR" >&2
  exit 1
fi

for file in "${job_files[@]}"; do
  job_name=$(yq -r '.spec.name' "$file")
  if [[ -z "$job_name" || "$job_name" == "null" ]]; then
    job_name=$(basename "$file")
    job_name="${job_name%.yml}"
  fi

  job_name_key=$(to_lower "$job_name")
  if [[ -n "${job_file_by_name[$job_name_key]-}" && "${job_display_by_name[$job_name_key]}" != "$job_name" ]]; then
    echo "Error: job name collision (case-insensitive): '${job_display_by_name[$job_name_key]}' and '$job_name'." >&2
    exit 1
  fi
  job_file_by_name["$job_name_key"]="$file"
  job_display_by_name["$job_name_key"]="$job_name"

  while IFS= read -r step_key; do
    [[ -z "$step_key" || "$step_key" == "null" ]] && continue
    if [[ -n "${step_key_to_job[$step_key]-}" && "${step_key_to_job[$step_key]}" != "$job_name_key" ]]; then
      echo "Warning: duplicate step key '$step_key' in $file (already mapped to ${job_display_by_name[${step_key_to_job[$step_key]}]})." >&2
    fi
    step_key_to_job["$step_key"]="$job_name_key"
  done < <(yq -r '.pipeline.steps[].key' "$file")
done

# Resolve the requested job name.
job_name_key=$(to_lower "$JOB_NAME")
if [[ -z "${job_file_by_name[$job_name_key]-}" ]]; then
  candidate="$JOBS_DIR/$JOB_NAME.yml"
  if [[ -f "$candidate" ]]; then
    resolved_name=$(yq -r '.spec.name' "$candidate")
    if [[ -n "$resolved_name" && "$resolved_name" != "null" ]]; then
      job_name_key=$(to_lower "$resolved_name")
      JOB_NAME="$resolved_name"
    else
      base_name=$(basename "$candidate")
      base_name="${base_name%.yml}"
      job_name_key=$(to_lower "$base_name")
      JOB_NAME="$base_name"
    fi
  fi
fi

if [[ -z "${job_file_by_name[$job_name_key]-}" ]]; then
  echo "Error: job '$JOB_NAME' not found in $JOBS_DIR" >&2
  exit 1
fi

# Extract dependency step keys from a pipeline file.
list_dep_steps() {
  local file="$1"
  yq -r '.pipeline.steps[].depends_on[]? | .step' "$file"
}

# Map dependency step keys to job names and return unique deps.
get_job_deps() {
  local job="$1"
  local file="${job_file_by_name[$job]}"
  declare -A seen=()

  while IFS= read -r dep_step; do
    [[ -z "$dep_step" || "$dep_step" == "null" ]] && continue
    dep_job="${step_key_to_job[$dep_step]-}"
    if [[ -z "$dep_job" ]]; then
      echo "Error: dependency step '$dep_step' referenced by job '${job_display_by_name[$job]}' not found in $JOBS_DIR." >&2
      exit 1
    fi
    if [[ "$dep_job" == "$job" ]]; then
      continue
    fi
    if [[ -z "${seen[$dep_job]-}" ]]; then
      seen["$dep_job"]=1
      echo "$dep_job"
    fi
  done < <(list_dep_steps "$file")
}

# Depth-first walk for topological ordering with cycle detection.
declare -A temp_mark
declare -A perm_mark
declare -a ordered_jobs

visit_job() {
  local job="$1"
  if [[ -n "${perm_mark[$job]-}" ]]; then
    return
  fi
  if [[ -n "${temp_mark[$job]-}" ]]; then
    echo "Error: circular dependency detected at job '$job'." >&2
    exit 1
  fi

  temp_mark["$job"]=1

  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    if [[ -z "${job_file_by_name[$dep]-}" ]]; then
      echo "Error: dependency job '${job_display_by_name[$dep]-$dep}' not found in $JOBS_DIR" >&2
      exit 1
    fi
    visit_job "$dep"
  done < <(get_job_deps "$job")

  perm_mark["$job"]=1
  ordered_jobs+=("$job")
}

visit_job "$job_name_key"

if [[ "$DEBUG" == true ]]; then
  echo "Debug: upload order: ${ordered_jobs[*]}"
fi

# Upload pipelines in dependency order (or print in dry-run).
for job in "${ordered_jobs[@]}"; do
  file="${job_file_by_name[$job]}"
  display_name="${job_display_by_name[$job]}"
  if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: would upload job '$display_name' from $file"
    continue
  fi
  if [[ "$DEBUG" == true ]]; then
    echo "Uploading job '$display_name' from $file"
  fi
  yq '.pipeline' "$file" | buildkite-agent pipeline upload
done
