#!/usr/bin/env bash

# CI glue for the artifact verification tools.
#
# One entrypoint, selected by VERIFY_MODE:
#
#   infra      Cheap canary. Is the apt repository serving and does the docker
#              registry answer? No credentials, no downloads. Safe to run hourly.
#
#   artifacts  Full test. Installs every listed package in a clean container of
#              each codename, pulls every listed docker image, and runs the
#              automode metapackage install with no version pin. Downloads a few
#              gigabytes, so run it daily rather than hourly.
#
# Every input is an environment variable so a Buildkite scheduled build can set
# them without changing the pipeline definition.
#
# Shared:
#   VERIFY_MODE      infra | artifacts            (default: infra)
#   CODENAMES        comma list                   (default: bullseye,focal,noble,jammy,bookworm)
#   DEBIAN_REPO      apt host                     (default: packages.o1test.net)
#   ARCH             amd64 | arm64                (default: amd64)
#   DOCKER_REPO      registry namespace           (default: minaprotocol)
#
# VERIFY_MODE=infra:
#   DEBIAN_CHANNELS  comma list of components     (default: unstable,alpha,beta,stable)
#   DOCKER_IMAGES    comma list of repositories   (default: mina-daemon,mina-archive,mina-rosetta)
#   STRICT_INFRA     true -> a missing component fails (default: false)
#
# VERIFY_MODE=artifacts:
#   DEBIAN_CHANNEL   single component to test     (default: alpha)
#   PACKAGES         comma list of name=version   (optional)
#   IMAGES           comma list of name=version   (optional)
#   AUTOMODE         name=version                 (optional)
#   DOCKER_SUFFIX    tag suffix after codename    (default: -devnet)
#   JOBS             containers in parallel       (default: 4)
#
# At least one of PACKAGES, IMAGES or AUTOMODE must be set in artifacts mode.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

VERIFY_MODE="${VERIFY_MODE:-infra}"
CODENAMES="${CODENAMES:-bullseye,focal,noble,jammy,bookworm}"
DEBIAN_REPO="${DEBIAN_REPO:-packages.o1test.net}"
ARCH="${ARCH:-amd64}"
DOCKER_REPO="${DOCKER_REPO:-minaprotocol}"

echo "--- Verification mode: ${VERIFY_MODE}"

case "$VERIFY_MODE" in

  infra)
    DEBIAN_CHANNELS="${DEBIAN_CHANNELS:-unstable,alpha,beta,stable}"
    DOCKER_IMAGES="${DOCKER_IMAGES:-mina-daemon,mina-archive,mina-rosetta}"

    ARGS=(
      --repos "$DEBIAN_REPO"
      --channels "$DEBIAN_CHANNELS"
      --codenames "$CODENAMES"
      --arch "$ARCH"
      --docker-repo "$DOCKER_REPO"
      --images "$DOCKER_IMAGES"
    )

    if [[ "${STRICT_INFRA:-false}" == "true" ]]; then
      ARGS+=(--strict)
    fi

    exec "${REPO_ROOT}/scripts/verify/check-infra.sh" "${ARGS[@]}"
    ;;

  artifacts)
    DEBIAN_CHANNEL="${DEBIAN_CHANNEL:-alpha}"
    DOCKER_SUFFIX="${DOCKER_SUFFIX:--devnet}"
    JOBS="${JOBS:-4}"
    OUTPUT_DIR="${OUTPUT_DIR:-${PWD}/verification-results}"

    if [[ -z "${PACKAGES:-}" && -z "${IMAGES:-}" && -z "${AUTOMODE:-}" ]]; then
      echo "ERROR: artifacts mode needs at least one of PACKAGES, IMAGES or AUTOMODE."
      echo "       Set them on the scheduled build, for example:"
      echo "         PACKAGES=mina-devnet=3.5.0-devnet-stop-slot-98e7835"
      echo "         IMAGES=mina-daemon=3.5.0-devnet-stop-slot-98e7835"
      echo "         AUTOMODE=mina-devnet-automode=4.0.0-devnet-ca2ccb1"
      exit 1
    fi

    ARGS=(
      --codenames "$CODENAMES"
      --channel "$DEBIAN_CHANNEL"
      --repo "$DEBIAN_REPO"
      --docker-repo "$DOCKER_REPO"
      --suffix "$DOCKER_SUFFIX"
      --arch "$ARCH"
      --jobs "$JOBS"
      --output "$OUTPUT_DIR"
    )

    if [[ -n "${PACKAGES:-}" ]]; then ARGS+=(--packages "$PACKAGES"); fi
    if [[ -n "${IMAGES:-}" ]];   then ARGS+=(--images "$IMAGES"); fi
    if [[ -n "${AUTOMODE:-}" ]]; then ARGS+=(--automode "$AUTOMODE"); fi

    exec "${REPO_ROOT}/scripts/verify/test-release.sh" "${ARGS[@]}"
    ;;

  *)
    echo "ERROR: unknown VERIFY_MODE '${VERIFY_MODE}'. Use 'infra' or 'artifacts'."
    exit 1
    ;;
esac
