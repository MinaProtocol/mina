#!/bin/bash

# Reject a release variable that is set to something Dhall will quietly ignore.
#
# MINA_RELEASE_DOCKER_REPO, MINA_RELEASE_DOCKER_MIRROR, MINA_RELEASE_DEBIAN_REPO
# and MINA_RELEASE_DEBIAN_MIRROR carry Dhall values, and the expressions that read
# them end in `? None` so that an unset variable means "use what the job
# declares" (or, for a mirror, "no second target"). That fallback cannot tell
# "unset" from "set to something that does not resolve", because Dhall
# collapses both into the same None:
#
#   '< Internal | InternalEurope | Public >.Public'  -> Some .Public
#   '< Internal | InternalEurope | Public >.Pubic'   -> None   (typo)
#   'Public'                                         -> None   (plain word)
#   'docker.io/minaprotocol'                         -> None   (address)
#
# So a release asking for docker.io, with one letter wrong, pushes its images
# to the internal registry instead and the build stays green. The wrong
# direction is at least the safe one -- a typo always falls back to the job
# default, which is internal, never public -- but "the images never reached
# docker.io and nothing said so" is the kind of quiet failure this pipeline is
# meant to be free of. The debian variables are the same story: a typo in the
# mirror publishes to one repository and says nothing about the second.
#
# Dhall cannot make the difference itself: it has no Text equality, so the
# variable cannot be matched against a list of accepted spellings there. Here
# it can. The same goes for a mirror that names the primary: Dhall would
# render two publishes of the same files to the same place.

set -euo pipefail

CLEAR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'

DOCKER_UNION='< Internal | InternalEurope | Public >'
DOCKER_ACCEPTED=(
  "${DOCKER_UNION}.Internal"
  "${DOCKER_UNION}.InternalEurope"
  "${DOCKER_UNION}.Public"
)

DEBIAN_UNION='< Unstable | Nightly | Stable | O1Test >'
DEBIAN_ACCEPTED=(
  "${DEBIAN_UNION}.Unstable"
  "${DEBIAN_UNION}.Nightly"
  "${DEBIAN_UNION}.Stable"
  "${DEBIAN_UNION}.O1Test"
)

# What the packaging jobs declare (Command/MinaArtifact.dhall,
# PackagingSpec.docker_repo) and what the publish job pushes to
# (Jobs/Release/PublishDockers.dhall) when MINA_RELEASE_DOCKER_REPO is unset.
DOCKER_DEFAULT="${DOCKER_UNION}.InternalEurope"

# What Jobs/Release/PublishDebians.dhall declares, and so where the packages
# go when MINA_RELEASE_DEBIAN_REPO is unset.
DEBIAN_DEFAULT="${DEBIAN_UNION}.O1Test"

# reject <variable> <value> <what went wrong> <accepted>...
reject() {
  local name="$1" value="$2" why="$3" accepted
  shift 3
  echo -e "${RED}❌ ${name} is set to a value Dhall will ignore.${CLEAR}" >&2
  echo "" >&2
  echo "    got:      ${value}" >&2
  echo "    problem:  ${why}" >&2
  echo "" >&2
  echo "    expected an alternative spelled exactly as one of:" >&2
  for accepted in "$@"; do
    echo "      ${accepted}" >&2
  done
  echo "" >&2
  echo "    Anything else resolves to nothing, and the expression that reads it" >&2
  echo "    cannot tell that from the variable being unset. The build would have" >&2
  echo "    gone green with every job keeping the target it declares rather" >&2
  echo "    than the one asked for here." >&2
  exit 1
}

# check <variable> <accepted>...: the variable is unset, or exactly one of the
# accepted spellings. Unset is a real answer: every job keeps the target it
# declares, which is what nightly and pull request CI want.
check() {
  local name="$1" value accepted
  shift
  value="${!name:-}"
  [[ -z "$value" ]] && return 0
  for accepted in "$@"; do
    if [[ "$value" == "$accepted" ]]; then
      echo -e "${GREEN}✅ ${name} accepted${CLEAR}"
      echo "    ${value}"
      return 0
    fi
  done
  reject "$name" "$value" "not an accepted spelling" "$@"
}

check MINA_RELEASE_DOCKER_REPO "${DOCKER_ACCEPTED[@]}"
check MINA_RELEASE_DOCKER_MIRROR "${DOCKER_ACCEPTED[@]}"
check MINA_RELEASE_DEBIAN_REPO "${DEBIAN_ACCEPTED[@]}"
check MINA_RELEASE_DEBIAN_MIRROR "${DEBIAN_ACCEPTED[@]}"

# not_the_primary <mirror variable> <primary variable> <primary default>: a
# mirror is a second target. The same one twice is not a release anyone means
# to run, and Dhall would render it without a word.
not_the_primary() {
  local mirror_name="$1" primary_name="$2" default="$3" mirror primary
  mirror="${!mirror_name:-}"
  primary="${!primary_name:-$default}"
  [[ -n "$mirror" && "$mirror" == "$primary" ]] || return 0
  echo -e "${RED}❌ ${mirror_name} names the target the release already goes to.${CLEAR}" >&2
  echo "" >&2
  echo "    primary:  ${primary}$([[ -z "${!primary_name:-}" ]] && echo "  (the job default; ${primary_name} is unset)")" >&2
  echo "    mirror:   ${mirror}" >&2
  echo "" >&2
  echo "    A mirror is a second target. Leave it unset to publish to one." >&2
  exit 1
}

not_the_primary MINA_RELEASE_DOCKER_MIRROR MINA_RELEASE_DOCKER_REPO "$DOCKER_DEFAULT"
not_the_primary MINA_RELEASE_DEBIAN_MIRROR MINA_RELEASE_DEBIAN_REPO "$DEBIAN_DEFAULT"
