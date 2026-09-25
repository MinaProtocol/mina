#!/bin/bash
set -euo pipefail

# Defaulted here, not at the exports below: MINA_DOCKER_TAG reads it first, and
# under `set -u` an unset one aborted anything sourcing this script directly.
MINA_DEB_CODENAME=${MINA_DEB_CODENAME:-bookworm}

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

# Reads back exactly the flat, string-valued object write_git_env_file writes.
# Not a JSON parser.
function pinned_git_env_value() {
    sed -n "s/^[[:space:]]*\"$1\"[[:space:]]*:[[:space:]]*\"\(.*\)\"[[:space:]]*,\{0,1\}[[:space:]]*$/\1/p" \
        "${MINA_GIT_ENV_FILE}" | head -1
}

# MINA_GIT_ENV_FILE holds the git facts this script otherwise derives from the
# checkout. It is written beside the binaries so identity travels with them,
# which fixes two things: a tag pushed mid-build no longer gives a build's
# earlier and later jobs different versions, and a packaging job stamps
# GITHASH_CONFIG -- the genesis config the daemon auto-loads -- with the commit
# the binaries were built from rather than its own checkout.
#
# OVERRIDE_TAG and OVERRIDE_GITHASH still win.
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

    # Falling back to the checkout would reintroduce the mismatch the file
    # exists to prevent.
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

# Write the derived facts in the shape read back above, for callers pinning an
# identity for other jobs. See buildkite/scripts/git-env/write_to_cache.sh.
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
export MINA_DEB_CODENAME
export REPO_ROOT