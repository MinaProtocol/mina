#!/usr/bin/env bash

# Build only the steps that were asked for.
#
# The pipelines are rendered to YAML, select_steps.sh works out which steps to
# run (the ones named, and everything they depend on), and this script uploads
# those steps only. A job with no chosen step is not uploaded at all.
#
# Usage:
#   run-selection.sh --selection "SET_OR_PATTERN[,...]" --jobs DIR [options]
#
#   --selection LIST   What to build, separated by commas. An item is either the
#                      name of a set (daemon, archive, rosetta, automode,
#                      prefork, logproc, all ... see
#                      buildkite/src/Constants/Artifact/Sets.dhall) or a pattern
#                      for step keys. This is what the author of the comment
#                      wrote, so it is not trusted: every item must match a step,
#                      or the script stops.
#                      Defaults to $BUILDKITE_PIPELINE_SELECTION, which is how
#                      the value reaches a real build.
#   --deb LIST         Patterns for debian package tokens, separated by commas
#                      (prefork_*, logproc, ...). The debian step of a job is
#                      then told to build only the packages that match.
#                      Defaults to $BUILDKITE_PIPELINE_DEB_SELECTION.
#                      See "Narrowing the debian step" below.
#   --layer LAYER      docker (default) or debian. The command says which one:
#                      !ci-docker-me builds images, !ci-debian-me builds
#                      packages. A set is read on that side, and a set with
#                      nothing on it stops the run: prefork makes no image.
#   --codename LIST    bullseye, focal, jammy, noble, bookworm. Comma separated.
#   --arch LIST        amd64, arm64.
#   --network LIST     devnet, mainnet. Comma separated.
#   --profile LIST     devnet, mainnet, lightnet. The same place in a step key
#                      as the network, so the two add up.
#   --instrumented V   true, false (the default) or both. An instrumented build
#                      is a coverage build and is left out until it is asked
#                      for. true builds ONLY the instrumented one.
#   --from BUILD_ID    Take the binaries and the packages from that earlier
#                      build instead of making them again. The steps that would
#                      make them are dropped and the cache is read under that
#                      build's root, so only the images are built.
#   --jobs DIR         Directory of rendered pipelines (buildkite/src/gen)
#   --dry-run          Write what would be uploaded, upload nothing.
#   --debug            Write the pruned pipeline of each job.
#   -h, --help         Write this text.
#
# Every one of these also comes from the environment, which is how a real build
# passes it: BUILDKITE_PIPELINE_LAYER, _CODENAME, _ARCH, _NETWORK, _PROFILE,
# _FROM_BUILD, _INSTRUMENTED.
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
NARROW_DEBS="${SCRIPT_DIR}/../pipeline/narrow_debian_tokens.sh"

# The patterns come from a pull request comment, so they travel in the
# environment and never in a dhall expression. Prepare.dhall puts the value of
# BUILDKITE_PIPELINE_SELECTION into a dhall expression for nothing else, and
# dhall can read the environment, so a value that closed the quote would run on
# the agent. A flag still wins, which is what the tests and a hand run use.
SELECTION="${BUILDKITE_PIPELINE_SELECTION:-}"
DEB_SELECTION="${BUILDKITE_PIPELINE_DEB_SELECTION:-}"
LAYER="${BUILDKITE_PIPELINE_LAYER:-docker}"
CODENAMES="${BUILDKITE_PIPELINE_CODENAME:-}"
ARCHS="${BUILDKITE_PIPELINE_ARCH:-}"
NETWORKS="${BUILDKITE_PIPELINE_NETWORK:-}"
PROFILES="${BUILDKITE_PIPELINE_PROFILE:-}"
INSTRUMENTED="${BUILDKITE_PIPELINE_INSTRUMENTED:-false}"
FROM_BUILD="${BUILDKITE_PIPELINE_FROM_BUILD:-}"
JOBS_DIR=""
DRY_RUN=false
DEBUG=false

