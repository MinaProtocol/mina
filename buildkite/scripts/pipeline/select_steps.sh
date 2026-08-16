#!/usr/bin/env bash

# Choose pipeline steps by name, and add everything they depend on.
#
# The pipelines are rendered to YAML first (see dump_dhall_to_pipelines.sh), so
# every step that CI can run already has a key, and the key already holds what
# is built, for which tier and for which network:
#
#   daemon_apps_only-devnet     archive-devnet
#   daemon_profile-lightnet     rosetta_apps_only-devnet
#   daemon_config-devnet        rosetta_config-devnet
#
# This script takes patterns for those keys and writes the steps that match,
# together with the steps they depend on. It changes nothing: it only says what
# the run set is. The caller decides what to do with it.
#
# The dependency walk uses the index in monorepo_lib.sh, which reads the real
# `depends_on` of the rendered pipelines. There is no second list of
# dependencies to keep in step with the first.
#
# Usage:
#   select_steps.sh --jobs DIR --select PATTERN [--select PATTERN ...] [options]
#
#   --jobs DIR         Directory of rendered pipeline YAML (buildkite/src/gen)
#   --select PATTERN   Pattern for a step key. Give it more than once to add
#                      steps together. A pattern may hold * and ?.
#   --format FORMAT    plan  (default) one "<file><TAB><step key>" for each step
#                      keys  the step keys only
#                      files the job files only, each one time
#   --quiet            Do not write the report on stderr.
#   -h, --help         Write this text.
#
# A pattern is matched against the whole key and against the key without the
# "_<JobName>-" that the renderer puts in front, so both of these choose the
# same step:
#
#   --select 'rosetta_config-devnet-docker-image'
#   --select '_MinaArtifactBullseye-rosetta_config-devnet-docker-image'
#
# Exit codes:
#   0  at least one step was chosen
#   1  no step matched (the keys that exist are written on stderr)
#   2  the arguments or the environment are wrong

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=buildkite/scripts/monorepo_lib.sh
source "${SCRIPT_DIR}/../monorepo_lib.sh"

JOBS_DIR=""
FORMAT="plan"
QUIET=0
declare -a PATTERNS=()

usage() {
    sed -n '3,45p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

fail() {
    echo "ERROR: $*" >&2
    exit 2
}

while [[ "$#" -gt 0 ]]; do case "$1" in
    --jobs)   JOBS_DIR="${2:-}"; shift 2 ;;
    --select) PATTERNS+=("${2:-}"); shift 2 ;;
    --format) FORMAT="${2:-}"; shift 2 ;;
    --quiet)  QUIET=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 2 ;;
esac; done

[[ -n "$JOBS_DIR" ]] || fail "--jobs is required."
[[ -d "$JOBS_DIR" ]] || fail "'${JOBS_DIR}' is not a directory."
[[ "${#PATTERNS[@]}" -gt 0 ]] || fail "give at least one --select."

case "$FORMAT" in
    plan|keys|files) ;;
    *) fail "--format must be plan, keys or files." ;;
esac

command -v yq > /dev/null 2>&1 || fail "'yq' is not installed."

report() {
    [[ "$QUIET" -eq 1 ]] || echo "$*" >&2
}

# ---------------------------------------------------------------------------
# Read every rendered pipeline
# ---------------------------------------------------------------------------

# step key -> job YAML file, from monorepo_lib.sh.
build_step_index "$JOBS_DIR"

if [[ "${#STEP_KEY_TO_FILE[@]}" -eq 0 ]]; then
    fail "no step found in '${JOBS_DIR}'. Render the pipelines first with ./buildkite/scripts/dhall/dump_dhall_to_pipelines.sh"
fi

# step key -> the keys it depends on, separated by spaces.
declare -A STEP_DEPS=()
for key in "${!STEP_KEY_TO_FILE[@]}"; do
    file="${STEP_KEY_TO_FILE[$key]}"
    deps="$(yq -r "[.pipeline.steps[]? | select(.key == \"${key}\") | .depends_on[]?.step] | .[]" "$file" 2>/dev/null | tr '\n' ' ')"
    STEP_DEPS["$key"]="$deps"
done

# The renderer puts "_<JobName>-" in front of every key. Keep the rest, so that
# a pattern may name the step without knowing which job holds it.
short_key() {
    local key="$1"
    if [[ "$key" == _*-* ]]; then
        echo "${key#_*-}"
    else
        echo "$key"
    fi
}

# ---------------------------------------------------------------------------
# Choose
# ---------------------------------------------------------------------------

declare -A CHOSEN=()
declare -A REASON=()

for pattern in "${PATTERNS[@]}"; do
    matched=0
    for key in "${!STEP_KEY_TO_FILE[@]}"; do
        # shellcheck disable=SC2053  # the pattern is meant to be a glob
        if [[ "$key" == $pattern || "$(short_key "$key")" == $pattern ]]; then
            if [[ -z "${CHOSEN[$key]-}" ]]; then
                CHOSEN["$key"]=1
                REASON["$key"]="asked for (${pattern})"
            fi
            matched=1
        fi
    done
    if [[ "$matched" -eq 0 ]]; then
        report "⚠️  no step matches '${pattern}'"
    fi
done

if [[ "${#CHOSEN[@]}" -eq 0 ]]; then
    {
        echo "ERROR: no step matched. These keys exist:"
        for key in "${!STEP_KEY_TO_FILE[@]}"; do
            echo "  $(short_key "$key")"
        done | sort
    } >&2
    exit 1
fi

report "Chosen by name: ${#CHOSEN[@]} step(s)"

# ---------------------------------------------------------------------------
# Add what they depend on
#
# A step that waits for a step which is not in the run set waits for ever, so
# every dependency has to come too, however far away it is. This walks the
# `depends_on` of the rendered pipelines, so it holds for dependencies inside
# one job and between jobs alike.
# ---------------------------------------------------------------------------

declare -a QUEUE=("${!CHOSEN[@]}")
ADDED=0

while [[ "${#QUEUE[@]}" -gt 0 ]]; do
    current="${QUEUE[0]}"
    QUEUE=("${QUEUE[@]:1}")

    for dep in ${STEP_DEPS[$current]-}; do
        [[ -z "$dep" ]] && continue

        if [[ -z "${STEP_KEY_TO_FILE[$dep]-}" ]]; then
            report "⚠️  '${current}' depends on '${dep}', which no rendered job defines"
            continue
        fi

        if [[ -z "${CHOSEN[$dep]-}" ]]; then
            CHOSEN["$dep"]=1
            REASON["$dep"]="needed by ${current}"
            QUEUE+=("$dep")
            ADDED=$((ADDED + 1))
        fi
    done
done

report "Added because they are needed: ${ADDED} step(s)"
report "Run set: ${#CHOSEN[@]} step(s)"

if [[ "$QUIET" -eq 0 ]]; then
    for key in "${!CHOSEN[@]}"; do
        echo "  ${key}  <-  ${REASON[$key]}"
    done | sort >&2
fi

# ---------------------------------------------------------------------------
# Write the run set
# ---------------------------------------------------------------------------

case "$FORMAT" in
    plan)
        for key in "${!CHOSEN[@]}"; do
            printf '%s\t%s\n' "${STEP_KEY_TO_FILE[$key]}" "$key"
        done | sort
        ;;
    keys)
        for key in "${!CHOSEN[@]}"; do echo "$key"; done | sort
        ;;
    files)
        for key in "${!CHOSEN[@]}"; do echo "${STEP_KEY_TO_FILE[$key]}"; done | sort -u
        ;;
esac
