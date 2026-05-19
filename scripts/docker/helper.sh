#!/usr/bin/env bash

set -eox pipefail

source "$(dirname "$0")/../export-git-env-vars.sh"

# Array of valid service names
export VALID_SERVICES=('mina-archive' 'mina-daemon' 'mina-daemon-generic' 'mina-daemon-configured' 'mina-daemon-legacy-hardfork' 'mina-daemon-auto-hardfork' 'mina-rosetta' 'mina-rosetta-generic' 'mina-rosetta-configured' 'mina-test-suite' 'mina-batch-txn' 'mina-zkapp-test-transaction' 'mina-toolchain' 'leaderboard' 'delegation-backend' 'mina-delegation-verifier' 'delegation-backend-toolchain')

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
        mina-daemon|mina-archive|mina-batch-txn|mina-rosetta|mina-daemon-auto-hardfork) export VERSION="${VERSION}-${NETWORK##*=}" ;;
        *)  ;;
esac
}

function export_suffixes () {
    # Determine suffix for mina name. Suffix is combined from custom suffix, profile and build flags.
    # Order must match debian package naming in builder-helpers.sh:
    #   mina-{network}-{custom_suffix}-{profile}-{build_flags}
    # Possible raw outcomes (without leading dash):
    # - instrumented
    # - lightnet
    # - generic
    # - generic-lightnet
    # - generic-instrumented
    # - generic-lightnet-instrumented
    local __raw_suffix=""
    local __sep=""

    if [[ -n "${DOCKER_DEB_SUFFIX:-}" ]]; then
        __raw_suffix="${DOCKER_DEB_SUFFIX}"
        __sep="-"
    fi

    if [[ "${DEB_PROFILE:-}" == "lightnet" ]]; then
        __raw_suffix="${__raw_suffix}${__sep}lightnet"
        __sep="-"
    fi

    if [[ "${DEB_BUILD_FLAGS:-}" == *instrumented* ]]; then
        __raw_suffix="${__raw_suffix}${__sep}instrumented"
        __sep="-"
    fi

    # COMBINED_SUFFIX: used in docker tags, has leading dash when non-empty
    if [[ -n "${__raw_suffix}" ]]; then
        export COMBINED_SUFFIX="-${__raw_suffix}"
    else
        export COMBINED_SUFFIX=""
    fi

    # DOCKER_DEB_SUFFIX_ARG: passed to Dockerfile as build arg (no leading dash,
    # the Dockerfile adds its own dash via ${deb_suffix:+-${deb_suffix}})
    export DOCKER_DEB_SUFFIX_ARG="--build-arg deb_suffix=${__raw_suffix}"

    # BUILD_FLAGS_SUFFIX_ARG: passed to Dockerfile as build arg for packages
    # that only use the build flags suffix (e.g. archive uses instrumented but not generic)
    local __build_flags="${DEB_BUILD_FLAGS:-}"
    if [[ "$__build_flags" == "none" ]]; then
        __build_flags=""
    else
        __build_flags="-${__build_flags}"
    fi
    export BUILD_FLAGS_SUFFIX_ARG="--build-arg build_flags_suffix=${__build_flags}"
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

    CUSTOM_SUFFIX_ARG=""
    if [[ -z "${CUSTOM_SUFFIX:-}" ]]; then
        CUSTOM_SUFFIX=""
    else
        CUSTOM_SUFFIX="-${CUSTOM_SUFFIX}"
        CUSTOM_SUFFIX_ARG="--build-arg custom_suffix=${CUSTOM_SUFFIX}"
    fi


    PLATFORM_SUFFIX="$(get_platform_suffix)"
    export CUSTOM_SUFFIX_ARG
    export TAG_VERSION_PART="${VERSION}${COMBINED_SUFFIX}${PLATFORM_SUFFIX}${CUSTOM_SUFFIX}"
    export TAG="${DOCKER_REGISTRY}/${SERVICE}:${TAG_VERSION_PART}"
    export PLATFORM_SUFFIX
    export HASHTAG_VERSION_PART="${GITHASH}-${DEB_CODENAME##*=}-${NETWORK##*=}${COMBINED_SUFFIX}${PLATFORM_SUFFIX}${CUSTOM_SUFFIX}"
    export HASHTAG="${DOCKER_REGISTRY}/${SERVICE}:${HASHTAG_VERSION_PART}"

}