usage() {
    sed -n '3,46p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

fail() {
    echo "ERROR: $*" >&2
    exit 2
}

while [[ "$#" -gt 0 ]]; do case "$1" in
    --selection) SELECTION="${2:-}"; shift 2 ;;
    --deb)       DEB_SELECTION="${2:-}"; shift 2 ;;
    --layer)     LAYER="${2:-}"; shift 2 ;;
    --codename)  CODENAMES="${2:-}"; shift 2 ;;
    --arch)      ARCHS="${2:-}"; shift 2 ;;
    --network)   NETWORKS="${2:-}"; shift 2 ;;
    --profile)   PROFILES="${2:-}"; shift 2 ;;
    --instrumented) INSTRUMENTED="${2:-}"; shift 2 ;;
    --from)      FROM_BUILD="${2:-}"; shift 2 ;;
    --jobs)      JOBS_DIR="${2:-}"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    --debug)     DEBUG=true; shift ;;
    -h|--help)   usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 2 ;;
esac; done

case "$LAYER" in
    docker|debian) ;;
    *) fail "--layer must be docker or debian." ;;
esac

if [[ -z "$SELECTION" && -n "$DEB_SELECTION" ]]; then
    # Asking for packages means asking for the step that builds them.
    SELECTION="build-deb-pkg"
fi

if [[ -z "$SELECTION" ]]; then
    # This entrypoint is reached only by an ARTIFACT pipeline, which is started
    # by someone who typed !ci-docker-me or !ci-debian-me. Naming nothing means
    # the whole layer -- there is no triage here to fall back on, and building
    # nothing is not what the comment asked for.
    SELECTION="all"
    echo "--- Nothing was named, so every ${LAYER} artifact is built"
fi

# Splits "a, b,c" into SPLIT, without the spaces and without the empty items.
split_list() {
    local raw="$1" item
    local -a parts=()
    IFS=',' read -ra parts <<< "$raw"
    SPLIT=()
    for item in "${parts[@]+"${parts[@]}"}"; do
        item="$(echo "$item" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        if [[ -n "$item" ]]; then
            SPLIT+=("$item")
        fi
    done
    # An empty last item must not make this return 1, which under `set -e`
    # would stop the whole run without saying anything.
    return 0
}

[[ -n "$SELECTION" ]] || fail "--selection or --deb is required."
[[ -n "$JOBS_DIR" ]] || fail "--jobs is required."
[[ -d "$JOBS_DIR" ]] || fail "'${JOBS_DIR}' is not a directory."
[[ -x "$SELECT_STEPS" ]] || fail "'${SELECT_STEPS}' is not there."
command -v yq > /dev/null 2>&1 || fail "'yq' is not installed."

# ---------------------------------------------------------------------------
# Work out the run set
# ---------------------------------------------------------------------------

# The names of the sets, so that a word which names one is passed as a set and
# not as a pattern. A set name holds no star and matches no step key, so the two
# cannot be confused; an unknown name is a pattern, and select_steps.sh then
# stops on it because it matches nothing.
# A failure here used to be swallowed whole: the output went to /dev/null and
# `set -euo pipefail` then stopped the script with no message and status 1,
# which is how a binary missing from the CI image looked like nothing at all.
if ! sets_listing="$("$SELECT_STEPS" --list-sets 2>&1)"; then
    echo "ERROR: the sets could not be read, so a selection cannot be understood:" >&2
    printf '%s\n' "$sets_listing" >&2
    exit 2
fi

KNOWN_SETS=" $(printf '%s\n' "$sets_listing" | grep -E '^[a-z]' | awk '{print $1}' | tr '\n' ' ') "

declare -a SELECT_ARGS=(--layer "$LAYER")
declare -a NAMED_SETS=()
split_list "$SELECTION"
for pattern in "${SPLIT[@]+"${SPLIT[@]}"}"; do
    if [[ "$KNOWN_SETS" == *" ${pattern} "* ]]; then
        SELECT_ARGS+=(--set "$pattern")
        NAMED_SETS+=("$pattern")
    else
        SELECT_ARGS+=(--select "$pattern")
    fi
done

[[ "${#SELECT_ARGS[@]}" -gt 1 ]] || fail "--selection holds no pattern."

# ---------------------------------------------------------------------------
# Where to build it
#
# The codename and the architecture are in the NAME of a job, and the network
# and the profile are in the middle of a step KEY, so the two are filtered in
# different places. Everything given is joined with OR, which is what
# network=[devnet,mainnet] means.
# ---------------------------------------------------------------------------

