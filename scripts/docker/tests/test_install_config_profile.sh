#!/bin/bash
set -euo pipefail

################################################################################
# Regression test for dockerfiles/Dockerfile-install-config
#
# Usage:
#   bash scripts/docker/tests/test_install_config_profile.sh
#
# The per-network daemon image (mina-daemon:<version>-<network>) layers the
# mina-<network>-config deb on a base daemon image. The node takes its profile
# from MINA_PROFILE or /etc/coda/build_config/PROFILE and has no default, so the
# base must be the profiled image (<version>-<profile>-generic), not the
# profile-free generic one. This test builds the real Dockerfile on stub base
# images and a stub config deb, and checks the built image carries the profile
# it was built for.
#
# Needs a working docker daemon, local or remote (no bind mounts). Pulls
# debian:bookworm-slim.
################################################################################

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BASE_IMAGE="debian:bookworm-slim"
STUB_REPO="mina-test-install-config"
VERSION="0.0.0-test"
WORK_DIR="$(mktemp -d)"
FAILURES=0
# <network>:<profile> pairs, as the release pipeline builds them.
IMAGES=(devnet:devnet mainnet:mainnet)

cleanup() {
  rm -rf "${WORK_DIR}"
  docker image rm -f "${STUB_REPO}/mina-daemon:${VERSION}-generic" "${STUB_REPO}/deb-builder:${VERSION}" >/dev/null 2>&1 || true
  for image in "${IMAGES[@]}"; do
    docker image rm -f "${STUB_REPO}/mina-daemon:${VERSION}-${image#*:}-generic" "${STUB_REPO}/mina-daemon:${VERSION}-${image%%:*}" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

# Stub generic image: nothing profile-related, like the real generic image.
printf 'FROM %s\n' "${BASE_IMAGE}" \
  | docker build -q -t "${STUB_REPO}/mina-daemon:${VERSION}-generic" - >/dev/null

# Same resolution as the node: MINA_PROFILE, then the PROFILE file, no default.
# shellcheck disable=SC2016 # expanded inside the container
RESOLVE_PROFILE='p="${MINA_PROFILE:-$(cat /etc/coda/build_config/PROFILE 2>/dev/null || true)}"; echo "${p:-<none>}"'

for image in "${IMAGES[@]}"; do
  network="${image%%:*}"
  profile="${image#*:}"

  # Stub profiled image, like the real one: generic plus the PROFILE file.
  printf 'FROM %s/mina-daemon:%s-generic\nRUN mkdir -p /etc/coda/build_config && printf %s > /etc/coda/build_config/PROFILE\n' \
    "${STUB_REPO}" "${VERSION}" "${profile}" \
    | docker build -q -t "${STUB_REPO}/mina-daemon:${VERSION}-${profile}-generic" - >/dev/null

  ctx="${WORK_DIR}/ctx/${network}"
  mkdir -p "${ctx}/pkg/DEBIAN" "${ctx}/pkg/var/lib/coda"
  printf 'Package: mina-%s-config\nVersion: %s\nArchitecture: all\nMaintainer: test\nDescription: stub\n' \
    "${network}" "${VERSION}" > "${ctx}/pkg/DEBIAN/control"
  echo '{}' > "${ctx}/pkg/var/lib/coda/${network}.json"
  # Build the deb inside docker and copy it out: CI talks to a remote docker
  # daemon, where bind mounts of local paths do not work.
  printf 'FROM %s\nCOPY pkg /pkg\nRUN dpkg-deb --build /pkg /stub.deb\n' "${BASE_IMAGE}" \
    | docker build -q -t "${STUB_REPO}/deb-builder:${VERSION}" -f - "${ctx}" >/dev/null
  cid="$(docker create "${STUB_REPO}/deb-builder:${VERSION}")"
  docker cp "${cid}:/stub.deb" "${ctx}/mina-${network}-config_${VERSION}_all.deb"
  docker rm "${cid}" >/dev/null

  # Same build args scripts/docker/build.sh passes for mina-daemon-configured.
  tag="${STUB_REPO}/mina-daemon:${VERSION}-${network}"
  docker build -q \
    -f "${REPO_ROOT}/dockerfiles/Dockerfile-install-config" \
    --build-arg "docker_repo=${STUB_REPO}" \
    --build-arg "version=${VERSION}" \
    --build-arg "deb_version=${VERSION}" \
    --build-arg "network=${network}" \
    --build-arg "deb_profile=${profile}" \
    --build-arg "generic_base_segment=-${profile}" \
    -t "${tag}" "${ctx}" >/dev/null

  actual="$(docker run --rm --entrypoint sh "${tag}" -c "${RESOLVE_PROFILE}")"
  if [[ "${actual}" == "${profile}" ]]; then
    echo "PASS: ${network} image has profile '${actual}'"
  else
    echo "FAIL: ${network} image has profile '${actual}', expected '${profile}'"
    FAILURES=$((FAILURES + 1))
  fi
done

if [[ "${FAILURES}" -ne 0 ]]; then
  echo "${FAILURES} failure(s)"
  exit 1
fi
echo "All install-config profile tests passed"
