#!/usr/bin/env bash

set -eox pipefail

# Array of valid service names
export VALID_SERVICES=('mina-archive' 'mina-daemon' 'mina-daemon-legacy-hardfork' 'mina-daemon-auto-hardfork' 'mina-rosetta' 'mina-test-suite' 'mina-batch-txn' 'mina-zkapp-test-transaction' 'mina-toolchain' 'leaderboard' 'delegation-backend' 'delegation-backend-toolchain')

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
        IMAGE="debian:bookworm"
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
    local suffix=""

    if [[ "${DEB_PROFILE}" != "public_network" ]] && [[ -n "${DEB_PROFILE}" ]]; then
        suffix="${DEB_PROFILE}"
    fi

    if [[ "${DEB_BUILD_FLAGS}" == *instrumented* ]]; then
        if [[ -n "${suffix}" ]]; then
            suffix="${suffix}-instrumented"
        else
            suffix="instrumented"
        fi
    fi

    if [[ -n "${suffix}" ]]; then
        export DOCKER_DEB_SUFFIX="--build-arg deb_suffix=${suffix}"
        export BUILD_FLAG_SUFFIX="-${suffix}"
    else
        export DOCKER_DEB_SUFFIX=""
        export BUILD_FLAG_SUFFIX=""
    fi
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


function export_docker_tag() {
    export_suffixes

    export DOCKER_REGISTRY="gcr.io/o1labs-192920"

    PLATFORM_SUFFIX="$(get_platform_suffix)"
    export TAG="${DOCKER_REGISTRY}/${SERVICE}:${VERSION}${BUILD_FLAG_SUFFIX}${PLATFORM_SUFFIX}"
    # friendly, predictable tag
    GITHASH=$(git rev-parse --short=7 HEAD)
    export PLATFORM_SUFFIX
    export GITHASH
    export HASHTAG="${DOCKER_REGISTRY}/${SERVICE}:${GITHASH}-${DEB_CODENAME##*=}-${NETWORK##*=}${BUILD_FLAG_SUFFIX}${PLATFORM_SUFFIX}"

}