capitalise() { echo "$(tr '[:lower:]' '[:upper:]' <<< "${1:0:1}")${1:1}"; }

# Each axis is ONE group, so the alternatives inside it are ORed and the axes
# are ANDed: codename=bookworm arch=arm64 is the arm64 build of bookworm, not
# everything that is either.
group=""
split_list "$CODENAMES"
for item in "${SPLIT[@]+"${SPLIT[@]}"}"; do
    group="${group:+${group},}*$(capitalise "$item")*"
done
[[ -n "$group" ]] && SELECT_ARGS+=(--job-include "$group")

group=""
split_list "$ARCHS"
for item in "${SPLIT[@]+"${SPLIT[@]}"}"; do
    case "$item" in
        arm64) group="${group:+${group},}*Arm64*" ;;
        # No job name says amd64; the ones that are not arm64 are amd64. Asking
        # for both is asking for no filter at all.
        amd64) group="${group:+${group},}*" ;;
        *) fail "--arch must be amd64 or arm64, not '${item}'." ;;
    esac
done
if [[ -n "$group" ]]; then
    if [[ "$group" == "*" ]]; then
        SELECT_ARGS+=(--job-exclude '*Arm64*')
    else
        SELECT_ARGS+=(--job-include "$group")
    fi
fi

# An instrumented build is a coverage build. It is never what is wanted unless
# it is asked for, so it is left out until instrumented=true says otherwise.
case "$INSTRUMENTED" in
    true|yes|1)  SELECT_ARGS+=(--job-include '*Instrumented*') ;;
    false|no|0)  SELECT_ARGS+=(--job-exclude '*Instrumented*') ;;
    both|any)    ;;
    *) fail "--instrumented must be true, false or both, not '${INSTRUMENTED}'." ;;
esac

group=""
split_list "${NETWORKS},${PROFILES}"
declare -a WANTED_NETWORKS=()
for item in "${SPLIT[@]+"${SPLIT[@]}"}"; do
    group="${group:+${group},}*-${item}-*"
    WANTED_NETWORKS+=("$item")
done
# Only an image key carries the network. One step builds every package of a job
# and its key is just "build-deb-pkg", so filtering the key in the debian layer
# would throw that step away; there the network narrows the token list instead.
if [[ -n "$group" && "$LAYER" == "docker" ]]; then
    SELECT_ARGS+=(--key-include "$group")
fi

# ---------------------------------------------------------------------------
# Which packages
#
# In the debian layer the set names packages, not steps, so the token list comes
# out of the same Sets.dhall by the other door.
# ---------------------------------------------------------------------------

if [[ "$LAYER" == "debian" && "${#NAMED_SETS[@]}" -gt 0 && -z "$DEB_SELECTION" ]]; then
    declare -a set_args=()
    for name in "${NAMED_SETS[@]}"; do set_args+=(--set "$name"); done
    DEB_SELECTION="$("$SELECT_STEPS" --print-debians "${set_args[@]}" | paste -sd, -)"
    [[ -n "$DEB_SELECTION" ]] || fail "the sets ${NAMED_SETS[*]} name no debian package."
fi

# A package token carries its network in its name (archive_devnet), so asking
# for one network drops the packages of the others. The network-less packages
# (archive_generic) are kept: a networked one is built on top of them.
if [[ -n "$DEB_SELECTION" && "${#WANTED_NETWORKS[@]}" -gt 0 ]]; then
    while IFS= read -r segment; do
        [[ -z "$segment" ]] && continue
        wanted=false
        for want in "${WANTED_NETWORKS[@]}"; do
            [[ "$want" == "$segment" ]] && { wanted=true; break; }
        done
        [[ "$wanted" == true ]] || DEB_SELECTION="${DEB_SELECTION},!*${segment}*"
    done < <("$SELECT_STEPS" --print-segments)
fi

if [[ "${#NAMED_SETS[@]}" -gt 0 ]]; then
    echo "--- Asked for: ${NAMED_SETS[*]}  (layer: ${LAYER})"
fi

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

