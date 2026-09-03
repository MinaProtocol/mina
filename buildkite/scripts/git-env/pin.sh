#!/usr/bin/env bash

# Fix one git identity for this whole build, before any job that needs one runs.
#
# Every job that sources export-git-env-vars.sh otherwise derives GITHASH,
# GITTAG and GITBRANCH for itself, from its own checkout, at its own moment.
# Two things go wrong with that.
#
# The identity can change under a running build. find_most_recent_numeric_tag
# does "git fetch --tags" on every call, so a tag pushed while a build is in
# flight gives its earlier jobs one version and its later jobs another.
#
# And for a packaging-only pipeline the identity is simply the wrong one. Such
# a build compiles nothing: it takes binaries from an app build and wraps them.
# GITHASH_CONFIG names the genesis config the daemon auto-loads
# (config_<GITHASH_CONFIG>.json, written into the package by
# copy_common_daemon_configs), so it has to name the commit the BINARIES came
# from. Derived from the wrapping job's checkout it names something else, and
# the package holds a config its own daemon will not look for.
#
# So this runs once, in the prepare step, before the triage step uploads any
# real job -- which is what makes it a barrier rather than a race. It resolves
# the identity in this order:
#
#   1. already pinned for this build     a later stage upload of the same build
#   2. MINA_APPS_CACHE_ROOT              inherit the app build being wrapped
#   3. MINA_READ_CACHE_ROOT, or          inherit the build being published, or
#      BUILDKITE_PIPELINE_FROM_BUILD     the one an artifact run was told to
#                                        take its binaries and packages from
#   4. this checkout                     this build compiles its own binaries
#
# and writes the result into this build's own root. Every reader then looks in
# one place, its own root, and no reader has to know where the binaries came
# from.
#
# Usage: pin.sh

set -euo pipefail

CLEAR='\033[0m'
RED='\033[0;31m'

GIT_ENV_CACHE_PATH="git-env.json"

# --from on an artifact run means "take the binaries and the packages from that
# build", which makes that build's commit the one to describe. It arrives as
# BUILDKITE_PIPELINE_FROM_BUILD and run-selection.sh puts it on every step it
# uploads as MINA_READ_CACHE_ROOT, so the two mean the same thing here and an
# explicit MINA_READ_CACHE_ROOT wins.
#
# Resolved in this script rather than by the caller so that every entrypoint
# gets it without having to know, and so no pipeline definition has to spell a
# shell expansion through Dhall's escaping.
FROM_BUILD="${MINA_READ_CACHE_ROOT:-${BUILDKITE_PIPELINE_FROM_BUILD:-}}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

function already_pinned () {
  ./buildkite/scripts/cache/manager.sh read \
    --root "${BUILDKITE_BUILD_ID}" "$GIT_ENV_CACHE_PATH" "$TMP_DIR" >/dev/null 2>&1
}

function publish () {
  echo "--- Pinning the git environment of this build"
  cat "$1"
  ./buildkite/scripts/cache/manager.sh write --override "$1" "$GIT_ENV_CACHE_PATH"
}

# Take the identity of the build whose output this one is wrapping. Its absence
# is fatal on purpose: we know the binaries came from somewhere else, so
# deriving from this checkout would describe the wrong commit -- quietly, and
# in the one field that decides whether the package works.
function inherit_from () {
  local __root="$1" __why="$2"

  echo "--- Taking the git environment from ${__why} (${__root})"

  if ! ./buildkite/scripts/cache/manager.sh read \
        --root "${__root}" "$GIT_ENV_CACHE_PATH" "$TMP_DIR" >/dev/null 2>&1; then
    echo -e "${RED}❌ Build ${__root} has no ${GIT_ENV_CACHE_PATH}.${CLEAR}" >&2
    echo "   ${__why} is ${__root}, so this build must describe that build's" >&2
    echo "   commit and not its own checkout. Re-run the app build to pin one," >&2
    echo "   or set OVERRIDE_GITHASH and OVERRIDE_TAG to say what it was." >&2
    exit 1
  fi

  publish "${TMP_DIR}/${GIT_ENV_CACHE_PATH}"
}

if already_pinned; then
  echo "--- This build is already pinned"
  cat "${TMP_DIR}/${GIT_ENV_CACHE_PATH}"
  exit 0
fi

if [[ -n "${MINA_APPS_CACHE_ROOT:-}" ]]; then
  inherit_from "${MINA_APPS_CACHE_ROOT}" "the app build being packaged"
elif [[ -n "${FROM_BUILD}" ]]; then
  inherit_from "${FROM_BUILD}" "the build this one takes its artifacts from"
else
  # This build compiles its own binaries, so its checkout is the answer.
  # shellcheck disable=SC1090,SC1091
  source ./buildkite/scripts/export-git-env-vars.sh

  LOCAL_FILE="${TMP_DIR}/${GIT_ENV_CACHE_PATH}"
  write_git_env_file "$LOCAL_FILE"
  publish "$LOCAL_FILE"
fi
