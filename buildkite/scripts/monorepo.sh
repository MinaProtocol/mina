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
#     1. selection       (Triaged or Full) - Determines the mode of selection for triggering jobs.
#                                            Triaged mode checks for relevant changes,
#                                            while Full mode triggers all jobs, which falls under scope and filter.
#     2. tags            STRING            - A filter is a group of job tags, those tags can be any string.
#     3. scope           STRING            - A filter string to determine if the job falls under a specific scope.
#                                            Scope is a gate level in mina like :
#                                             - PR - for pull requests
#                                             - Nightly - for builds that run extended scope of tests including heavy tests
#                                                         which might take longer time to execute
#                                             - Release - full builds with all known jobs, including all supported networks/codenames
#                                             - Mainline Nightly - like above but for mainline branch on nightly basis
#     4. dirty-when      STRING            - A pattern used to check for relevant changes in the repository.
#
# ------------------------------------------------------------------------------

set -euo pipefail

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
  --dirty-when PATTERN   STRING    Pattern for dirty check
  --git-diff-file FILE   STRING    File containing git diff output
  --dry-run              BOOL      Dry run mode (True/False)
  --filter-mode MODE     STRING    Filter mode (any or all)
  --trigger CMD          STRING    Trigger command
  -h, --help             Show this help message
EOF
}

# Default values
SELECTION_MODE=""
JOBS=""
TAGS=""
SCOPES=""
DIRTY_WHEN=""
GIT_DIFF_FILE=""
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
    --dirty-when)
      DIRTY_WHEN="$2"; shift 2;;
    --git-diff-file)
      GIT_DIFF_FILE="$2"; shift 2;;
    --dry-run)
      DRY_RUN=true; shift 1;;
    --filter-mode)
      FILTER_MODE="$2"; shift 2;;
    -h|--help)
      show_help; exit 0;;
    *)
      echo "Unknown option: $1"; show_help; exit 1;;
  esac
done

# Require all arguments
if [[ -z "$SELECTION_MODE" || -z "$JOBS" || -z "$TAGS" || -z "$SCOPES" || -z "$DIRTY_WHEN" ]]; then
  echo "Error: All arguments --selection-mode, --jobs, --tags, --scopes, and --dirty-when are required."
  exit 1
fi

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

has_matching_tags() {
  local tags="$1"
  local filter_any="$2"
  local filter_all="$3"
  shift 3
  local desired_tags=("$@")

  local match_count=0

  for want in "${desired_tags[@]}"; do

    if WANT="$want" \
       yq -e '.[] | select((downcase) == (env(WANT) | downcase))' \
       <<< "$tags" \
       >/dev/null 2>&1
    then
      match_count=$((match_count+1))
    fi
  done

  if $filter_any && [[ $match_count -ge 1 ]]; then
    echo 1
  elif $filter_all && [[ $match_count -eq ${#desired_tags[@]} ]]; then
    echo 1
  else
    echo 0
  fi
}

scope_matches() {
  local scope="$1"
  shift
  local desired_scopes=("$@")
  local match_count=0

 for want in "${desired_scopes[@]}"; do
    # yq v4 NIE ma --arg, więc używamy env(WANT)
    if WANT="$want" \
       yq -e '.[] | select((downcase) == (env(WANT) | downcase))' \
       <<< "$scope" \
         >/dev/null 2>&1
    then
      match_count=$((match_count+1))
      break
    fi
  done

  echo $(( match_count == 1 ? 1 : 0 ))
}

select_job() {
  local selection_full="$1"
  local selection_triaged="$2"
  local file="$3"
  local job_name="$4"
  local git_diff_file="$5"

  if [[ "$selection_full" == true ]]; then
    echo 1
  elif [[ "$selection_triaged" == true ]]; then
    dirtyWhen=$(cat "${file%.yml}.dirtywhen")
    # Remove quotes from beginning and end of string
    dirtyWhen="${dirtyWhen%\"}"
    dirtyWhen="${dirtyWhen#\"}"
    if cat "$git_diff_file" | grep -E "$dirtyWhen" > /dev/null; then
      echo 1
    else
      echo 0
    fi
  fi
}

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

  echo "✅ Including job $job_name in build "

  if [[ "$DRY_RUN" == true ]]; then
      printf " -> 🛑 Dry run enabled, skipping upload for job: %s\n" "$job_name"
  else
    job_path=$(yq -r .spec.path "$file")

    dhall-to-yaml --quoted <<< "(./buildkite/src/Jobs/$job_path/$job_name.dhall).pipeline" | buildkite-agent pipeline upload
    printf " -> ✅ Uploaded job: %s\n" "$job_name"
  fi

done

