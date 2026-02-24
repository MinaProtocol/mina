#!/bin/bash

# ------------------------------------------------------------------------------
# monorepo.sh
#
#   This script is used to determine whether a specific job should be triggered
#   based on the current selection mode, job filters, scope, and changes detected in the repository.
#   It supports conditional triggering for both triaged and full buildkite runs, using
#   parameters such as job name, tag inclusion, scope inclusion, and file change
#   patterns. If the conditions are met, it uploads the corresponding pipeline
#   for the job to Buildkite.
#
#   Glossary of Arguments:
#     1. selection           (triaged or full) - Determines the mode of selection for triggering jobs.
#                                                Triaged mode checks for relevant changes,
#                                                while Full mode triggers all jobs, which falls under scope and filter.
#     2. tags                STRING            - Comma-separated list of job tags to filter by.
#     3. scopes              STRING            - Comma-separated list of scopes to filter by.
#                                                Scope is a gate level in mina like:
#                                                 - PR - for pull requests
#                                                 - Nightly - for builds that run extended scope of tests including heavy tests
#                                                           which might take longer time to execute
#                                                 - Release - full builds with all known jobs, including all supported networks/codenames
#                                                 - Mainline Nightly - like above but for mainline branch on nightly basis
#     4. filter-mode         (any or all)      - Determines if any or all tags must match.
#     5. jobs                PATH              - Path to the jobs directory containing .yml files.
#     6. git-diff-file       PATH              - Path to the git diff file for dirty-when checks.
#     7. mainline-branches   STRING            - Comma-separated list of mainline branches for ancestor detection.
#     8. debug               FLAG              - Optional flag to enable debug output.

set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the library functions
source "$SCRIPT_DIR/monorepo_lib.sh"

show_help() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --selection-mode       MODE      Selection mode (Triaged or Full)
  --is-included-in-tag   BOOL      Is included in tag (True/False)
  --is-included-in-scope BOOL      Is included in scope (True/False)
  --jobs PATH            STRING    Path to jobs directory
  --tags FILTER          STRING    Jobs filter (tags separated by commas)
  --scopes FILTER        STRING    Scope filter (PR, Nightly, Release, Mainline Nightly)
  --git-diff-file FILE   STRING    File containing git diff output
  --dry-run              BOOL      Dry run mode (True/False)
  --filter-mode MODE     STRING    Filter mode (any or all)
  --mainline-branches    STRING    Comma-separated list of mainline branches
  --debug                          Enable debug mode
  --h, --help             Show this help message
EOF
}

# Default values
SELECTION_MODE=""
JOBS=""
TAGS=""
SCOPES=""
GIT_DIFF_FILE=""
MAINLINE_BRANCHES=()
DEBUG=false
DRY_RUN=false

# Parse
while [[ $# -gt 0 ]]; do
  case "$1" in
    --selection-mode)
      SELECTION_MODE="$2"; shift 2;;
    --jobs)
      JOBS="$2"; shift 2;;
    --tags)
      TAGS="$2"; shift 2;;
    --scopes)
      SCOPES="$2"; shift 2;;
    --filter-mode)
      FILTER_MODE="$2"; shift 2;;
    --git-diff-file)
      GIT_DIFF_FILE="$2"; shift 2;;
    --mainline-branches)
      IFS=',' read -r -a MAINLINE_BRANCHES <<< "$2"
      shift; shift;;
    --debug)
      DEBUG=true; shift;;
    --dry-run)
      DRY_RUN=true; shift 1;;
    -h|--help)
      show_help; exit 0;;
    *)
      echo "Unknown option: $1"; show_help; exit 1;;
  esac
done

# Require all arguments
if [[ -z "$SELECTION_MODE" || -z "$JOBS" || -z "$TAGS" || -z "$SCOPES" || -z "$FILTER_MODE" ]]; then
  echo "Error: All arguments --selection-mode, --jobs, --tags, --scopes, and --filter-mode are required."
  exit 1
fi

