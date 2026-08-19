#!/usr/bin/env bash

# Build only the steps that were asked for.
#
# The pipelines are rendered to YAML, select_steps.sh works out which steps to
# run (the ones named, and everything they depend on), and this script uploads
# those steps only. A job with no chosen step is not uploaded at all.
#
# Usage:
#   run-selection.sh --selection "PATTERN[,PATTERN...]" --jobs DIR [options]
#
#   --selection LIST   Patterns for step keys, separated by commas. This is what
#                      the author of the comment wrote, so it is not trusted:
#                      every pattern must match a step, or the script stops.
#   --deb LIST         Patterns for debian package tokens, separated by commas
#                      (prefork_*, logproc, ...). The debian step of a job is
#                      then told to build only the packages that match.
#                      See "Narrowing the debian step" below.
#   --jobs DIR         Directory of rendered pipelines (buildkite/src/gen)
#   --dry-run          Write what would be uploaded, upload nothing.
#   --debug            Write the pruned pipeline of each job.
#   -h, --help         Write this text.
#
# Exit codes:
#   0  the chosen steps were uploaded (or written, with --dry-run)
#   1  nothing matched what was asked for
#   2  the arguments or the environment are wrong
#
# A step that waits for a step which is not uploaded waits for ever, so this
# script never prunes a dependency away: select_steps.sh adds them, and the
# check below fails the run if one is missing all the same.
#
# Narrowing the debian step
# -------------------------
# One step builds every debian package of a job:
#
#   build-from-cache.sh <variant> <token> <token> ...
#
# With --deb, that list is cut down to the tokens that match. It is only cut
# down when NO docker image of that job is being built, because the images
# install those .deb files from the build context (install-mina-debs.sh), so an
# image whose packages were not built fails inside docker with a message about
# a missing file. When an image survives, the whole list is kept and the reason
# is written out.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELECT_STEPS="${SCRIPT_DIR}/../pipeline/select_steps.sh"
NARROW_DEBS="${SCRIPT_DIR}/../pipeline/narrow_debian_tokens.py"

SELECTION=""
DEB_SELECTION=""
JOBS_DIR=""
DRY_RUN=false
DEBUG=false

usage() {
    sed -n '3,27p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

fail() {
    echo "ERROR: $*" >&2
    exit 2
}

while [[ "$#" -gt 0 ]]; do case "$1" in
    --selection) SELECTION="${2:-}"; shift 2 ;;
    --deb)       DEB_SELECTION="${2:-}"; shift 2 ;;
    --jobs)      JOBS_DIR="${2:-}"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    --debug)     DEBUG=true; shift ;;
    -h|--help)   usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 2 ;;
esac; done

if [[ -z "$SELECTION" && -n "$DEB_SELECTION" ]]; then
    # Asking for packages means asking for the step that builds them.
    SELECTION="build-deb-pkg"
fi

[[ -n "$SELECTION" ]] || fail "--selection or --deb is required."
[[ -n "$JOBS_DIR" ]] || fail "--jobs is required."
[[ -d "$JOBS_DIR" ]] || fail "'${JOBS_DIR}' is not a directory."
[[ -x "$SELECT_STEPS" ]] || fail "'${SELECT_STEPS}' is not there."
command -v yq > /dev/null 2>&1 || fail "'yq' is not installed."

# ---------------------------------------------------------------------------
# Work out the run set
# ---------------------------------------------------------------------------

declare -a SELECT_ARGS=()
IFS=',' read -ra RAW_PATTERNS <<< "$SELECTION"
for pattern in "${RAW_PATTERNS[@]}"; do
    # Take the spaces off, so that "a, b" works as well as "a,b".
    pattern="$(echo "$pattern" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ -z "$pattern" ]] && continue
    SELECT_ARGS+=(--select "$pattern")
done

[[ "${#SELECT_ARGS[@]}" -gt 0 ]] || fail "--selection holds no pattern."

echo "--- Working out which steps to run"

PLAN_FILE="$(mktemp)"
trap 'rm -f "$PLAN_FILE"' EXIT

set +e
"$SELECT_STEPS" --jobs "$JOBS_DIR" --format plan "${SELECT_ARGS[@]}" > "$PLAN_FILE"
SELECT_STATUS=$?
set -e

