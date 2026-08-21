#!/usr/bin/env bash

# Keep only the wanted debian packages in a pipeline that is about to be
# uploaded.
#
# One step of a job builds every debian package of that job:
#
#     build-from-cache.sh <variant> <token> <token> ...
#     build-release.sh <token> <token> ...          (the job that also compiles)
#
# This reads a pipeline on stdin, cuts that list down to the tokens that match
# the patterns given, and writes the pipeline out again.
#
#     narrow_debian_tokens.sh 'prefork_*' logproc < pipeline.yml > narrowed.yml
#
# A pattern that starts with "!" drops what it matches, whatever else kept it.
# That is how network= narrows packages: asking for devnet keeps the devnet and
# the network-less ones by adding "!*mainnet*".
#
# The token list is written more than once in the same step: once in the `echo
# "-- Running: ..."` line that the log shows, and once in the command that
# really runs. Both are changed, so the log does not say something other than
# what ran.
#
# Nothing else in the pipeline is touched. When no token matches, the run stops:
# building nothing is never what was meant, and a silent empty list would make
# build.sh fall back to building EVERY default package. Nothing is written to
# stdout in that case, so a caller that pipes this into another command cannot
# be given a half narrowed pipeline.
#
# In bash, and not in python, because the CI toolchain image has no python at
# all (Dockerfile-toolchain-base installs bash, curl, git, make, dhall-to-yaml
# and yq, and nothing else). Bash also matches a glob against a word natively,
# which is exactly what a pattern here is.
#
# Exit codes:
#   0  the list was narrowed
#   1  no package list was found, or no package matched
#   2  the arguments are wrong

set -euo pipefail

declare -a KEEP=()
declare -a DROP=()

for pattern in "$@"; do
    if [[ "$pattern" == '!'* ]]; then
        DROP+=("${pattern#!}")
    else
        KEEP+=("$pattern")
    fi
done

if [[ "${#KEEP[@]}" -eq 0 ]]; then
    {
        echo "usage: narrow_debian_tokens.sh PATTERN [PATTERN ...]"
        echo "       a PATTERN starting with ! drops what it matches"
    } >&2
    exit 2
fi

# Every token the input offered, and every token kept, so the caller can be told
# what was dropped and so an empty result can stop the run.
declare -A SEEN=()
declare -A KEPT=()

wanted() {
    local token="$1" pattern
    for pattern in "${DROP[@]+"${DROP[@]}"}"; do
        # shellcheck disable=SC2053  # the pattern is meant to be a glob
        [[ "$token" == $pattern ]] && return 1
    done
    for pattern in "${KEEP[@]}"; do
        # shellcheck disable=SC2053
        [[ "$token" == $pattern ]] && return 0
    done
    return 1
}

# The two shapes of a call. build-from-cache.sh names the tree it restores
# first, because the compile was somewhere else; build-release.sh compiles and
# packages in one step, so it has no variant.
#
# The first group is everything up to the token list -- for build-from-cache.sh
# that includes the variant, and a variant may hold a dash
# (bullseye-instrumented, bullseye-arm64) -- and the second is the token list
# itself. A token is lower case letters, digits and underscores only, so the
# list ends at the first word that is not one: the closing quote, a bracket,
# anything. That is how the two forms of the line (the echo and the real
# command) both end.
CALL_FROM_CACHE='(build-from-cache\.sh[[:space:]]+[A-Za-z0-9_-]+)(([[:space:]]+[a-z0-9_]+)+)'
CALL_RELEASE='(build-release\.sh)(([[:space:]]+[a-z0-9_]+)+)'

# Sets NARROWED to the line with its token list cut down. It assigns rather
# than prints because a command substitution would run it in a subshell, and
# SEEN and KEPT would be thrown away with that subshell.
NARROWED=""

narrow_line() {
    local line="$1" regex head tokens whole before after result
    local -a wanted_tokens
    local token

    for regex in "$CALL_FROM_CACHE" "$CALL_RELEASE"; do
        result=""
        while [[ "$line" =~ $regex ]]; do
            whole="${BASH_REMATCH[0]}"
            head="${BASH_REMATCH[1]}"
            tokens="${BASH_REMATCH[2]}"

            before="${line%%"$whole"*}"
            after="${line#*"$whole"}"

            wanted_tokens=()
            for token in $tokens; do
                SEEN["$token"]=1
                if wanted "$token"; then
                    wanted_tokens+=("$token")
                    KEPT["$token"]=1
                fi
            done

            if [[ "${#wanted_tokens[@]}" -eq 0 ]]; then
                # Leave it alone; the caller stops the run.
                result+="${before}${whole}"
            else
                result+="${before}${head} ${wanted_tokens[*]}"
            fi

            line="$after"
        done
        line="${result}${line}"
    done

    NARROWED="$line"
}

sorted() {
    local -n names="$1"
    local token
    for token in "${!names[@]}"; do echo "$token"; done | sort | tr '\n' ' '
}

# The whole pipeline is held, not streamed, so that a run that has to stop
# writes nothing at all. `|| [[ -n "$line" ]]` keeps a last line that carries no
# newline of its own; that line is written back with one, which YAML does not
# care about.
OUT=""
while IFS= read -r line || [[ -n "$line" ]]; do
    narrow_line "$line"
    OUT+="${NARROWED}"$'\n'
done

if [[ "${#SEEN[@]}" -eq 0 ]]; then
    echo "narrow_debian_tokens.sh: no debian package list was found, so nothing was narrowed." >&2
    exit 1
fi

if [[ "${#KEPT[@]}" -eq 0 ]]; then
    {
        echo "narrow_debian_tokens.sh: no debian package matches ${KEEP[*]}${DROP[*]+", less ${DROP[*]}"}."
        echo "  These are built by this job:"
        for token in "${!SEEN[@]}"; do echo "    ${token}"; done | sort
    } >&2
    exit 1
fi

{
    kept="$(sorted KEPT)"
    echo "narrow_debian_tokens.sh: keeping ${#KEPT[@]} of ${#SEEN[@]} packages (${kept% })"

    declare -A DROPPED=()
    for token in "${!SEEN[@]}"; do
        [[ -z "${KEPT[$token]-}" ]] && DROPPED["$token"]=1
    done
    if [[ "${#DROPPED[@]}" -gt 0 ]]; then
        not_built="$(sorted DROPPED)"
        echo "  not built: ${not_built% }"
    fi
} >&2

printf '%s' "$OUT"
