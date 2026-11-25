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
    # Unescape YAML-escaped backslashes (dhall-to-yaml outputs \\\\ for regex \\)
    dirtyWhen="${dirtyWhen//\\\\/\\}"
    if cat "$git_diff_file" | grep -E "$dirtyWhen" > /dev/null; then
      echo 1
    else
      echo 0
    fi
  fi
}

# ------------------------------------------------------------------------------
# Dependency resolution
#
#   A job selected by dirty-when triage may depend (via step depends_on) on other
#   jobs -- typically build jobs -- whose own dirty-when did NOT match the change
#   set. Those dependencies must still be uploaded, otherwise the selected job
#   waits on a step that never gets scheduled. The helpers below reproduce the
#   dependency walk used by run-single-job-with-deps.sh (the !ci-single-me logic)
#   so triage can pull every prerequisite job into the run set.
# ------------------------------------------------------------------------------

# Global: maps a pipeline step key to the job YAML file that defines it.
declare -A STEP_KEY_TO_FILE

# build_step_index - populate STEP_KEY_TO_FILE from every job YAML in a directory.
# Args:
#   $1: jobs directory
build_step_index() {
  local jobs_dir="$1"
  STEP_KEY_TO_FILE=()
  local file key
  while IFS= read -r file; do
    while IFS= read -r key; do
      [[ -z "$key" || "$key" == "null" ]] && continue
      STEP_KEY_TO_FILE["$key"]="$file"
    done < <(yq -r '[.pipeline.steps[]?.key] | .[]' "$file" 2>/dev/null)
  done < <(find "$jobs_dir" -type f -name "*.yml")
}

# job_dependency_files - print the immediate dependency job files of a job: the
# jobs that own the steps this job's steps depend on. Dedupes and skips
# self-references (steps that depend on other steps of the same job). Requires
# build_step_index to have been called first.
# Args:
#   $1: job YAML file
job_dependency_files() {
  local file="$1"
  local -A seen=()
  local dep_key dep_file
  while IFS= read -r dep_key; do
    [[ -z "$dep_key" || "$dep_key" == "null" ]] && continue
    dep_file="${STEP_KEY_TO_FILE[$dep_key]-}"
    if [[ -z "$dep_file" ]]; then
      echo "⚠️  Warning: dependency step '$dep_key' (required by $(basename "$file")) is not produced by any known job" >&2
      continue
    fi
    [[ "$dep_file" == "$file" ]] && continue
    if [[ -z "${seen[$dep_file]-}" ]]; then
      seen["$dep_file"]=1
      echo "$dep_file"
    fi
  done < <(yq -r '[.pipeline.steps[]?.depends_on[]?.step] | .[]' "$file" 2>/dev/null)
}

# resolve_transitive_deps - print the set of dependency job files (transitive,
# excluding the starting file itself) for a given job. Each dependency is emitted
# at most once. Requires build_step_index to have been called first.
# Args:
#   $1: starting job YAML file
resolve_transitive_deps() {
  local start="$1"
  local -A visited=()
  local -a queue=("$start")
  visited["$start"]=1

  while [[ ${#queue[@]} -gt 0 ]]; do
    local cur="${queue[0]}"
    queue=("${queue[@]:1}")

    local dep_file
    while IFS= read -r dep_file; do
      [[ -z "$dep_file" ]] && continue
      if [[ -z "${visited[$dep_file]-}" ]]; then
        visited["$dep_file"]=1
        queue+=("$dep_file")
      fi
    done < <(job_dependency_files "$cur")
  done

  local f
  for f in "${!visited[@]}"; do
    [[ "$f" != "$start" ]] && echo "$f"
  done
}