if [[ "$SELECT_STATUS" -ne 0 ]]; then
    exit "$SELECT_STATUS"
fi

# job file -> the keys of its chosen steps, separated by spaces
declare -A JOB_STEPS=()
while IFS=$'\t' read -r file key; do
    [[ -z "$file" || -z "$key" ]] && continue
    JOB_STEPS["$file"]="${JOB_STEPS[$file]-} ${key}"
done < "$PLAN_FILE"

[[ "${#JOB_STEPS[@]}" -gt 0 ]] || fail "the run set is empty."

# Every key of the run set, to check the dependencies against.
ALL_KEYS=" $(cut -f2 "$PLAN_FILE" | tr '\n' ' ') "

echo "--- Run set: $(cut -f2 "$PLAN_FILE" | wc -l) step(s) in ${#JOB_STEPS[@]} job(s)"

# ---------------------------------------------------------------------------
# Keep only the chosen steps of each job, and upload
# ---------------------------------------------------------------------------

UPLOADED=0

for file in "${!JOB_STEPS[@]}"; do
    job_name="$(yq -r '.spec.name' "$file")"

    # Build the yq test: keep a step when its key is one of the chosen ones.
    filter=""
    for key in ${JOB_STEPS[$file]}; do
        if [[ -z "$filter" ]]; then
            filter=".key == \"${key}\""
        else
            filter="${filter} or .key == \"${key}\""
        fi
    done

    pruned="$(yq -o=yaml ".pipeline | .steps |= map(select(${filter}))" "$file")"

    # A step that waits for a step nobody uploads waits for ever. select_steps.sh
    # adds every dependency, so this can only fail if the two stop agreeing.
    missing=""
    while IFS= read -r dep; do
        [[ -z "$dep" || "$dep" == "null" ]] && continue
        if [[ "$ALL_KEYS" != *" ${dep} "* ]]; then
            missing="${missing} ${dep}"
        fi
    done < <(echo "$pruned" | yq -r '[.steps[]?.depends_on[]?.step] | .[]' 2>/dev/null)

    if [[ -n "$missing" ]]; then
        echo "ERROR: in job '${job_name}', these steps are waited for but not uploaded:${missing}" >&2
        echo "       select_steps.sh and this script disagree; that is a fault, not a bad request." >&2
        exit 2
    fi

    # Narrow the debian step, but only when this job builds no image: the
    # images install those .deb files from the build context, so an image whose
    # packages were not built fails inside docker.
    if [[ -n "$DEB_SELECTION" && "${JOB_STEPS[$file]}" == *build-deb-pkg* ]]; then
        if [[ "${JOB_STEPS[$file]}" == *docker-image* ]]; then
            echo " !  ${job_name}: keeping every debian package, because this job also builds images that install them" >&2
        else
            declare -a deb_patterns=()
            IFS=',' read -ra raw_debs <<< "$DEB_SELECTION"
            for d in "${raw_debs[@]}"; do
                d="$(echo "$d" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
                [[ -n "$d" ]] && deb_patterns+=("$d")
            done

            if ! narrowed="$(echo "$pruned" | "$NARROW_DEBS" "${deb_patterns[@]}")"; then
                echo "ERROR: in job '${job_name}', no debian package matches ${DEB_SELECTION}" >&2
                exit 1
            fi
            pruned="$narrowed"
        fi
    fi

    count="$(echo "$pruned" | yq -r '[.steps[]?] | length')"

    if [[ "$DEBUG" == true ]]; then
        echo "--- Pruned pipeline of ${job_name} (${count} step(s))"
        echo "$pruned"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo " -> would upload ${job_name} with ${count} step(s):$(echo "${JOB_STEPS[$file]}" | tr ' ' '\n' | sed 's/^/ /' | tr -d '\n')"
        continue
    fi

    echo " -> uploading ${job_name} with ${count} step(s)"
    echo "$pruned" | buildkite-agent pipeline upload
    UPLOADED=$((UPLOADED + 1))
done

if [[ "$DRY_RUN" == true ]]; then
    echo "--- Dry run: nothing was uploaded."
else
    echo "--- Uploaded ${UPLOADED} job(s)."
fi