# Check if mainline branches were provided
if [[ ${#MAINLINE_BRANCHES[@]} -eq 0 ]]; then
  echo "Error: --mainline-branches is required."
  exit 1
fi

# Debug output
if [[ "${DEBUG:-false}" == true ]]; then
  echo "Debug: SELECTION_MODE=$SELECTION_MODE"
  echo "Debug: TAGS=$TAGS"
  echo "Debug: SCOPES=$SCOPES"
  echo "Debug: FILTER_MODE=$FILTER_MODE"
  echo "Debug: JOBS=$JOBS"
  echo "Debug: GIT_DIFF_FILE=$GIT_DIFF_FILE"
  if [[ -n "$GIT_DIFF_FILE" && -f "$GIT_DIFF_FILE" ]]; then
    echo "Debug: Contents of GIT_DIFF_FILE ($GIT_DIFF_FILE):"
    cat "$GIT_DIFF_FILE"
  fi
  echo "Debug: MAINLINE_BRANCHES=${MAINLINE_BRANCHES[*]}"
  echo "Debug: DRY_RUN=$DRY_RUN"

fi

# Check if yq is installed, if not install it
if ! command -v yq &> /dev/null; then
  echo "Error: yq is not installed and automatic installation is not supported on this system. Please install yq manually."
  exit 1
fi

IFS=',' read -r -a DESIRED_TAGS <<< "$TAGS"
IFS=',' read -r -a DESIRED_SCOPES <<< "$SCOPES"

# Set filter flag based on FILTER_MODE
FILTER_ANY=false
FILTER_ALL=false
if [[ "$FILTER_MODE" == "any" ]]; then
  FILTER_ANY=true
elif [[ "$FILTER_MODE" == "all" ]]; then
  FILTER_ALL=true
else
  echo "Error: --filter-mode must be 'any' or 'all'."
  exit 1
fi

# Validate SELECTION value

# Set selection flags
SELECTION_TRIAGED=false
SELECTION_FULL=false
if [[ "$SELECTION_MODE" == "triaged" ]]; then
  SELECTION_TRIAGED=true
elif [[ "$SELECTION_MODE" == "full" ]]; then
  SELECTION_FULL=true
else
  echo "Error: --selection-mode must be 'triaged' or 'full'."
  exit 1
fi

# Check for forced closest ancestor via environment variable
# Used only in testing or if git is on fire
if [[ -n "${FORCE_CLOSEST_ANCESTOR:-}" ]]; then
  closest_ancestor="$FORCE_CLOSEST_ANCESTOR"
else
  closest_ancestor=$(find_closest_ancestor)
fi

find "$JOBS" -type f -name "*.yml" | while read -r file; do
  tags=$(yq .spec.tags "$file")
  scope=$(yq .spec.scope "$file")
  job_name=$(yq -r .spec.name "$file")

  tag_match=$(has_matching_tags "$tags" "$FILTER_ANY" "$FILTER_ALL" "${DESIRED_TAGS[@]}")

  scope_match=$(scope_matches "$scope" "${DESIRED_SCOPES[@]}")

  if [[ $tag_match -ne 1 ]]; then
    echo "🏷️🚫 $job_name rejected job due to tags mismatch: $file" >&2
    continue
  fi
  if [[ $scope_match -ne 1 ]]; then
    echo "🔭🚫 $job_name rejected job due to scope mismatch: $file" >&2
    continue
  fi

  job_selected=$(select_job "$SELECTION_FULL" "$SELECTION_TRIAGED" "$file" "$job_name" "$GIT_DIFF_FILE")

  if [[ $job_selected -ne 1 ]]; then
    echo "🧹🚫 $job_name rejected job as it does not fall into dirty when: $file" >&2
    continue
  fi

  # Check if both includeIf and excludeIf are set - this is not allowed
  has_include_if=$(yq -r '.spec.includeIf | length' "$file")
  has_exclude_if=$(yq -r '.spec.excludeIf | length' "$file")
  if [[ "$has_include_if" != "null" && "$has_include_if" -gt 0 && "$has_exclude_if" != "null" && "$has_exclude_if" -gt 0 ]]; then
    echo "❌ Error: $job_name has both includeIf and excludeIf set. This is not allowed. Please use only one of them." >&2
    exit 1
  fi

  is_excluded=$(check_exclude_if "$file" "$job_name" "$closest_ancestor")

  if [[ $is_excluded -eq 1 ]]; then
    continue
  fi

  is_included=$(check_include_if "$file" "$job_name" "$closest_ancestor")

  if [[ $is_included -ne 1 ]]; then
    continue
  fi

  echo "✅ Including job $job_name in build "

  if [[ "$DRY_RUN" == true ]]; then
      printf " -> 🛑 Dry run enabled, skipping upload for job: %s\n" "$job_name"
  else
    job_path=$(yq -r .spec.path "$file")

    ./buildkite/scripts/pipeline/upload.sh "(./buildkite/src/Jobs/$job_path/$job_name.dhall).pipeline"
    printf " -> ✅ Uploaded job: %s\n" "$job_name"
  fi

done
