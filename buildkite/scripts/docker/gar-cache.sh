#!/usr/bin/env bash

# ------------------------------------------------------------------
# gar-cache pull-through (Phase 2 — Mina-side coverage for buildx)
#
# Buildkite agents run a `docker pull` PATH shim that rewrites image
# refs in our project namespace (.../o1labs-192920/*) to go through
# the in-cluster gar-cache (https://gar-cache.gcp.o1test.net externally,
# http://gar-cache-ingress.zot-gar-cache in-cluster on rivendell-1).
# That shim only intercepts standalone `docker pull` — it does NOT
# cover `docker buildx build`, which is how all our images are built.
# Evidence: build 1407 of mina-mainline-branches-nightlies — the buildx
# step pulled FROM/COPY base layers direct from GAR, only the verify
# step's `docker pull` hit the cache.
#
# These helpers expose a buildkite-side rewrite that callers can apply
# before invoking scripts/docker/build.sh, so buildx-driven FROM lines
# and Dockerfile-install-config bases resolve via the cache when up.
# They fall through to the upstream value when the cache is unreachable
# or when GAR_CACHE_DISABLED=true is set.
#
# Design: this script lives under buildkite/scripts/ on purpose —
# scripts/docker/ is meant to stay infra-free; everything here is
# o1labs-CI-specific.
#
# Env vars (consistent with the agent-side shim hook):
#   DOCKER_CACHE_ENDPOINT  - cache base URL; defaults to
#                            http://gar-cache-ingress.zot-gar-cache
#   GAR_CACHE_DISABLED     - set to "true" to opt out
# ------------------------------------------------------------------

function gar_cache_probe () {
    # Returns 0 iff zot is reachable on /v2/. Re-probes every call —
    # /v2/ is a single curl with a 2s timeout, so memoization isn't
    # worth the state-management cost. NOTE: a 200 here only proves
    # zot is up; it does NOT guarantee any given image is servable
    # (disk-full / sync-failure cases still pass /v2/ but fail real
    # manifest fetches — see gar_cache_has_manifest).
    if [[ "${GAR_CACHE_DISABLED:-false}" == "true" ]]; then
        echo "[gar-cache] disabled via GAR_CACHE_DISABLED=true" >&2
        return 1
    fi
    local cache_url="${DOCKER_CACHE_ENDPOINT:-http://gar-cache-ingress.zot-gar-cache}"
    if curl -fso /dev/null --connect-timeout 1 --max-time 2 "${cache_url}/v2/" 2>/dev/null; then
        echo "[gar-cache] probe UP at ${cache_url}/v2/" >&2
        return 0
    fi
    echo "[gar-cache] probe DOWN at ${cache_url}/v2/ — falling back to direct upstream" >&2
    return 1
}

function gar_cache_has_manifest () {
    # Returns 0 iff the cache can serve the manifest for the given full ref.
    # Triggers zot's on-demand sync if the manifest is not yet cached, so a
    # 200 here means "either already cached OR successfully fetched just now".
    # A 404 (or any non-200) means the cache is unwilling/unable to serve it —
    # could be: image doesn't exist upstream, sync failed, zot disk full.
    # Either way: caller MUST NOT rewrite if this returns non-zero.
    if ! gar_cache_probe; then
        return 1
    fi
    local full_ref="$1"
    # Scope: only refs in our project namespace. Anything else is out of
    # cache scope (zot's sync extension is only configured for upstreams
    # we know how to authenticate against).
    case "$full_ref" in
        */o1labs-192920/*) ;;
        *) return 1 ;;
    esac
    local cache_url="${DOCKER_CACHE_ENDPOINT:-http://gar-cache-ingress.zot-gar-cache}"
    # Strip the upstream registry hostname (everything up to & including the
    # first "/"). The agent-side shim does the same swap, and zot's sync
    # extension iterates its configured upstreams to resolve the manifest.
    local repo_with_tag="${full_ref#*/}"
    local tag="${repo_with_tag##*:}"
    local repo_path="${repo_with_tag%:*}"
    # Pass all three Accept headers so we get a 200 regardless of whether
    # the upstream stores a Docker manifest, an OCI image manifest, or an
    # OCI image index.
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
    # failure mode: if buildx asks the cache for an image and gets 404, it
    # errors out — there's no exec-fallback like the agent-side shim has.
    local ref="$1"
    if ! gar_cache_has_manifest "$ref"; then
        echo "$ref"
        return 0
    fi
    local cache_url="${DOCKER_CACHE_ENDPOINT:-http://gar-cache-ingress.zot-gar-cache}"
    local cache_host="${cache_url#*://}"
    # Generic rewrite: drop the upstream registry hostname, prepend the
    # cache host. Works for any GAR-like upstream serving o1labs-192920/*
    # — adding a third upstream (e.g. us-central1-docker.pkg.dev) needs
    # zero code changes here.
    local rewritten="${cache_host}/${ref#*/}"
    echo "[gar-cache] rewriting ${ref} -> ${rewritten}" >&2
    echo "$rewritten"
}

function rewrite_docker_repo_via_gar_cache () {
    # Rewrite the `docker_repo` build-arg prefix to use the cache hostname
    # IFF the dependency image (constructed as ${prefix}/${image_name}:${tag})
    # is currently servable from the cache. Used by Dockerfile-install-config
    # which has `FROM ${docker_repo}/${image_name}:${version}-...-generic...`
    # The probe constructs that exact FROM ref before deciding to rewrite.
    local registry_prefix="$1"   # e.g., europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo
    local dep_image_name="$2"    # e.g., mina-daemon
    local dep_tag="$3"           # e.g., 4.0.0-rc1-...-bullseye-devnet-generic-instrumented
    local full_ref="${registry_prefix}/${dep_image_name}:${dep_tag}"
    if ! gar_cache_has_manifest "$full_ref"; then
        echo "$registry_prefix"
        return 0
    fi
    local cache_url="${DOCKER_CACHE_ENDPOINT:-http://gar-cache-ingress.zot-gar-cache}"
    local cache_host="${cache_url#*://}"
    # Same generic rewrite as rewrite_via_gar_cache: gar_cache_has_manifest
    # already vetted scope, so we can safely drop the upstream hostname.
    local rewritten="${cache_host}/${registry_prefix#*/}"
    echo "[gar-cache] rewriting docker_repo ${registry_prefix} -> ${rewritten} (probe: ${dep_image_name}:${dep_tag})" >&2
    echo "$rewritten"
}
