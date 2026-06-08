#!/usr/bin/env bash

set -eox pipefail

source "$(dirname "$0")/../export-git-env-vars.sh"

# Array of valid service names
export VALID_SERVICES=('mina-archive' 'mina-daemon' 'mina-daemon-generic' 'mina-daemon-configured' 'mina-daemon-legacy-hardfork' 'mina-daemon-auto-hardfork' 'mina-rosetta' 'mina-rosetta-generic' 'mina-rosetta-configured' 'mina-test-suite' 'mina-batch-txn' 'mina-zkapp-test-transaction' 'mina-toolchain' 'leaderboard' 'delegation-backend' 'mina-delegation-verifier' 'delegation-backend-toolchain')

# ------------------------------------------------------------------
# gar-cache pull-through (Phase 2 — Mina-side coverage for buildx)
#
# Buildkite agents run a `docker pull` PATH shim that rewrites image
# references under europe-west3-docker.pkg.dev/o1labs-192920/* and
# gcr.io/o1labs-192920/* to go through the in-cluster gar-cache
# (https://gar-cache.gcp.o1test.net externally,
#  http://gar-cache-ingress.zot-gar-cache in-cluster on rivendell-1).
# That shim only intercepts standalone `docker pull` — it does NOT
# cover `docker buildx build`, which is how all our images are built.
# Evidence: see build 1407 of mina-mainline-branches-nightlies — the
# buildx step pulled FROM/COPY base layers direct from GAR, only the
# verify step's `docker pull` hit the cache.
#
# These helpers rewrite the `image` and `docker_repo` build-args at
# the build.sh call-site so the buildx-driven FROM lines and the
# Dockerfile-install-config base resolve via the cache when up. They
# fall through to the upstream value when the cache is unreachable
# or when GAR_CACHE_DISABLED=true is set.
#
# Env vars (consistent with the agent-side shim hook):
#   DOCKER_CACHE_ENDPOINT  - cache base URL; defaults to
#                            http://gar-cache-ingress.zot-gar-cache
#   GAR_CACHE_DISABLED     - set to "true" to opt out
# ------------------------------------------------------------------

function gar_cache_probe () {
    # Memoize within the current shell so repeated rewrite calls do
    # not re-probe. Sets GAR_CACHE_STATE to UP, DOWN, or DISABLED.
    # NOTE: This only verifies zot is responding on /v2/. It does NOT
    # verify that any given image is actually servable from the cache.
    # Disk-full / on-demand-sync-failure cases will still let /v2/ pass
    # but fail real manifest fetches — see gar_cache_has_manifest.
    if [[ -n "${GAR_CACHE_STATE:-}" ]]; then
        [[ "$GAR_CACHE_STATE" == "UP" ]]
        return $?
    fi
    if [[ "${GAR_CACHE_DISABLED:-false}" == "true" ]]; then
        echo "[gar-cache] disabled via GAR_CACHE_DISABLED=true" >&2
        export GAR_CACHE_STATE="DISABLED"
        return 1
    fi
    local cache_url="${DOCKER_CACHE_ENDPOINT:-http://gar-cache-ingress.zot-gar-cache}"
    if curl -fso /dev/null --connect-timeout 1 --max-time 2 "${cache_url}/v2/" 2>/dev/null; then
        echo "[gar-cache] probe UP at ${cache_url}/v2/" >&2
        export GAR_CACHE_STATE="UP"
        return 0
    fi
    echo "[gar-cache] probe DOWN at ${cache_url}/v2/ — falling back to direct upstream" >&2
    export GAR_CACHE_STATE="DOWN"
    return 1
}

