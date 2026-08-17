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
#   --set NAME         An artifact of the product, from
#                      buildkite/src/Constants/Artifact/Sets.dhall (daemon,
#                      archive, rosetta, automode, prefork, all ...). It is only
#                      sugar: it becomes patterns and is then treated the same.
#                      Give it more than once, and mix it with --select.
#   --layer LAYER      docker (default) or debian. It says which side of a set
#                      is wanted: the images it names, or the step that builds
#                      its packages. A set that has nothing on the chosen side
#                      stops the run rather than building nothing.
#   --print-debians    With --set, write the debian package patterns of those
#                      sets and stop. This is the other half of --layer debian,
#                      and it keeps Sets.dhall the only place the names live.
#   --job-include GLOB Choose a step only if the name of its job matches. Use it
#                      for codename and architecture, which are in the job name
#                      and not in the key. Repeatable; one match is enough.
#   --job-exclude GLOB Do not choose a step whose job name matches. Repeatable.
#   --key-include GLOB Choose a step only if its key matches as well. Use it for
#                      the network or the profile. Repeatable; one is enough.
#   --print-segments   Write what network= and profile= may say, and stop.
#   --list-sets        Write the sets that exist and stop.
#   --format FORMAT    plan  (default) one "<file><TAB><step key>" for each step
#                      keys  the step keys only
#                      files the job files only, each one time
#   --quiet            Do not write the report on stderr.
#   -h, --help         Write this text.
#
# The filters are put on the steps that were ASKED for, never on the steps that
# were added because something needs them. Narrowing to one codename must not
# throw away the debian step that the chosen image is built from.
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
LIST_SETS=0
LAYER="docker"
PRINT_DEBIANS=0
PRINT_SEGMENTS=0
declare -a PATTERNS=()
declare -a SETS=()
declare -a JOB_INCLUDE=()
declare -a JOB_EXCLUDE=()
declare -a KEY_INCLUDE=()

SETS_DHALL="${SCRIPT_DIR}/../../src/Constants/Artifact/Sets.dhall"

usage() {
    sed -n '3,64p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

fail() {
    echo "ERROR: $*" >&2
    exit 2
}

while [[ "$#" -gt 0 ]]; do case "$1" in
    --jobs)   JOBS_DIR="${2:-}"; shift 2 ;;
    --select) PATTERNS+=("${2:-}"); shift 2 ;;
    --set)    SETS+=("${2:-}"); shift 2 ;;
    --layer)  LAYER="${2:-}"; shift 2 ;;
    --print-debians) PRINT_DEBIANS=1; shift ;;
    --print-segments) PRINT_SEGMENTS=1; shift ;;
    --job-include) JOB_INCLUDE+=("${2:-}"); shift 2 ;;
    --job-exclude) JOB_EXCLUDE+=("${2:-}"); shift 2 ;;
    --key-include) KEY_INCLUDE+=("${2:-}"); shift 2 ;;
    --list-sets) LIST_SETS=1; shift ;;
    --format) FORMAT="${2:-}"; shift 2 ;;
    --quiet)  QUIET=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 2 ;;
esac; done

case "$LAYER" in
    docker|debian) ;;
    *) fail "--layer must be docker or debian." ;;
esac

# ---------------------------------------------------------------------------
# A set is only a name for some patterns. It is read from the dhall file, so the
# names live in one place and this script holds no copy of them.
# ---------------------------------------------------------------------------

read_sets() {
    command -v dhall-to-json > /dev/null 2>&1 || fail "'dhall-to-json' is not installed, so --set cannot be used."
    [[ -f "$SETS_DHALL" ]] || fail "'${SETS_DHALL}' is not there."
    dhall-to-json <<< "(${SETS_DHALL}).sets" 2>/dev/null \
        || fail "cannot read ${SETS_DHALL}."
}

if [[ "$LIST_SETS" -eq 1 ]]; then
    read_sets | python3 -c '
import json, sys
for s in json.load(sys.stdin):
    print("%-20s %s" % (s["name"], s["description"]))
    print("%-20s   dockers: %s" % ("", " ".join(s["dockers"]) or "(none)"))
    print("%-20s   debians: %s" % ("", " ".join(s["debians"]) or "(none)"))
'
    exit 0
fi

