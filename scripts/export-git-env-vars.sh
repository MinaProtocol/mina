#!/bin/bash
set -euo pipefail

# Defaulted here rather than further down, where it used to be, because
# MINA_DOCKER_TAG is built from it well before that point. Under `set -u` a
# caller that had not set it aborted on the unbound variable instead of
# getting the default the script clearly intends to provide. Every caller
# reached this script through buildkite/scripts/export-git-env-vars.sh, which
# sets it first, so nothing ever ran into it until a script sourced this one
# directly.
MINA_DEB_CODENAME=${MINA_DEB_CODENAME:-bullseye}

# If enabled, keep my tags intact, it won't run git fetch --prune
KEEP_MY_TAGS_INTACT=${KEEP_MY_TAGS_INTACT:-1}

# Explicit warnings for override environment variables
if [[ -v SKIP_GITBRANCH ]]; then
    echo "⚠️  WARNING: SKIP_GITBRANCH is defined - will override GITBRANCH in package version" >&2
fi
if [[ -v OVERRIDE_TAG ]]; then
    echo "⚠️  WARNING: OVERRIDE_TAG is defined - will override GITTAG to '${OVERRIDE_TAG}' in package version" >&2
fi
if [[ -v OVERRIDE_GITHASH ]]; then
    echo "⚠️  WARNING: OVERRIDE_GITHASH is defined - will override GITHASH to '${OVERRIDE_GITHASH}' in package version" >&2
fi

function find_most_recent_numeric_tag() {

    local keep_tags_values=("1" "true" "t" "T" "y" "yes" "Y" "YES")
    if [[ ! " ${keep_tags_values[*]} " =~  ${KEEP_MY_TAGS_INTACT}  ]]; then
        # We use the --prune flag because we've had problems with buildkite agents getting conflicting results here
        git fetch --tags --prune --prune-tags --force
    else
        git fetch --tags --force
    fi
    TAG=$(git describe --always --abbrev=0 $1 | sed 's!/!-!g; s!_!-!g; s!#!-!g')
    if [[ $TAG != [0-9]* ]]; then
        TAG=$(find_most_recent_numeric_tag $TAG~)
    fi
    echo $TAG
}

# Read one string field out of the pinned file. It is deliberately not a JSON
# parser: this reads back exactly the flat, string-valued object that
# write_git_env_file writes, and nothing else.
function pinned_git_env_value() {
    sed -n "s/^[[:space:]]*\"$1\"[[:space:]]*:[[:space:]]*\"\(.*\)\"[[:space:]]*,\{0,1\}[[:space:]]*$/\1/p" \
        "${MINA_GIT_ENV_FILE}" | head -1
}

