#!/bin/bash

# Refuse to release a commit that is not tagged.
#
# The version a build stamps comes from find_most_recent_numeric_tag in
# scripts/export-git-env-vars.sh, which walks BACKWARDS until it finds a
# numeric tag. Every commit therefore gets a version, derived from the release
# it follows. That is correct for pull-request and nightly builds.
#
# For a release build it is a trap. Building an untagged commit does not fail:
# it quietly reuses the PREVIOUS release's tag and produces, say,
# 4.0.0-<a-different-hash> — a package that claims a release it is not. With
# SKIP_GITBRANCH=1 there is not even a branch segment left to tell the two
# apart.
#
# So a pipeline that publishes runs this first, as its own step, and stops
# there instead of discovering the problem forty minutes later inside
# packaging — or not discovering it at all.
#
# This is a check, not a source of values. It sets nothing and exports
# nothing; export-git-env-vars.sh stays a script about git facts and the
# version derived from them.

set -euo pipefail

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

CLEAR='\033[0m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'

# Sourced for GITTAG / GITHASH / GITHASH_CONFIG, so the tag logic and the
# `git fetch --tags` it performs live in exactly one place. Nothing here
# recomputes them.
# shellcheck disable=SC1090,SC1091
source "${SCRIPTPATH}/../export-git-env-vars.sh"

# Rehearsal escape hatch.
#
# A pipeline being tried out on a branch has no release tag on it, and this
# check is the first thing that runs, so nothing downstream can be exercised
# until it passes. MINA_RELEASE_ALLOW_UNTAGGED=1 turns the refusal into a
# warning so the rest of the pipeline can be rehearsed.
#
# It says loudly what it costs, because the cost is easy to forget: the
# version still falls back to the most recent tag reachable from HEAD, so the
# packages this build produces claim a release they are not. That is tolerable
# in a throwaway channel and is exactly the mislabelling this check exists to
# stop everywhere else. It must never be set on a pipeline that publishes to
# alpha, beta or stable.
if [[ "${MINA_RELEASE_ALLOW_UNTAGGED:-0}" == "1" ]]; then
    echo -e "${YELLOW}⚠️  MINA_RELEASE_ALLOW_UNTAGGED is set: the tag check is a warning.${CLEAR}" >&2
    echo "    Version would be ${GITTAG}-${GITHASH}, taken from the most recent" >&2
    echo "    tag reachable from HEAD rather than from a tag on this commit." >&2
    echo "    Packages built here claim a release they are not. Rehearsal only." >&2
    exit 0
fi

if [[ -n "${OVERRIDE_TAG:-}" ]]; then
    echo -e "${RED}❌ ERROR: OVERRIDE_TAG is set (${OVERRIDE_TAG}).${CLEAR}" >&2
    echo "" >&2
    echo "    A release version is read from the repository, never asserted." >&2
    echo "    OVERRIDE_TAG makes the package version independent of what is" >&2
    echo "    actually tagged, which is the exact confusion this check exists" >&2
    echo "    to prevent. Tag the commit instead." >&2
    exit 1
fi

# `git tag --points-at HEAD` must run AFTER export-git-env-vars.sh, not
# before: find_most_recent_numeric_tag is what performs `git fetch --tags`,
# and on a fresh CI clone a read before it sees no tags at all and would
# reject a properly tagged commit.
HEAD_TAGS=$(git tag --points-at HEAD)

if [[ -z "${HEAD_TAGS}" ]]; then
    echo -e "${RED}❌ ERROR: HEAD (${GITHASH_CONFIG}) carries no git tag.${CLEAR}" >&2
    echo "" >&2
    echo "    This pipeline publishes, so the version must come from a tag on" >&2
    echo "    the commit being built. Without one the version falls back to the" >&2
    echo "    most recent tag reachable from HEAD (${GITTAG}), producing" >&2
    echo "    ${GITTAG}-${GITHASH}: a package that claims a release it is not." >&2
    echo "" >&2
    echo "    Tag the commit you mean to release, then build that commit." >&2
    echo "    Use an ANNOTATED tag: find_most_recent_numeric_tag calls" >&2
    echo "    git describe without --tags, so a lightweight tag is invisible to" >&2
    echo "    the version derivation even though git tag --points-at sees it." >&2
    echo "" >&2
    echo "        git tag -a <version> -m <version> ${GITHASH_CONFIG}" >&2
    echo "        git push origin <version>" >&2
    exit 1
fi

# An annotated tag is a tag object; a lightweight tag points straight at the
# commit. Only the first is visible to the version derivation, so a HEAD
# carrying only lightweight tags would pass the check above and still be
# versioned from an older release.
ANNOTATED=""
while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    if [[ "$(git cat-file -t "$tag" 2>/dev/null)" == "tag" ]]; then
        ANNOTATED="${ANNOTATED:+${ANNOTATED} }${tag}"
    fi
done <<< "${HEAD_TAGS}"

if [[ -z "${ANNOTATED}" ]]; then
    echo -e "${RED}❌ ERROR: HEAD is tagged, but only with lightweight tags.${CLEAR}" >&2
    echo "" >&2
    echo "    Tags on HEAD: ${HEAD_TAGS//$'\n'/ }" >&2
    echo "    find_most_recent_numeric_tag calls git describe without --tags," >&2
    echo "    so none of these are visible to the version derivation and the" >&2
    echo "    build would still be versioned ${GITTAG}-${GITHASH}." >&2
    echo "" >&2
    echo "        git tag -a <version> -m <version> ${GITHASH_CONFIG}" >&2
    exit 1
fi

# The version derivation must actually have chosen a tag from HEAD. If GITTAG
# is some older tag, the two checks above passed and the build would still be
# mislabelled — for example when HEAD's only annotated tag is non-numeric and
# find_most_recent_numeric_tag walked past it.
if [[ " ${ANNOTATED} " != *" ${GITTAG} "* ]]; then
    echo -e "${RED}❌ ERROR: the version would not come from HEAD's tag.${CLEAR}" >&2
    echo "" >&2
    echo "    Annotated tags on HEAD: ${ANNOTATED}" >&2
    echo "    Tag the version derivation chose: ${GITTAG}" >&2
    echo "" >&2
    echo "    find_most_recent_numeric_tag only accepts a tag that starts with" >&2
    echo "    a digit, and walks backwards past any that does not. The build" >&2
    echo "    would be versioned ${GITTAG}-${GITHASH}." >&2
    exit 1
fi

echo -e "${GREEN}✅ Release commit check passed${CLEAR}"
echo "    Commit:  ${GITHASH_CONFIG}"
echo "    Tag:     ${GITTAG}"
echo "    Version: ${MINA_DEB_VERSION}"