# With --from, the binaries and the packages of that build are in the cache
# already, so the steps that would make them again are dropped. The images are
# then built from what that build left behind, and nothing is compiled at all.
#
# This is the one place a step is taken OUT of the run set on purpose, which is
# why the dangling check below has to be told about it.
declare -A DROPPED=()
if [[ -n "$FROM_BUILD" ]]; then
    while IFS=$'\t' read -r _ key; do
        case "$key" in
            *-build-apps|*-build-deb-pkg) DROPPED["$key"]=1 ;;
        esac
    done < "$PLAN_FILE"
fi

# job file -> the keys of its chosen steps, separated by spaces
declare -A JOB_STEPS=()
while IFS=$'\t' read -r file key; do
    [[ -z "$file" || -z "$key" ]] && continue
    [[ -n "${DROPPED[$key]-}" ]] && continue
    JOB_STEPS["$file"]="${JOB_STEPS[$file]-} ${key}"
done < "$PLAN_FILE"

if [[ -n "$FROM_BUILD" ]]; then
    if [[ "${#DROPPED[@]}" -eq 0 ]]; then
        echo " !  nothing to take from build ${FROM_BUILD}: this run compiles and packages nothing anyway" >&2
    else
        echo "--- Taking the binaries and the packages from build ${FROM_BUILD}"
        echo "    dropped: ${!DROPPED[*]}"
    fi
fi

[[ "${#JOB_STEPS[@]}" -gt 0 ]] || fail "the run set is empty."

# Every key of the run set, to check the dependencies against.
ALL_KEYS=" $(cut -f2 "$PLAN_FILE" | tr '\n' ' ') "

echo "--- Run set: $(cut -f2 "$PLAN_FILE" | wc -l) step(s) in ${#JOB_STEPS[@]} job(s)"

# ---------------------------------------------------------------------------
# Keep only the chosen steps of each job, and upload
# ---------------------------------------------------------------------------

UPLOADED=0
NARROWED_JOBS=0
NARROWING_ASKED=false

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

    # A step dropped by --from is not coming, so nothing may wait for it, and
    # the cache root of the build it IS coming from has to reach the step that
    # reads it. Both are done on the uploaded YAML rather than in the renderer,
    # so a normal build renders exactly what it rendered before.
    if [[ -n "$FROM_BUILD" ]]; then
        for key in "${!DROPPED[@]}"; do
            pruned="$(echo "$pruned" \
                | yq -o=yaml ".steps |= map(.depends_on |= (. // [] | map(select(.step != \"${key}\"))))")"
        done
        # A step left waiting for nothing keeps an empty list, which reads as if
        # something had been forgotten. Take it off.
        pruned="$(echo "$pruned" \
            | yq -o=yaml 'del(.steps[] | select(.depends_on != null and (.depends_on | length) == 0) | .depends_on)')"
        pruned="$(echo "$pruned" \
            | yq -o=yaml ".steps |= map(.env.MINA_READ_CACHE_ROOT = \"${FROM_BUILD}\")")"
    fi

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
            NARROWING_ASKED=true
            declare -a deb_patterns=()
            IFS=',' read -ra raw_debs <<< "$DEB_SELECTION"
            for d in "${raw_debs[@]}"; do
                d="$(echo "$d" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
                [[ -n "$d" ]] && deb_patterns+=("$d")
            done

            # Not every job builds every package: MinaArtifactOnlyDebianNoble
            # builds a subset, and a codename may carry packages another does
            # not. A job with none of the wanted packages is left out, and the
            # run stops only if NO job had any -- which is what a mistyped name
            # looks like.
            if ! narrowed="$(echo "$pruned" | "$NARROW_DEBS" "${deb_patterns[@]}")"; then
                echo " !  ${job_name}: left out, it builds none of ${DEB_SELECTION}" >&2
                continue
            fi
            pruned="$narrowed"
            NARROWED_JOBS=$((NARROWED_JOBS + 1))
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

if [[ "$NARROWING_ASKED" == true && "$NARROWED_JOBS" -eq 0 ]]; then
    echo "ERROR: no job builds any of these debian packages: ${DEB_SELECTION}" >&2
    exit 1
fi

if [[ "$DRY_RUN" == true ]]; then
    echo "--- Dry run: nothing was uploaded."
else
    echo "--- Uploaded ${UPLOADED} job(s)."
fi
