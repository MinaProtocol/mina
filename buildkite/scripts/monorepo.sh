#!/bin/bash

# Usage:
# monorepo.sh --scopes <scopes> --tags <tags> --filter-mode <filter_mode> --selection <selection> --jobs <jobs>

set -euo pipefail

# Default values
SCOPES=""
TAGS=""
FILTER_MODE=""
SELECTION=""
JOBS=""
GIT_DIFF_FILE=""
MAINLINE_BRANCHES=()
DRY_RUN=false

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --scopes)
      SCOPES="$2"
      shift; shift
      ;;
    --tags)
      TAGS="$2"
      shift; shift
      ;;
    --filter-mode)
      FILTER_MODE="$2"
      shift; shift
      ;;
    --selection)
      SELECTION="$2"
      shift; shift
      ;;
    --jobs)
      JOBS="$2"
      shift; shift
      ;;
    --git-diff-file)
      GIT_DIFF_FILE="$2"
      shift; shift
      ;;
    --mainline-branches)
      IFS=',' read -r -a MAINLINE_BRANCHES <<< "$2"
      shift; shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --debug)
      set -x
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done


# Require all arguments
if [[ -z "$SCOPES" || -z "$TAGS" || -z "$FILTER_MODE" || -z "$SELECTION" || -z "$JOBS" || -z "$GIT_DIFF_FILE" ]]; then
  echo "Error: All arguments --scopes, --tags, --filter-mode, --selection, --jobs, and --git-diff-file are required."
  exit 1
fi


# Fetch mainline branches needed by monorepo.sh for merge-base calculations
for branch in "${MAINLINE_BRANCHES[@]}"; do
  git fetch origin "$branch:$branch"
done

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
if [[ "$SELECTION" == "triaged" ]]; then
  SELECTION_TRIAGED=true
elif [[ "$SELECTION" == "full" ]]; then
  SELECTION_FULL=true
else
  echo "Error: --selection must be 'triaged' or 'full'."
  exit 1
fi

find_closest_ancestor() {
  CURRENT_COMMIT=$(git rev-parse HEAD)
  closest_branch=""
  min_distance=""
  for branch in "${MAINLINE_BRANCHES[@]}"; do
    ancestor=$(git merge-base "$CURRENT_COMMIT" "origin/$branch")
    distance=$(git rev-list --count "${ancestor}..${CURRENT_COMMIT}")
    echo "Branch $branch: $distance commits from current commit ($CURRENT_COMMIT) via ancestor $ancestor" >&2
    if [[ -z "$min_distance" || $distance -lt $min_distance ]]; then
      min_distance=$distance
      closest_branch=$branch
    fi
  done
  echo "$closest_branch"
}


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
    # yq v4 doesn't have --arg, so we use env(WANT)
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

check_exclude_if() {
  local file="$1"
  local job_name="$2"
  local closest_ancestor="$3"

  # Check if excludeIf exists
  local exclude_if_count
  exclude_if_count=$(yq -r '.spec.excludeIf | length' "$file")

  if [[ "$exclude_if_count" == "null" || "$exclude_if_count" -eq 0 ]]; then
    echo 0
    return
  fi

  # Check each excludeIf condition
  for ((i=0; i<exclude_if_count; i++)); do
    # Safely read ancestor and reason fields - they may not exist
    local ancestor reason
    ancestor=$(yq -r ".spec.excludeIf[$i].ancestor // \"\"" "$file")
    reason=$(yq -r ".spec.excludeIf[$i].reason // \"\"" "$file")

    # Skip this item if it doesn't have ancestor field (not an ancestor-based exclusion)
    if [[ -z "$ancestor" || "$ancestor" == "null" ]]; then
      echo "⚠️  Skipping excludeIf[$i] for $job_name: no 'ancestor' field found (possibly different exclusion type)" >&2
      continue
    fi

    echo "Evaluating excludeIf[$i]: ancestor=$ancestor, reason=$reason, closest_ancestor=$closest_ancestor" >&2

    # Case-insensitive comparison
    local ancestor_lower closest_ancestor_lower
    ancestor_lower=$(echo "$ancestor" | tr '[:upper:]' '[:lower:]')
    closest_ancestor_lower=$(echo "$closest_ancestor" | tr '[:upper:]' '[:lower:]')

    if [[ "$ancestor_lower" == "$closest_ancestor_lower" ]]; then
      if [[ -n "$reason" && "$reason" != "null" ]]; then
        echo "❌🚫 $job_name excluded based on excludeIf condition: $reason" >&2
      else
        echo "❌🚫 $job_name excluded based on excludeIf condition (ancestor: $ancestor)" >&2
      fi
      echo 1
      return
    fi
  done

  echo 0
}

check_include_if() {
  local file="$1"
  local job_name="$2"
  local closest_ancestor="$3"

  # Check if includeIf exists
  local include_if_count
  include_if_count=$(yq -r '.spec.includeIf | length' "$file")

  # If no includeIf conditions, include by default
  if [[ "$include_if_count" == "null" || "$include_if_count" -eq 0 ]]; then
    echo 1
    return
  fi

  # Check each includeIf condition
  for ((i=0; i<include_if_count; i++)); do
    # Safely read ancestor and reason fields - they may not exist
    local ancestor reason
    ancestor=$(yq -r ".spec.includeIf[$i].ancestor // \"\"" "$file")
    reason=$(yq -r ".spec.includeIf[$i].reason // \"\"" "$file")

    # Skip this item if it doesn't have ancestor field (not an ancestor-based inclusion)
    if [[ -z "$ancestor" || "$ancestor" == "null" ]]; then
      echo "⚠️  Skipping includeIf[$i] for $job_name: no 'ancestor' field found (possibly different inclusion type)" >&2
      continue
    fi

    echo "Evaluating includeIf[$i]: ancestor=$ancestor, reason=$reason, closest_ancestor=$closest_ancestor" >&2

    # Case-insensitive comparison
    local ancestor_lower closest_ancestor_lower
    ancestor_lower=$(echo "$ancestor" | tr '[:upper:]' '[:lower:]')
    closest_ancestor_lower=$(echo "$closest_ancestor" | tr '[:upper:]' '[:lower:]')

    if [[ "$ancestor_lower" == "$closest_ancestor_lower" ]]; then
      if [[ -n "$reason" && "$reason" != "null" ]]; then
        echo "✅ $job_name included based on includeIf condition: $reason" >&2
      else
        echo "✅ $job_name included based on includeIf condition (ancestor: $ancestor)" >&2
      fi
      echo 1
      return
    fi
  done

  # If we have includeIf conditions but none matched, exclude the job
  echo "❌🚫 $job_name excluded: none of the includeIf conditions matched" >&2
  echo 0
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


# Find the closest ancestor branch
# which will be used for excludeIf evaluations
closest_ancestor=$(find_closest_ancestor)

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

    dhall-to-yaml --quoted <<< "(./buildkite/src/Jobs/$job_path/$job_name.dhall).pipeline" | buildkite-agent pipeline upload
    printf " -> ✅ Uploaded job: %s\n" "$job_name"
  fi

done

