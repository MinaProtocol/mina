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
#     5. jobs-filter     STRING            - A filter is a group of job tags, those tags can be any string.
#     6. scope-filter    STRING            - A filter string to determine if the job falls under a specific scope.
#                                            Scope is a gate level in mina like :
#                                             - PR - for pull requests
#                                             - Nightly - for builds that run extended scope of tests including heavy tests
#                                                         which might take longer time to execute
#                                             - Release - full builds with all known jobs, including all supported networks/codenames
#                                             - Mainline Nightly - like above but for mainline branch on nightly basis
#     7. dirty-when      STRING            - A pattern used to check for relevant changes in the repository.


show_help() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --selection-mode       MODE      Selection mode (Triaged or Full)
  --is-included-in-tag   BOOL      Is included in tag (True/False)
  --is-included-in-scope BOOL      Is included in scope (True/False)
  --job-name NAME        STRING    Job name
  --jobs-filter FILTER   STRING    Jobs filter
  --scope-filter FILTER  STRING    Scope filter
  --dirty-when PATTERN   STRING    Pattern for dirty check
  --trigger CMD          STRING    Trigger command
  -h, --help             Show this help message
EOF
}

# Default values
SELECTION_MODE=""
IS_INCLUDED_IN_TAG=""
IS_INCLUDED_IN_SCOPE=""
JOB_NAME=""
JOBS_FILTER=""
SCOPE_FILTER=""
DIRTY_WHEN=""


# Parse
while [[ $# -gt 0 ]]; do
  case "$1" in
    --selection-mode)
      SELECTION_MODE="$2"; shift 2;;
    --is-included-in-tag)
      IS_INCLUDED_IN_TAG="$2"; shift 2;;
    --is-included-in-scope)
      IS_INCLUDED_IN_SCOPE="$2"; shift 2;;
    --job-name)
      JOB_NAME="$2"; shift 2;;
    --job-path)
      JOB_PATH="$2"; shift 2;;
    --jobs-filter)
      JOBS_FILTER="$2"; shift 2;;
    --scope-filter)
      SCOPE_FILTER="$2"; shift 2;;
    --dirty-when)
      DIRTY_WHEN="$2"; shift 2;;
    -h|--help)
      show_help; exit 0;;
    *)
      echo "Unknown option: $1"; show_help; exit 1;;
  esac
done

if [[ -z "$SELECTION_MODE" ]]; then
  echo "Error: --selection-mode is required"; show_help; exit 1
fi

should_trigger=false

if [[ "$SELECTION_MODE" == "Triaged" ]]; then
  if [[ "$IS_INCLUDED_IN_TAG" == "False" ]]; then
    echo "Skipping $JOB_NAME because this job is not falling under $JOBS_FILTER filter "
  elif [[ "$IS_INCLUDED_IN_SCOPE" == "False" ]]; then
    echo "Skipping $JOB_NAME because this job is not falling under $SCOPE_FILTER stage"
  elif grep -E -q "$DIRTY_WHEN" _computed_diff.txt; then
    echo "Triggering $JOB_NAME for reason:"
    grep -E "$DIRTY_WHEN" _computed_diff.txt
    should_trigger=true
  else
    echo "Skipping $JOB_NAME because is irrelevant to PR changes"
  fi
elif [[ "$SELECTION_MODE" == "Full" ]]; then
  if [[ "$IS_INCLUDED_IN_TAG" == "False" ]]; then
    echo "Skipping $JOB_NAME because this job is not falling under $JOBS_FILTER filter "
  elif [[ "$IS_INCLUDED_IN_SCOPE" == "False" ]]; then
    echo "Skipping $JOB_NAME because this job is not falling under $SCOPE_FILTER stage"
  else
    echo "Triggering $JOB_NAME because this is a stable buildkite run"
    should_trigger=true
  fi
else
  echo "Unknown selection mode: $SELECTION_MODE"; show_help; exit 1
fi

if [[ "$should_trigger" == "true" ]]; then
  dhall-to-yaml --quoted <<< "(./buildkite/src/Jobs/${JOB_PATH}/${JOB_NAME}.dhall).pipeline" | buildkite-agent pipeline upload
fi