function gar_cache_has_manifest () {
    # Returns 0 iff the cache can serve the manifest for the given full ref.
    # Triggers zot's on-demand sync if the manifest is not yet cached, so a
    # 200 here means "either already cached OR successfully fetched just now".
    # A 404 (or any non-200) means the cache is unwilling/unable to serve it
    # — could be: image doesn't exist upstream, sync failed, zot disk full.
    # Either way: caller MUST NOT rewrite if this returns non-zero.
    if ! gar_cache_probe; then
        return 1
    fi
    local full_ref="$1"
    local cache_url="${DOCKER_CACHE_ENDPOINT:-http://gar-cache-ingress.zot-gar-cache}"
    local repo_with_tag=""
    case "$full_ref" in
        europe-west3-docker.pkg.dev/o1labs-192920/*) repo_with_tag="${full_ref#europe-west3-docker.pkg.dev/}" ;;
        gcr.io/o1labs-192920/*) repo_with_tag="${full_ref#gcr.io/}" ;;
        *) return 1 ;;  # out of cache scope
    esac
    local tag="${repo_with_tag##*:}"
    local repo_path="${repo_with_tag%:*}"
    # Manifest endpoints honor the standard OCI/Docker Accept headers; pass
    # all three so we get a 200 regardless of whether the upstream stores
    # a manifest, an OCI image manifest, or an OCI image index.
    if curl -fsI -o /dev/null --max-time 20 \
        -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' \
        -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
        -H 'Accept: application/vnd.oci.image.index.v1+json' \
        "${cache_url}/v2/${repo_path}/manifests/${tag}" 2>/dev/null; then
        echo "[gar-cache] manifest present in cache: ${repo_path}:${tag}" >&2
        return 0
    fi
    echo "[gar-cache] manifest NOT in cache (will pass through to upstream): ${repo_path}:${tag}" >&2
    return 1
}

function rewrite_via_gar_cache () {
    # Rewrite a full image:tag reference to use the in-cluster gar-cache
    # hostname IFF the cache currently serves that exact manifest. The
    # manifest probe (gar_cache_has_manifest) avoids the buildx-no-fallback
    # failure mode: if buildx asks the cache for an image and gets 404,
    # it errors out — there's no exec-fallback like the agent-side shim has.
    local ref="$1"
    if ! gar_cache_has_manifest "$ref"; then
        echo "$ref"
        return 0
    fi
    local cache_url="${DOCKER_CACHE_ENDPOINT:-http://gar-cache-ingress.zot-gar-cache}"
    local cache_host="${cache_url#*://}"
    local rewritten=""
    case "$ref" in
        europe-west3-docker.pkg.dev/o1labs-192920/*)
            rewritten="${ref/europe-west3-docker.pkg.dev/$cache_host}" ;;
        gcr.io/o1labs-192920/*)
            rewritten="${ref/gcr.io/$cache_host}" ;;
    esac
    if [[ -n "$rewritten" ]]; then
        echo "[gar-cache] rewriting ${ref} -> ${rewritten}" >&2
        echo "$rewritten"
    else
        echo "$ref"
    fi
}

function rewrite_docker_repo_via_gar_cache () {
    # Rewrite the `docker_repo` build-arg prefix to use the cache hostname
    # IFF the dependency image (constructed as ${prefix}/${image_name}:${tag})
    # is currently servable from the cache. Used by Dockerfile-install-config
    # which has `FROM ${docker_repo}/${image_name}:${version}-...-generic...`
    # The probe constructs that exact FROM ref before deciding to rewrite.
    local registry_prefix="$1"   # e.g., europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo
    local dep_image_name="$2"     # e.g., mina-daemon
    local dep_tag="$3"            # e.g., 4.0.0-rc1-...-bullseye-devnet-generic-instrumented
    local full_ref="${registry_prefix}/${dep_image_name}:${dep_tag}"
    if ! gar_cache_has_manifest "$full_ref"; then
        echo "$registry_prefix"
        return 0
    fi
    local cache_url="${DOCKER_CACHE_ENDPOINT:-http://gar-cache-ingress.zot-gar-cache}"
    local cache_host="${cache_url#*://}"
    local rewritten=""
    case "$registry_prefix" in
        europe-west3-docker.pkg.dev/o1labs-192920/*|europe-west3-docker.pkg.dev/o1labs-192920)
            rewritten="${registry_prefix/europe-west3-docker.pkg.dev/$cache_host}" ;;
        gcr.io/o1labs-192920/*|gcr.io/o1labs-192920)
            rewritten="${registry_prefix/gcr.io/$cache_host}" ;;
    esac
    if [[ -n "$rewritten" ]]; then
        echo "[gar-cache] rewriting docker_repo ${registry_prefix} -> ${rewritten} (probe: ${dep_image_name}:${dep_tag})" >&2
        echo "$rewritten"
    else
        echo "$registry_prefix"
    fi
}

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
    # Route GAR-prefixed bases (today: bookworm) through the gar-cache
    # pull-through when reachable. focal/jammy/noble/bullseye fall through
    # to docker.io unchanged because they're outside the cache's scope.
    IMAGE="$(rewrite_via_gar_cache "${IMAGE}")"
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
