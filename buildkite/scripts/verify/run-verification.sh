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
#   DEBIAN_CHANNEL   default component            (default: alpha)
#   PACKAGES         comma list of name[=version][@channel]   (optional)
#   IMAGES           comma list of name=version[:network]     (optional)
#   AUTOMODE         comma list of name[=version][@channel]   (optional)
#
# The two networks do not share a channel: devnet artifacts sit in alpha and
# mainnet ones in stable. Per-entry @channel and :network let a single run cover
# both, so there is no second pipeline to keep in step. A bare package name means
# the version the channel currently offers, which keeps a schedule from carrying
# versions that go stale after every release. Docker images always need an
# explicit version, because a tag has no channel to resolve against.
#
#   PACKAGES=mina-devnet,mina-rosetta-devnet,mina-mainnet@stable
#   IMAGES=mina-daemon=3.5.0-x:devnet,mina-daemon=3.4.0-y:mainnet
#   AUTOMODE=mina-devnet-automode,mina-mainnet-automode@stable
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
      echo "ERROR: artifacts mode needs at least one of PACKAGES, IMAGES or AUTOMODE." >&2
      echo >&2
      echo "For a recurring schedule prefer bare package names, so the schedule never" >&2
      echo "carries a version that goes stale after a release. Add @channel to reach a" >&2
      echo "second network, which lives in a different component:" >&2
      echo "  PACKAGES=mina-devnet,mina-archive-devnet,mina-rosetta-devnet,mina-mainnet@stable" >&2
      echo >&2
      echo "Pin a version only when testing one specific release:" >&2
      echo "  PACKAGES=mina-devnet=3.5.0-devnet-stop-slot-98e7835" >&2
      echo "  AUTOMODE=mina-devnet-automode=4.0.0-devnet-ca2ccb1" >&2
      echo >&2
      echo "Docker images always need an explicit version, because a tag has no" >&2
      echo "channel to resolve against:" >&2
      echo "  IMAGES=mina-daemon=3.5.0-devnet-stop-slot-98e7835" >&2
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
