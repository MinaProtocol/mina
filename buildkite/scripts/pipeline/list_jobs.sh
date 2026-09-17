#!/usr/bin/env bash

# Print the jobs a pipeline stage would run, without uploading anything.
#
# Takes the SAME environment variables the Buildkite pipeline settings set on a
# stage (see the "fast checks" / "long tests" / "tear down" steps), resolves them
# through the same Dhall filters the real triage uses, and runs monorepo.sh in
# dry-run mode. Use it to answer "which jobs does this stage actually run?"
# before changing a filter or a job's tags.
#
# Usage:
#   BUILDKITE_PIPELINE_FILTER=LongAndVeryLong \
#   BUILDKITE_PIPELINE_SCOPE=MainlineNightly \
#   BUILDKITE_PIPELINE_JOB_SELECTION=Full \
#     ./buildkite/scripts/pipeline/list_jobs.sh
#
# Environment (all optional, defaults match Prepare.dhall):
#   BUILDKITE_PIPELINE_FILTER         tag filter, e.g. FastOnly, LongAndVeryLong,
#                                     Packaging, TearDownOnly  (default FastOnly)
#   BUILDKITE_PIPELINE_SCOPE          scope filter               (default All)
#   BUILDKITE_PIPELINE_JOB_SELECTION  Full | Triaged             (default Full)
#   BUILDKITE_PIPELINE_FILTER_MODE    Any | All                  (default Any)
#
# Options:
#   --diff-file <path>  git diff file to triage against (only meaningful with
#                       BUILDKITE_PIPELINE_JOB_SELECTION=Triaged)
#   --verbose           also show the per-job rejection reasons from monorepo.sh
#   --regenerate        re-dump the job specs from Dhall before triaging
#
# Exits non-zero if the filter/scope names do not resolve, so a typo in a
# pipeline setting is reported rather than silently selecting nothing.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

TAG_FILTER="${BUILDKITE_PIPELINE_FILTER:-FastOnly}"
SCOPE_FILTER="${BUILDKITE_PIPELINE_SCOPE:-All}"
SELECTION="${BUILDKITE_PIPELINE_JOB_SELECTION:-Full}"
FILTER_MODE="${BUILDKITE_PIPELINE_FILTER_MODE:-Any}"

DIFF_FILE=""
VERBOSE=false
REGENERATE=false

while [[ "$#" -gt 0 ]]; do case $1 in
  --diff-file) DIFF_FILE="$2"; shift;;
  --verbose) VERBOSE=true;;
  --regenerate) REGENERATE=true;;
  -h|--help) sed -n '3,32p' "${BASH_SOURCE[0]}"; exit 0;;
  *) echo "Unknown option: $1" >&2; exit 1;;
esac; shift; done

cd "$REPO_ROOT"

GEN_DIR="buildkite/src/gen"
if [[ "$REGENERATE" == true || ! -d "$GEN_DIR" ]]; then
  echo "--- Dumping job specs from Dhall" >&2
  ./buildkite/scripts/dhall/dump_dhall_to_pipelines.sh ./buildkite/src "$GEN_DIR" >/dev/null
fi

# Resolve the filter names through Dhall, exactly as Monorepo.dhall does, so this
# tool cannot drift from what the pipeline really runs.
resolve() {
  local expr="$1" what="$2"
  local out
  if ! out=$(dhall text <<< "$expr" 2>&1); then
    echo "Error: could not resolve ${what}." >&2
    echo "       Check the name against buildkite/src/Pipeline/*.dhall." >&2
    echo "$out" >&2
    exit 1
  fi
  echo "$out"
}

TAGS=$(resolve \
  "(./buildkite/src/Pipeline/Tag.dhall).join ((./buildkite/src/Pipeline/TagFilter.dhall).tags (./buildkite/src/Pipeline/TagFilter.dhall).Type.${TAG_FILTER})" \
  "tag filter '${TAG_FILTER}'")

SCOPES=$(resolve \
  "(./buildkite/src/Pipeline/Scope.dhall).join ((./buildkite/src/Pipeline/ScopeFilter.dhall).scopes (./buildkite/src/Pipeline/ScopeFilter.dhall).Type.${SCOPE_FILTER})" \
  "scope filter '${SCOPE_FILTER}'")

MODE_LOWER=$(echo "$FILTER_MODE" | tr '[:upper:]' '[:lower:]')

echo "=============================================================="
echo " Pipeline stage"
echo "   BUILDKITE_PIPELINE_FILTER        = ${TAG_FILTER}"
echo "   BUILDKITE_PIPELINE_SCOPE         = ${SCOPE_FILTER}"
echo "   BUILDKITE_PIPELINE_JOB_SELECTION = ${SELECTION}"
echo "   BUILDKITE_PIPELINE_FILTER_MODE   = ${FILTER_MODE}"
echo " resolves to"
echo "   tags   = ${TAGS}"
echo "   scopes = ${SCOPES}"
echo "=============================================================="

SELECTION_LOWER=$(echo "$SELECTION" | tr '[:upper:]' '[:lower:]')

DIFF_ARG=()
if [[ -n "$DIFF_FILE" ]]; then
  DIFF_ARG=(--git-diff-file "$DIFF_FILE")
fi

OUT=$(./buildkite/scripts/monorepo.sh \
  --selection-mode "$SELECTION_LOWER" \
  --tags "$TAGS" \
  --scopes "$SCOPES" \
  --filter-mode "$MODE_LOWER" \
  --jobs "$GEN_DIR" \
  --mainline-branches "$(dhall text <<< '(./buildkite/src/Pipeline/MainlineBranch.dhall).join (./buildkite/src/Pipeline/MainlineBranch.dhall).Full')" \
  "${DIFF_ARG[@]}" \
  --dry-run 2>&1) || {
    echo "$OUT" >&2
    echo "Error: monorepo.sh failed." >&2
    exit 1
  }

if [[ "$VERBOSE" == true ]]; then
  echo "$OUT"
  echo "=============================================================="
fi

# "Dry run enabled, skipping upload for job: X" is emitted once per job in the
# final run set -- i.e. jobs selected by tag/scope/dirty-when PLUS dependencies
# pulled in by phase 2. That set is exactly what the stage would upload.
mapfile -t JOBS < <(echo "$OUT" | sed -n 's/.*Dry run enabled, skipping upload for job: //p' | sort -u)

echo " Jobs this stage would run: ${#JOBS[@]}"
echo "--------------------------------------------------------------"
if [[ "${#JOBS[@]}" -eq 0 ]]; then
  echo " (none)"
else
  printf '  %s\n' "${JOBS[@]}"
fi
echo "=============================================================="

# Dependencies pulled in by phase 2 rather than selected on their own merit are
# worth calling out: they run in this stage even though its filter did not pick
# them.
mapfile -t PULLED < <(echo "$OUT" | sed -n 's/.*➕ Including dependency job \([^ ]*\) .*/\1/p' | sort -u)
if [[ "${#PULLED[@]}" -gt 0 ]]; then
  echo " Of those, pulled in as dependencies (not matched by the filter):"
  printf '  %s\n' "${PULLED[@]}"
  echo "=============================================================="
fi
