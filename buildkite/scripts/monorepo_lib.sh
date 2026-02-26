#!/bin/bash

# ------------------------------------------------------------------------------
# monorepo_lib.sh
#
#   Library of functions used by monorepo.sh for job filtering and selection.
#   This file is meant to be sourced by other scripts.
#
# ------------------------------------------------------------------------------

# has_matching_tags - Check if a job's tags match the desired tags
# Args:
#   $1: tags (YAML array as string)
#   $2: filter_any (true/false)
#   $3: filter_all (true/false)
#   $@: desired_tags (remaining args)
# Returns: 1 if matching, 0 if not
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

# scope_matches - Check if a job's scope matches the desired scopes
# Args:
#   $1: scope (YAML array as string)
#   $@: desired_scopes (remaining args)
# Returns: 1 if matching, 0 if not
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

# check_exclude_if - Check if a job should be excluded based on excludeIf conditions
# Args:
#   $1: file - path to job YAML file
#   $2: job_name - name of the job
#   $3: closest_ancestor - the closest mainline branch ancestor
# Returns: 1 if excluded, 0 if not
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

    # Case-insensitive comparison: dhall produces branch names with capital letters
    # (e.g., "Mesa") while git branch names may be lowercase (e.g., "mesa")
    if [[ "${ancestor,,}" == "${closest_ancestor,,}" ]]; then
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

# check_include_if - Check if a job should be included based on includeIf conditions
# Args:
#   $1: file - path to job YAML file
#   $2: job_name - name of the job
#   $3: closest_ancestor - the closest mainline branch ancestor
# Returns: 1 if included, 0 if not
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

    # Case-insensitive comparison: dhall produces branch names with capital letters
    # (e.g., "Mesa") while git branch names may be lowercase (e.g., "mesa")
    if [[ "${ancestor,,}" == "${closest_ancestor,,}" ]]; then
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

# select_job - Determine if a job should be selected based on selection mode
# Args:
#   $1: selection_full (true/false)
#   $2: selection_triaged (true/false)
#   $3: file - path to job YAML file
#   $4: job_name - name of the job
#   $5: git_diff_file - path to git diff file
# Returns: 1 if selected, 0 if not
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

# find_closest_ancestor - Find the closest mainline branch ancestor
# Uses global variable MAINLINE_BRANCHES (array of branch names)
# Returns: name of the closest ancestor branch
find_closest_ancestor() {
  CURRENT_COMMIT=$(git rev-parse HEAD)
  closest_branch=""
  min_distance=""
  for branch in "${MAINLINE_BRANCHES[@]}"; do
    ancestor=$(git merge-base "$CURRENT_COMMIT" "origin/$branch")
    distance=$(git rev-list --count "${ancestor}..${CURRENT_COMMIT}")
    echo "Branch $branch: $distance commits from current commit ($CURRENT_COMMIT) via ancestor $ancestor" >&2
    # Use <= so that branches later in MAINLINE_BRANCHES array win ties
    # This makes the order in --mainline-branches meaningful for priority
    if [[ -z "$min_distance" || $distance -le $min_distance ]]; then
      min_distance=$distance
      closest_branch=$branch
    fi
  done
  echo "$closest_branch"
}
