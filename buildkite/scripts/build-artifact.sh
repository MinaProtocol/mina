#!/bin/bash

set -eox pipefail

# shellcheck disable=SC1090
source ~/.profile

MINA_COMMIT_SHA1=$(git rev-parse HEAD)

# reexporting DUNE_INSTRUMENT_WITH
if [[ -v DUNE_INSTRUMENT_WITH ]]; then
  export DUNE_INSTRUMENT_WITH="$DUNE_INSTRUMENT_WITH"
fi


echo "--- Build all major targets required for packaging"
echo "Building from Commit SHA: ${MINA_COMMIT_SHA1}"
echo "Rust Version: $(rustc --version)"

make libp2p_helper

make build-logproc

make build-mina

make build-daemon-utils

make build-archive-utils

make build-test-utils

make build-delegation-verify

# --- Portable bundle -------------------------------------------------------
#
# The per-OS build matrix (bullseye/focal/noble/jammy/bookworm) exists only
# because these binaries link distro-provided shared libraries, forcing a
# separate build plus a matching base image per codename. A portable bundle
# sidesteps that: carry the whole .so closure -- GLIBC AND THE LOADER INCLUDED
# -- next to the binaries and run them under the bundled loader, so ONE build
# runs on every target regardless of the host's glibc.
#
# Bundling libc is what makes the build host a free choice rather than a
# constraint: this bundle is produced by the project's single toolchain, and
# the host glibc drops out of the support matrix entirely (the remaining
# runtime floor is the host KERNEL). The collection rules, and why the loader
# must be invoked explicitly, live in buildkite/scripts/bundle-libs.sh.
#
# We deliberately do NOT touch the in-place _build binaries: this script is also
# invoked by build-release.sh, which packages .deb files straight out of _build,
# and those must keep their normal system RPATHs. So we bundle COPIES into a
# separate tree.
if [[ "${MINA_BUILD_PORTABLE:-0}" == "1" ]]; then
  echo "--- Assembling portable bundle"

  # shellcheck source=buildkite/scripts/bundle-libs.sh
  source ./buildkite/scripts/bundle-libs.sh

  portable_root="$PWD/_build_portable"
  portable_bin="$portable_root/bin"
  portable_libexec="$portable_root/libexec"
  portable_lib="$portable_root/lib"
  rm -rf "$portable_root"
  mkdir -p "$portable_bin" "$portable_libexec" "$portable_lib"

  # Same binary set apps/write_to_cache.sh flattens into the apps cache: every
  # dune-built .exe (excluding ppx helpers), so the bundle backs the whole image
  # matrix, not just the daemon.
  #
  # No pipe into the loop: this runs under `set -e`, and a subshell body cannot
  # fail the script or export the collected state.
  mapfile -t source_exes < <(find _build/default -type f -name "*.exe" ! -name "*ppx.exe")

  libp2p_binary="${MINA_LIBP2P_HELPER_PATH:-$PWD/src/app/libp2p_helper/result/bin/libp2p_helper}"
  if [[ -f "$libp2p_binary" ]]; then
    # A Go binary, not under _build, but the daemon needs it at runtime, so it
    # rides along exactly like the apps cache carries it.
    source_exes+=("$libp2p_binary")
  fi

  for source_exe in "${source_exes[@]}"; do
    exe_name="$(basename "$source_exe")"
    [[ "$source_exe" == "$libp2p_binary" ]] && exe_name="mina-libp2p_helper"

    echo "Packaging executable $source_exe -> $portable_libexec/$exe_name"
    cp "$source_exe" "$portable_libexec/$exe_name"
    chmod u+w "$portable_libexec/$exe_name"

    # A library the build image lacks is invisible to ldd and would simply be
    # absent at run time. In the cache that is survivable -- the agent image may
    # still carry it -- but this bundle IS the runtime, so stop here rather than
    # ship an artifact that dies on first start.
    missing="$(bundle_missing "$source_exe")"
    if [[ -n "$missing" ]]; then
      echo "Unresolved shared libraries for $source_exe:" >&2
      echo "$missing" >&2
      echo "The build image is missing their runtime packages." >&2
      exit 1
    fi

    # One shared lib dir for every binary: the closures overlap heavily, and
    # copies are no-clobber, so this deduplicates them.
    bundle_collect "$source_exe" "$portable_lib"
  done

  # One loader serves the whole bundle -- every binary here is the same arch.
  loader="$(bundle_loader_name "$portable_lib")"
  if [[ -z "$loader" ]]; then
    echo "Portable bundle has no dynamic loader; refusing to ship it" >&2
    exit 1
  fi

  for source_exe in "${source_exes[@]}"; do
    exe_name="$(basename "$source_exe")"
    [[ "$source_exe" == "$libp2p_binary" ]] && exe_name="mina-libp2p_helper"

    # The wrapper is the entry point, and it is named after the binary it runs:
    # bin/<name> is what a Dockerfile or the .deb puts on PATH, while the real
    # ELF stays in libexec/ where nothing invokes it directly (its PT_INTERP
    # names the HOST loader and would load the host's libc).
    bundle_write_wrapper \
      "$portable_bin/$exe_name" "lib" "libexec/$exe_name" "$loader"
  done

  echo "Portable bundle: ${#source_exes[@]} binaries, \
$(find "$portable_lib" -type f | wc -l) libraries, loader $loader"
fi
