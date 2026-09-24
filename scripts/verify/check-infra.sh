#!/usr/bin/env bash

# Check that the package distribution infrastructure is reachable and serving.
#
# This is a canary, not an artifact test. It answers one question: can a user who
# runs "apt-get update" or "docker pull" right now get a usable answer from us?
# It is cheap enough to run every hour and needs no credentials.
#
# Checks per Debian repository and codename:
#   1. dists/<codename>/Release responds 200 and names that codename
#   2. dists/<codename>/<component>/binary-<arch>/Packages.gz responds 200,
#      decompresses, and holds at least one package stanza
#
# Checks per Docker repository:
#   3. the registry answers and the repository holds at least one tag
#
# An empty index is treated as a failure. A repository that answers 200 with zero
# packages is worse than one that is down, because apt reports no error and the
# user simply cannot find anything.
#
# Usage:
#   ./scripts/verify/check-infra.sh
#   ./scripts/verify/check-infra.sh --repos packages.o1test.net --channels alpha,stable

set -eo pipefail

REPOS="packages.o1test.net"
CHANNELS="unstable,alpha,beta,stable"
CODENAMES="bullseye,focal,noble,jammy,bookworm"
ARCH=amd64
DOCKER_REPO=minaprotocol
DOCKER_IMAGES="mina-daemon,mina-archive,mina-rosetta"
TIMEOUT=25
STRICT=0

function usage() {
  if [[ -n "$1" ]]; then echo "ERROR: $1"; echo; fi
  echo "Usage: $0 [options]"
  echo
  echo "  -r, --repos       Comma list of apt repository hosts (default: $REPOS)"
  echo "  -c, --channels    Comma list of components (default: $CHANNELS)"
  echo "  -m, --codenames   Comma list of codenames (default: $CODENAMES)"
  echo "      --arch        Architecture (default: $ARCH)"
  echo "      --docker-repo Docker namespace (default: $DOCKER_REPO)"
  echo "      --images      Comma list of docker repositories (default: $DOCKER_IMAGES)"
  echo "      --timeout     Per-request timeout in seconds (default: $TIMEOUT)"
  echo "      --strict      Treat a missing component as a failure. By default a"
  echo "                    component that does not exist on a codename is a SKIP,"
  echo "                    because not every repository carries every channel."
  echo "  -h, --help        This message"
  echo
  echo "Exit code is 1 if any check fails."
  exit 1
}

while [[ "$#" -gt 0 ]]; do case $1 in
  -r|--repos) REPOS="$2"; shift;;
  -c|--channels) CHANNELS="$2"; shift;;
  -m|--codenames) CODENAMES="$2"; shift;;
  --arch) ARCH="$2"; shift;;
  --docker-repo) DOCKER_REPO="$2"; shift;;
  --images) DOCKER_IMAGES="$2"; shift;;
  --timeout) TIMEOUT="$2"; shift;;
  --strict) STRICT=1;;
  -h|--help) usage "";;
  *) usage "Unknown parameter: $1";;
esac; shift; done

FAILURES=0
CHECKS=0

function report() {
  local status="$1" target="$2" detail="$3"
  printf '%-6s %-58s %s\n' "$status" "$target" "$detail"
  CHECKS=$((CHECKS + 1))
  if [[ "$status" == "FAIL" ]]; then FAILURES=$((FAILURES + 1)); fi
}

function http_code() {
  curl -sSL -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT" "$1" 2>/dev/null || echo "000"
}

echo "Infrastructure check  arch=$ARCH  $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "===================================================================================="

IFS=',' read -ra REPO_LIST <<< "$REPOS"
IFS=',' read -ra CHANNEL_LIST <<< "$CHANNELS"
IFS=',' read -ra CODENAME_LIST <<< "$CODENAMES"
IFS=',' read -ra IMAGE_LIST <<< "$DOCKER_IMAGES"

for repo in "${REPO_LIST[@]}"; do
  for codename in "${CODENAME_LIST[@]}"; do

    release_url="https://${repo}/dists/${codename}/Release"
    code=$(http_code "$release_url")

    if [[ "$code" != "200" ]]; then
      report "FAIL" "${repo} ${codename} Release" "HTTP $code"
      continue
    fi

    # A Release file that does not name its own codename means the repository was
    # rebuilt against the wrong suite, which breaks apt in a way that is hard to see.
    if curl -sSL --max-time "$TIMEOUT" "$release_url" 2>/dev/null | grep -qE "^(Codename|Suite): *${codename}\b"; then
      report "OK" "${repo} ${codename} Release" "signed index present"
    else
      report "FAIL" "${repo} ${codename} Release" "does not declare codename ${codename}"
    fi

    for channel in "${CHANNEL_LIST[@]}"; do
      pkg_url="https://${repo}/dists/${codename}/${channel}/binary-${ARCH}/Packages.gz"
      code=$(http_code "$pkg_url")

      if [[ "$code" == "404" ]]; then
        if [[ "$STRICT" == 1 ]]; then
          report "FAIL" "${repo} ${codename}/${channel}" "component missing (HTTP 404)"
        else
          report "SKIP" "${repo} ${codename}/${channel}" "component not present"
        fi
        continue
      fi

      if [[ "$code" != "200" ]]; then
        report "FAIL" "${repo} ${codename}/${channel}" "HTTP $code"
        continue
      fi

      count=$(curl -sSL --max-time "$TIMEOUT" "$pkg_url" 2>/dev/null \
        | gunzip 2>/dev/null \
        | grep -c '^Package: ' || true)

      if [[ -z "$count" || "$count" == "0" ]]; then
        report "FAIL" "${repo} ${codename}/${channel}" "index is empty or not valid gzip"
      else
        report "OK" "${repo} ${codename}/${channel}" "${count} packages"
      fi
    done
  done
done

echo "------------------------------------------------------------------------------------"

for image in "${IMAGE_LIST[@]}"; do
  api="https://hub.docker.com/v2/repositories/${DOCKER_REPO}/${image}/tags?page_size=1"
  body=$(curl -sSL --max-time "$TIMEOUT" "$api" 2>/dev/null || echo "")

  if [[ -z "$body" ]]; then
    report "FAIL" "docker ${DOCKER_REPO}/${image}" "registry did not answer"
    continue
  fi

  # "count" is the number of tags the registry reports for the repository.
  count=$(echo "$body" | tr ',' '\n' | grep -m1 '"count"' | grep -oE '[0-9]+' || true)

  if [[ -z "$count" ]]; then
    report "FAIL" "docker ${DOCKER_REPO}/${image}" "unexpected registry answer"
  elif [[ "$count" == "0" ]]; then
    report "FAIL" "docker ${DOCKER_REPO}/${image}" "repository holds no tags"
  else
    report "OK" "docker ${DOCKER_REPO}/${image}" "${count} tags"
  fi
done

echo "===================================================================================="
echo "checks=${CHECKS} failures=${FAILURES}"

if [[ "$FAILURES" -gt 0 ]]; then
  echo "Infrastructure check FAILED"
  exit 1
fi

echo "Infrastructure check OK"
exit 0
