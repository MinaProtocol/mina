#!/bin/bash

# Writes the freshly-built application binaries to the CI cache under
#   apps/<codename>[/<variant>]/
#
# <variant> names only what makes a build differ from the default one, and is
# EMPTY for that default (a standard, non-instrumented amd64 build), which lands
# directly in apps/<codename>/. The variants in use are "instrumented", "arm64"
# and "instrumented-arm64".
#
# The variant depth is needed because an instrumented build emits binaries with
# the same names as a standard one (mina.exe and friends); sharing a directory
# they would overwrite each other, leaving whichever build finished last -- a
# non-deterministic, wrong artifact for any consumer.
#
# The variant deliberately carries NO network or profile. The binaries here are
# network-agnostic: src/app/cli/src/mina.exe links no mina_signature_kind
# library (see src/app/cli/src/dune), so signature kind and proof level are
# resolved at runtime from the config. Only instrumentation and the target
# architecture change the bytes, so a devnet and a mainnet build of the same
# codename produce the same binaries and share one variant directory.

CODENAME=$1
VARIANT=$2

if [[ -z "$CODENAME" ]]; then
  echo "Usage: $0 <codename> [<variant>]" >&2
  exit 1
fi

DEST="apps/${CODENAME}${VARIANT:+/${VARIANT}}"

# Bundle every shared library a binary needs, so a consumer restoring the bare
# binary does not depend on the agent image happening to provide them. The agent
# image has always carried what these binaries needed (libgmp10, liblmdb0, ...);
# a binary that grows a NEW runtime dependency otherwise dies on the agent with
# "error while loading shared libraries" even though the .deb declares it.
#
# What goes in -- glibc, the loader, the dlopened libnss_* modules -- and why
# the restored binary must be run by the BUNDLED loader is documented once, in
# buildkite/scripts/bundle-libs.sh, which is also what the portable release
# bundle is built from. restore_app.sh installs the matching wrapper.
#
# Unlike that release bundle, the cache keeps one tarball per binary rather than
# a single deduplicated tree: a consumer restores ONE exe and should not have to
# download the closure of all of them.
# shellcheck source=buildkite/scripts/bundle-libs.sh
source ./buildkite/scripts/bundle-libs.sh

bundle_libs() {
  local exe="$1" dest="$2" stage tarball
  command -v ldd >/dev/null 2>&1 || return 0

  stage="$(mktemp -d)"
  tarball="$(mktemp -d)/$(basename "$exe").libs.tar.gz"

  bundle_collect "$exe" "$stage"

  if [[ -z "$(ls -A "$stage" 2>/dev/null)" ]]; then
    rm -rf "$stage" "$(dirname "$tarball")"
    return 0
  fi

  tar -czf "$tarball" -C "$stage" .
  ./buildkite/scripts/cache/manager.sh write-to-dir "$tarball" "$dest"
  rm -rf "$stage" "$(dirname "$tarball")"
}

find _build -type f -name "*.exe" | while read -r entry; do
  # Exclude files ending with ppx.exe
  if [[ "$entry" == *ppx.exe ]]; then
    continue
  fi

  ./buildkite/scripts/cache/manager.sh write-to-dir "$entry" "$DEST"
  bundle_libs "$entry" "$DEST"
done

# libp2p_helper is a Go binary (built under src/app/libp2p_helper/result/bin,
# not a dune _build/*.exe), but the daemon needs it at runtime. Cache it
# alongside the exes so bare daemon tests can restore it as coda-libp2p_helper,
# mirroring what the .deb installs.
HELPER="src/app/libp2p_helper/result/bin/libp2p_helper"
if [[ -f "$HELPER" ]]; then
  ./buildkite/scripts/cache/manager.sh write-to-dir "$HELPER" "$DEST"
  bundle_libs "$HELPER" "$DEST"
fi

# minimina is a Rust binary (built under src/app/minimina/target/release, not a
# dune _build/*.exe). Cache it alongside the exes so the debian packaging job can
# restore it into the build tree without a separate copy of the binaries.
MINIMINA="src/app/minimina/target/release/minimina"
if [[ -f "$MINIMINA" ]]; then
  ./buildkite/scripts/cache/manager.sh write-to-dir "$MINIMINA" "$DEST"
  bundle_libs "$MINIMINA" "$DEST"
fi
