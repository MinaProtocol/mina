#!/bin/bash

# Reject a release variable that is set to something Dhall will quietly ignore.
#
# MINA_RELEASE_DOCKER_REPO carries a Dhall value, and the expression that reads
# it ends in `? None Repo` so that an unset variable means "use the job's own
# registry". That fallback cannot tell "unset" from "set to something that does
# not resolve", because Dhall collapses both into the same None:
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
# meant to be free of.
#
# Dhall cannot make the difference itself: it has no Text equality, so the
# variable cannot be matched against a list of accepted spellings there. Here
# it can.

set -euo pipefail

CLEAR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'

UNION='< Internal | InternalEurope | Public >'
ACCEPTED=(
  "${UNION}.Internal"
  "${UNION}.InternalEurope"
  "${UNION}.Public"
)

value="${MINA_RELEASE_DOCKER_REPO:-}"

if [[ -z "$value" ]]; then
  # Unset is a real answer: every job keeps the registry it declares, which is
  # what nightly and pull request CI want.
  exit 0
fi

for accepted in "${ACCEPTED[@]}"; do
  if [[ "$value" == "$accepted" ]]; then
    echo -e "${GREEN}✅ MINA_RELEASE_DOCKER_REPO accepted${CLEAR}"
    echo "    ${value}"
    exit 0
  fi
done

echo -e "${RED}❌ MINA_RELEASE_DOCKER_REPO is set to a value Dhall will ignore.${CLEAR}" >&2
echo "" >&2
echo "    got:      ${value}" >&2
echo "" >&2
echo "    expected exactly one of:" >&2
for accepted in "${ACCEPTED[@]}"; do
  echo "      ${accepted}" >&2
done
echo "" >&2
echo "    Anything else resolves to nothing, and the expression that reads it" >&2
echo "    cannot tell that from the variable being unset. The build would have" >&2
echo "    gone green with every image pushed to the registry each job declares" >&2
echo "    rather than the one asked for here." >&2
exit 1