# A set is looked up once. Which of its two sides is read depends on the layer:
# the docker patterns are step keys, and the debian patterns are package tokens
# that only narrow_debian_tokens.py understands, so they leave by another door.
expand_sets() {
    local field="$1"
    local sets_json want found
    sets_json="$(read_sets)"
    for want in "${SETS[@]}"; do
        found="$(echo "$sets_json" | python3 -c "
import json, sys
want, field = sys.argv[1], sys.argv[2]
for s in json.load(sys.stdin):
    if s['name'] == want:
        print('\n'.join(s[field]))
        break
else:
    sys.exit(3)
" "$want" "$field")" || {
            {
                echo "ERROR: there is no set called '${want}'. These exist:"
                echo "$sets_json" | python3 -c "
import json, sys
for s in json.load(sys.stdin):
    print('  %-20s %s' % (s['name'], s['description']))
"
            } >&2
            exit 2
        }
        if [[ -z "$found" ]]; then
            echo "ERROR: the set '${want}' builds no ${field%s} at all. Ask for it in the other layer." >&2
            exit 2
        fi
        while IFS= read -r pattern; do
            [[ -n "$pattern" ]] && echo "$pattern"
        done <<< "$found"
    done
}

if [[ "$PRINT_DEBIANS" -eq 1 ]]; then
    [[ "${#SETS[@]}" -gt 0 ]] || fail "--print-debians needs at least one --set."
    expand_sets debians
    exit 0
fi

if [[ "$PRINT_SEGMENTS" -eq 1 ]]; then
    command -v dhall-to-json > /dev/null 2>&1 || fail "'dhall-to-json' is not installed."
    dhall-to-json <<< "(${SETS_DHALL}).segments" \
        | python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin)))'
    exit 0
fi

if [[ "${#SETS[@]}" -gt 0 ]]; then
    if [[ "$LAYER" == "debian" ]]; then
        # Every package of a pipeline is built by one step, so the debian side of
        # a set does not choose steps. It checks that the set HAS a debian side,
        # and then asks for that one step; the narrowing script cuts the list
        # down afterwards, out of --print-debians.
        expand_sets debians > /dev/null
        PATTERNS+=("build-deb-pkg")
    else
        # Captured, not read through a process substitution: expand_sets stops
        # the run when a set has no docker side, and an exit inside a process
        # substitution would be lost.
        expanded="$(expand_sets dockers)"
        while IFS= read -r pattern; do
            [[ -n "$pattern" ]] && PATTERNS+=("$pattern")
        done <<< "$expanded"
    fi
fi

[[ -n "$JOBS_DIR" ]] || fail "--jobs is required."
[[ -d "$JOBS_DIR" ]] || fail "'${JOBS_DIR}' is not a directory."
[[ "${#PATTERNS[@]}" -gt 0 ]] || fail "give at least one --select or --set."

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

# The name of the job that holds a key: "_MinaArtifactBullseye-archive-..." is
# built by MinaArtifactBullseye. The codename and the architecture are in there
# and nowhere else, which is why they are filtered here and not by a pattern.
job_of() {
    local key="$1"
    key="${key#_}"
    echo "${key%%-*}"
}

# True when a step may be CHOSEN. It says nothing about a step that is added
# afterwards because something needs it.
passes_filters() {
    local key="$1"
    local job pat ok

    job="$(job_of "$key")"

    for pat in "${JOB_EXCLUDE[@]+"${JOB_EXCLUDE[@]}"}"; do
        # shellcheck disable=SC2053  # the pattern is meant to be a glob
        [[ "$job" == $pat ]] && return 1
    done

    if [[ "${#JOB_INCLUDE[@]}" -gt 0 ]]; then
        ok=1
        for pat in "${JOB_INCLUDE[@]}"; do
            # shellcheck disable=SC2053
            [[ "$job" == $pat ]] && { ok=0; break; }
        done
        [[ "$ok" -eq 0 ]] || return 1
    fi

    if [[ "${#KEY_INCLUDE[@]}" -gt 0 ]]; then
        ok=1
        for pat in "${KEY_INCLUDE[@]}"; do
            # shellcheck disable=SC2053
            [[ "$key" == $pat ]] && { ok=0; break; }
        done
        [[ "$ok" -eq 0 ]] || return 1
    fi

    return 0
}

for pattern in "${PATTERNS[@]}"; do
    matched=0
    filtered=0
    for key in "${!STEP_KEY_TO_FILE[@]}"; do
        # shellcheck disable=SC2053  # the pattern is meant to be a glob
        if [[ "$key" == $pattern || "$(short_key "$key")" == $pattern ]]; then
            if passes_filters "$key"; then
                if [[ -z "${CHOSEN[$key]-}" ]]; then
                    CHOSEN["$key"]=1
                    REASON["$key"]="asked for (${pattern})"
                fi
                matched=1
            else
                filtered=1
            fi
        fi
    done
    if [[ "$matched" -eq 0 ]]; then
        if [[ "$filtered" -eq 1 ]]; then
            report "⚠️  '${pattern}' matches steps, but none that the codename, architecture, network or profile allows"
        else
            report "⚠️  no step matches '${pattern}'"
        fi
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
