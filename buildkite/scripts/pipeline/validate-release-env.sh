#!/bin/bash

# Reject a release variable that is set to something Dhall will quietly ignore.
#
# MINA_RELEASE_DOCKER_REPO and MINA_RELEASE_DEBIAN_REPOS carry Dhall values,
# and the expressions that read them end in `? None` so that an unset variable
# means "use what the job declares". That fallback cannot tell "unset" from
# "set to something that does not resolve", because Dhall collapses both into
# the same None:
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
# meant to be free of. The debian list is the same story: a typo in it
# publishes to packages.o1test.net alone and says nothing.
#
# Dhall cannot make the difference itself: it has no Text equality, so the
# variable cannot be matched against a list of accepted spellings there. Here
# it can.

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

# is_accepted <value> <accepted>...
is_accepted() {
  local value="$1" accepted
  shift
  for accepted in "$@"; do
    [[ "$value" == "$accepted" ]] && return 0
  done
  return 1
}

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

# One alternative: the whole value is one accepted spelling.
value="${MINA_RELEASE_DOCKER_REPO:-}"
if [[ -n "$value" ]]; then
  if is_accepted "$value" "${DOCKER_ACCEPTED[@]}"; then
    echo -e "${GREEN}✅ MINA_RELEASE_DOCKER_REPO accepted${CLEAR}"
    echo "    ${value}"
  else
    reject MINA_RELEASE_DOCKER_REPO "$value" "not an accepted spelling" "${DOCKER_ACCEPTED[@]}"
  fi
fi

# A list of alternatives: `[ a, b ]`, each element one accepted spelling, at
# least one element, no element twice. An empty list would publish nowhere
# and a repeated one would publish the same files twice; neither is a release
# anyone means to run, so both stop here.
value="${MINA_RELEASE_DEBIAN_REPOS:-}"
if [[ -n "$value" ]]; then
  flat="$(tr '\n' ' ' <<< "$value")"
  flat="${flat#"${flat%%[![:space:]]*}"}"
  flat="${flat%"${flat##*[![:space:]]}"}"
  if [[ "$flat" != "["* || "$flat" != *"]" ]]; then
    reject MINA_RELEASE_DEBIAN_REPOS "$value" "not a list: expected '[ <element>, ... ]'" "${DEBIAN_ACCEPTED[@]}"
  fi
  inner="${flat#\[}"
  inner="${inner%\]}"
  elements=()
  seen=()
  IFS=',' read -ra parts <<< "$inner"
  for part in "${parts[@]}"; do
    element="${part#"${part%%[![:space:]]*}"}"
    element="${element%"${element##*[![:space:]]}"}"
    [[ -z "$element" ]] && continue
    if ! is_accepted "$element" "${DEBIAN_ACCEPTED[@]}"; then
      reject MINA_RELEASE_DEBIAN_REPOS "$value" "element '${element}' is not an accepted spelling" "${DEBIAN_ACCEPTED[@]}"
    fi
    if is_accepted "$element" "${seen[@]+"${seen[@]}"}"; then
      reject MINA_RELEASE_DEBIAN_REPOS "$value" "element '${element}' is listed twice" "${DEBIAN_ACCEPTED[@]}"
    fi
    seen+=("$element")
    elements+=("$element")
  done
  if [[ ${#elements[@]} -eq 0 ]]; then
    reject MINA_RELEASE_DEBIAN_REPOS "$value" "the list is empty, so nothing would be published" "${DEBIAN_ACCEPTED[@]}"
  fi
  echo -e "${GREEN}✅ MINA_RELEASE_DEBIAN_REPOS accepted${CLEAR}"
  printf '    %s\n' "${elements[@]}"
fi
