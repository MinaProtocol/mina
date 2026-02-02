#!/usr/bin/env bash

set -eox pipefail

source "$(dirname "$0")/../export-git-env-vars.sh"

# Array of valid service names
export VALID_SERVICES=('mina-archive' 'mina-daemon' 'mina-daemon-legacy-hardfork' 'mina-daemon-auto-hardfork' 'mina-rosetta' 'mina-test-suite' 'mina-batch-txn' 'mina-zkapp-test-transaction' 'mina-toolchain' 'leaderboard' 'delegation-backend' 'mina-delegation-verifier' 'delegation-backend-toolchain')

function export_base_image () {
    # Determine the proper image for ubuntu or debian
    case "${DEB_CODENAME##*=}" in
    focal|jammy|noble)
        IMAGE="ubuntu:${DEB_CODENAME##*=}"
    ;;
    bullseye)
        IMAGE="debian:${DEB_CODENAME##*=}-slim"
    ;;
    bookworm)
        IMAGE="europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/debian:bookworm"
    ;;
    esac
    export IMAGE="--build-arg image=${IMAGE}"
}

function export_version () {
    case "${SERVICE}" in
        mina-daemon|mina-archive|mina-batch-txn|mina-rosetta|mina-daemon-legacy-hardfork|mina-daemon-auto-hardfork) export VERSION="${VERSION}-${NETWORK##*=}" ;;
        *)  ;;
esac
}

function export_suffixes () {
    # Determine suffix for mina name. Suffix is combined from profile and service name 
    # Possible outcomes:
    # - instrumented
    # - hardfork
    # - lightnet
    # - hardfork-instrumented
    case "${DEB_PROFILE}" in
        devnet|mainnet)
        case "${DEB_BUILD_FLAGS}" in 
            *instrumented)
            export DOCKER_DEB_SUFFIX="--build-arg deb_suffix=instrumented"
            export BUILD_FLAG_SUFFIX="-instrumented"
            ;;
            *)
            export DOCKER_DEB_SUFFIX="${DOCKER_DEB_SUFFIX:-}"
            export BUILD_FLAG_SUFFIX=""
            ;;
        esac
        ;;
        lightnet)
        case "${DEB_BUILD_FLAGS}" in
            *instrumented)
            export DOCKER_DEB_SUFFIX="--build-arg deb_suffix=lightnet-instrumented"
            export BUILD_FLAG_SUFFIX="lightnet-instrumented"
            ;;
            *)
            export DOCKER_DEB_SUFFIX="--build-arg deb_suffix=lightnet"
            export BUILD_FLAG_SUFFIX="-lightnet"
            ;;
        esac
        ;;
        *)
        case "${DEB_BUILD_FLAGS}" in 
            *instrumented)
            export DOCKER_DEB_SUFFIX="--build-arg deb_suffix=${DEB_PROFILE}-instrumented"
            export BUILD_FLAG_SUFFIX="-instrumented"
            ;;
            *)
            export DOCKER_DEB_SUFFIX="--build-arg deb_suffix=${DEB_PROFILE}"
            export BUILD_FLAG_SUFFIX=""
            ;;
        esac
        ;;
    esac
}

function get_platform_suffix() {
    case "${INPUT_PLATFORM}" in
        linux/amd64)
            echo ""
            ;;
        linux/arm64)
            echo "-arm64"
            ;;
        *)
            echo ""
            ;;
    esac
}

function check_docker_registry() {
    if [[ -z "${DOCKER_REGISTRY:-}" ]]; then
        echo "ERROR: DOCKER_REGISTRY environment variable is not set" >&2
        exit 1
    fi
}

function export_docker_tag() {
    export_suffixes
    
    check_docker_registry
    export DOCKER_REGISTRY="${DOCKER_REGISTRY}"

    PLATFORM_SUFFIX="$(get_platform_suffix)"
    export TAG="${DOCKER_REGISTRY}/${SERVICE}:${VERSION}${BUILD_FLAG_SUFFIX}${PLATFORM_SUFFIX}"
    export PLATFORM_SUFFIX
    export HASHTAG="${DOCKER_REGISTRY}/${SERVICE}:${GITHASH}-${DEB_CODENAME##*=}-${NETWORK##*=}${BUILD_FLAG_SUFFIX}${PLATFORM_SUFFIX}"

}
