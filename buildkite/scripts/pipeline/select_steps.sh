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
#   --job-include LIST Choose a step only if the name of its job matches. Use it
#                      for the codename, the architecture and the build flags,
#                      which are in the job name and not in the key.
#                      LIST is one or more globs separated by commas.
#   --job-exclude LIST Do not choose a step whose job name matches any of these.
#   --key-include LIST Choose a step only if its key matches as well. Use it for
#                      the network or the profile.
#
# ONE FLAG IS ONE AXIS. Inside a flag the globs are alternatives (bullseye OR
# jammy); between two flags they must BOTH hold (bullseye AND arm64). Passing
# the codename and the architecture as two flags is therefore what a developer
# means by "the arm64 build of bookworm", and not "anything bookworm or arm64".
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
#
# dhall-to-yaml and yq, and not dhall-to-json and python3: those two are what
# the CI toolchain image HAS. Dockerfile-toolchain-base takes only
# ./bin/dhall-to-yaml out of the dhall-json release and installs no python, so a
# selection that needed either died in the container with no message at all.
# Every other script that runs there reads yaml with yq already.
#
# One line per set, taken apart in bash: yq gathers the results of a comma by
# expression and not by item, so asking it for three lines per set interleaves
# them wrongly.
# ---------------------------------------------------------------------------

SETS_FIELDS='.[] | .name + "|" + .description + "|" + (.dockers | join(" ")) + "|" + (.debians | join(" "))'

read_sets() {
    command -v dhall-to-yaml > /dev/null 2>&1 || fail "'dhall-to-yaml' is not installed, so --set cannot be used."
    command -v yq > /dev/null 2>&1 || fail "'yq' is not installed, so --set cannot be used."
    [[ -f "$SETS_DHALL" ]] || fail "'${SETS_DHALL}' is not there."
    dhall-to-yaml <<< "(${SETS_DHALL}).sets" | yq -r "$SETS_FIELDS" \
        || fail "cannot read ${SETS_DHALL}."
}

# The name and the description of every set, for a message.
sets_summary() {
    local name description rest
    while IFS='|' read -r name description rest; do
        [[ -z "$name" ]] && continue
        printf '  %-20s %s\n' "$name" "$description"
    done
}

if [[ "$LIST_SETS" -eq 1 ]]; then
    read_sets | while IFS='|' read -r name description dockers debians; do
        [[ -z "$name" ]] && continue
        printf '%-20s %s\n' "$name" "$description"
        printf '%-20s   dockers: %s\n' "" "${dockers:-(none)}"
        printf '%-20s   debians: %s\n' "" "${debians:-(none)}"
    done
    exit 0
fi

# A set is looked up once. Which of its two sides is read depends on the layer:
# the docker patterns are step keys, and the debian patterns are package tokens
# that only the narrowing script understands, so they leave by another door.
expand_sets() {
    local field="$1"
    local sets_text want line found
    sets_text="$(read_sets)"

    for want in "${SETS[@]}"; do
        line=""
        while IFS='|' read -r name description dockers debians; do
            [[ -z "$name" ]] && continue
            if [[ "$name" == "$want" ]]; then
                line="${name}|${description}|${dockers}|${debians}"
                break
            fi
        done <<< "$sets_text"
        if [[ -z "$line" ]]; then
            {
                echo "ERROR: there is no set called '${want}'. These exist:"
                printf '%s\n' "$sets_text" | sets_summary
            } >&2
            exit 2
        fi

        case "$field" in
            dockers) found="$(printf '%s' "$line" | cut -d'|' -f3)" ;;
            debians) found="$(printf '%s' "$line" | cut -d'|' -f4)" ;;
            *) fail "unknown side of a set: ${field}" ;;
        esac

        if [[ -z "$found" ]]; then
            echo "ERROR: the set '${want}' builds no ${field%s} at all. Ask for it in the other layer." >&2
            exit 2
        fi

        tr ' ' '\n' <<< "$found" | while IFS= read -r pattern; do
            [[ -n "$pattern" ]] && echo "$pattern"
        done
    done
}

if [[ "$PRINT_DEBIANS" -eq 1 ]]; then
    [[ "${#SETS[@]}" -gt 0 ]] || fail "--print-debians needs at least one --set."
    expand_sets debians
    exit 0
fi

if [[ "$PRINT_SEGMENTS" -eq 1 ]]; then
    command -v dhall-to-yaml > /dev/null 2>&1 || fail "'dhall-to-yaml' is not installed."
    command -v yq > /dev/null 2>&1 || fail "'yq' is not installed."
    dhall-to-yaml <<< "(${SETS_DHALL}).segments" | yq -r '.[]'
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
# True when SUBJECT matches any of the comma separated globs in GROUP.
matches_any() {
    local subject="$1" group="$2" pat
    local -a alternatives=()
    IFS=',' read -ra alternatives <<< "$group"
    for pat in "${alternatives[@]+"${alternatives[@]}"}"; do
        [[ -z "$pat" ]] && continue
        # shellcheck disable=SC2053  # the pattern is meant to be a glob
        if [[ "$subject" == $pat ]]; then
            return 0
        fi
    done
    return 1
}

# True when a step may be CHOSEN: it must match at least one alternative of
# EVERY include group, and no alternative of any exclude group.
passes_filters() {
    local key="$1"
    local job group

    job="$(job_of "$key")"

    for group in "${JOB_EXCLUDE[@]+"${JOB_EXCLUDE[@]}"}"; do
        matches_any "$job" "$group" && return 1
    done

    for group in "${JOB_INCLUDE[@]+"${JOB_INCLUDE[@]}"}"; do
        matches_any "$job" "$group" || return 1
    done

    for group in "${KEY_INCLUDE[@]+"${KEY_INCLUDE[@]}"}"; do
        matches_any "$key" "$group" || return 1
    done

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
