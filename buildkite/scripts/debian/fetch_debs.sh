#!/bin/bash

# Where a test gets the .deb files it exercises.
#
# Sourced, not executed. Provides two functions that every deb-consuming test
# should use instead of calling `cache/manager.sh read` directly:
#
#   fetch_deb <dest-dir> <cache-path-glob>
#   fetch_legacy_deb <dest-dir> <cache-path-glob>
#
# where <cache-path-glob> is the usual cache path, e.g.
# "debians/bullseye/mina-generic_*".
#
# TOP-DOWN (default, unchanged): read from this build's cache, i.e. from
# whatever the packaging job wrote there. A test using this has to depend on the
# packaging job -- which also builds every docker image, so selecting the test
# drags all of that into the build.
#
# BOTTOM-UP (LOCAL_DEB_SOURCE_DIR set): the caller has already packaged the debs
# it needs in this same job, out of the app-build binaries
# (buildkite/scripts/debian/build-from-cache.sh writes them to _build/). The
# basename glob is then resolved against that directory and the file copied,
# with no cache round-trip and no dependency on the packaging job.
#
# fetch_legacy_deb ALWAYS reads the cache: prefork packages are released
# artifacts pinned at a version from before the fork, so there is nothing local
# to build them from.

# Resolve a cache path glob against LOCAL_DEB_SOURCE_DIR and copy the matches.
# Returns non-zero when nothing matches, so callers fail loudly rather than
# silently proceeding with a missing package.
_fetch_deb_local() {
    local dest="$1" pattern="$2"
    local basename_glob="${pattern##*/}"

    shopt -s nullglob
    # shellcheck disable=SC2206  # deliberate glob expansion
    local matches=(${LOCAL_DEB_SOURCE_DIR}/${basename_glob})
    shopt -u nullglob

    if [[ "${#matches[@]}" -eq 0 ]]; then
        echo "fetch_deb: no local .deb matching '${basename_glob}' in ${LOCAL_DEB_SOURCE_DIR}" >&2
        echo "fetch_deb: contents:" >&2
        ls -la "${LOCAL_DEB_SOURCE_DIR}" >&2 || true
        return 1
    fi

    echo "fetch_deb: using locally built ${matches[*]}" >&2
    cp "${matches[@]}" "${dest}/"
}

fetch_deb() {
    local dest="$1" pattern="$2"

    if [[ -n "${LOCAL_DEB_SOURCE_DIR:-}" ]]; then
        _fetch_deb_local "$dest" "$pattern"
    else
        ./buildkite/scripts/cache/manager.sh read --root "${ROOT:-${BUILDKITE_BUILD_ID}}" "$pattern" "$dest"
    fi
}

fetch_legacy_deb() {
    local dest="$1" pattern="$2"

    ./buildkite/scripts/cache/manager.sh read --root "legacy" "$pattern" "$dest"
}