# MINA_GIT_ENV_FILE names a file holding the git facts this script would
# otherwise derive from the checkout. Two problems go away when it is set.
#
# The first is drift. find_most_recent_numeric_tag runs "git fetch --tags" on
# every call, and this script is sourced by dozens of jobs across a build, so a
# tag pushed while a build is running gives its earlier jobs one version and
# its later jobs another.
#
# The second is worse and is why the file belongs beside the binaries rather
# than beside the build. A packaging job compiles nothing: it takes binaries
# from an app build and wraps them. GITHASH_CONFIG names the genesis config the
# daemon auto-loads (config_<GITHASH_CONFIG>.json, written by
# copy_common_daemon_configs), so it has to be the commit the BINARIES were
# built from. Derived from the packaging job's own checkout it names whatever
# that job happened to have checked out, and the package holds a config its
# daemon will not look for.
#
# So the app build writes this file next to its output and every job that
# consumes that output reads it. Identity travels with the binaries.
#
# The explicit overrides still win, exactly as they do below, so nothing that
# passes OVERRIDE_TAG or OVERRIDE_GITHASH today changes behaviour.
if [[ -n "${MINA_GIT_ENV_FILE:-}" ]]; then
    if [[ ! -r "${MINA_GIT_ENV_FILE}" ]]; then
        echo "❌ MINA_GIT_ENV_FILE is set to '${MINA_GIT_ENV_FILE}', which cannot be read." >&2
        echo "   Unset it to derive the git environment from the checkout instead." >&2
        exit 1
    fi

    echo "Reading the git environment from ${MINA_GIT_ENV_FILE}" >&2

    GITHASH_CONFIG=${OVERRIDE_GITHASH:-$(pinned_git_env_value githash_config)}
    GITHASH=${GITHASH_CONFIG%?}
    GITBRANCH=$(pinned_git_env_value gitbranch)
    GITTAG=${OVERRIDE_TAG:-$(pinned_git_env_value gittag)}
    THIS_COMMIT_TAG=${OVERRIDE_TAG:-$(pinned_git_env_value this_commit_tag)}

    # A field this script needs but the file does not carry is a fault in
    # whoever wrote the file, and silently falling back to the checkout would
    # reintroduce the mismatch the file exists to prevent.
    for __required in GITHASH_CONFIG GITBRANCH GITTAG; do
        if [[ -z "${!__required}" ]]; then
            echo "❌ ${MINA_GIT_ENV_FILE} carries no value for ${__required}." >&2
            exit 1
        fi
    done
    unset __required

    # Not pinned: it is where this checkout is, not what it holds.
    REPO_ROOT="$(git rev-parse --show-toplevel)"
else
    GITHASH_CONFIG=${OVERRIDE_GITHASH:-$(git rev-parse --short=8 --verify HEAD)}
    # Remove last character to get 7-character short hash
    GITHASH=${GITHASH_CONFIG%?}
    THIS_COMMIT_TAG=${OVERRIDE_TAG:-$(git tag --points-at HEAD)}
    REPO_ROOT="$(git rev-parse --show-toplevel)"

    if [[ -v BRANCH_NAME ]]; then
       GITBRANCH=$(echo "$BRANCH_NAME" | sed 's!/!-!g; s!_!-!g; s!#!-!g')
    else
       # Always use actual HEAD for branch resolution — OVERRIDE_GITHASH is a
       # short hash from another commit and git name-rev cannot resolve it.
       _GIT_HEAD_HASH=$(git rev-parse --verify HEAD)
       GITBRANCH=$(git name-rev --name-only "$_GIT_HEAD_HASH" | sed "s/remotes\/origin\///g" | sed 's!/!-!g; s!_!-!g; s!#!-!g' )
    fi

    GITTAG=${OVERRIDE_TAG:-$(find_most_recent_numeric_tag HEAD)}
fi

# Write the git facts this script derived, in the shape it reads back above.
# Callers use it to pin an identity for other jobs; see
# buildkite/scripts/git-env/write_to_cache.sh.
function write_git_env_file() {
    cat > "$1" <<GIT_ENV_JSON
{
  "githash_config": "${GITHASH_CONFIG}",
  "githash": "${GITHASH}",
  "gitbranch": "${GITBRANCH}",
  "gittag": "${GITTAG}",
  "this_commit_tag": "${THIS_COMMIT_TAG}"
}
GIT_ENV_JSON
}


if [[ "${SKIP_GITBRANCH:-0}" == "1" ]]; then
    MINA_DEB_VERSION="${GITTAG}-${GITHASH}"
else
    MINA_DEB_VERSION="${GITTAG}-${GITBRANCH}-${GITHASH}"
fi

MINA_DOCKER_TAG=$(echo "${MINA_DEB_VERSION}-${MINA_DEB_CODENAME}" | sed 's!/!-!g; s!_!-!g')

[[ -v THIS_COMMIT_TAG ]] && export MINA_COMMIT_TAG="${THIS_COMMIT_TAG}"

export GITTAG
export GITHASH
export GITHASH_CONFIG
export GITBRANCH
export MINA_DEB_VERSION
export MINA_DOCKER_TAG
export THIS_COMMIT_TAG
export MINA_DEB_CODENAME=${MINA_DEB_CODENAME:=bullseye}
export REPO_ROOT