#!/usr/bin/env bash

# Array of valid service names
export VALID_SERVICES=('mina-archive' 'mina-daemon' 'mina-daemon-hardfork' 'mina-rosetta' 'mina-test-suite' 'mina-batch-txn' 'mina-zkapp-test-transaction' 'mina-toolchain' 'leaderboard' 'delegation-backend' 'delegation-backend-toolchain')

function export_base_image () {
    # Determine the proper image for ubuntu or debian
    case "${DEB_CODENAME##*=}" in
    focal|noble)
        IMAGE="ubuntu:${DEB_CODENAME##*=}"
    ;;
    bullseye|jammy)
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
        mina-daemon|mina-batch-txn|mina-rosetta|mina-daemon-hardfork) export VERSION="${VERSION}-${NETWORK##*=}" ;;
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
        standard)
        case "${DEB_BUILD_FLAGS}" in 
            *instrumented)
            export DOCKER_DEB_SUFFIX="--build-arg deb_suffix=instrumented"
            export BUILD_FLAG_SUFFIX="-instrumented"
            ;;
            *)
            export DOCKER_DEB_SUFFIX=""
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

function export_docker_tag() {
    export_suffixes

    export DOCKER_REGISTRY="gcr.io/o1labs-192920"
    export TAG="${DOCKER_REGISTRY}/${SERVICE}:${VERSION}${BUILD_FLAG_SUFFIX}"
    # friendly, predictable tag
    GITHASH=$(git rev-parse --short=7 HEAD)
    export GITHASH
    export HASHTAG="${DOCKER_REGISTRY}/${SERVICE}:${GITHASH}-${DEB_CODENAME##*=}-${NETWORK##*=}${BUILD_FLAG_SUFFIX}"

}
