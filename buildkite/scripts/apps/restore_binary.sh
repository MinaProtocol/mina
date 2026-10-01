#!/bin/bash

# Restore the freshly-built mina daemon binary from the namespaced apps CI cache
# (written by buildkite/scripts/apps/write_to_cache.sh) and install it as `mina`
# on PATH -- mirroring the .deb -- so callers invoke `mina` identically whether
# it came from the cache or a package.
#
# Usage: restore_binary.sh
#
# This is a thin convenience wrapper over restore_app.sh: it installs the daemon
# binary as the plain `mina`, so client scripts never deal with the variant. The
# app-build (and the .deb, see scripts/debian/builder-helpers.sh) ships
# src/app/cli/src/mina.exe as `mina`. That binary is network-agnostic -- it links
# no mina_signature_kind library, so the signature kind and the proof level come
# from the runtime config -- which is why neither this script nor the cache path
# takes a network. The cache location (codename/flag/arch) is derived from the
# build identity by restore_app.sh -- see its header for the env knobs.
#
# Exits non-zero without side effects if not in Buildkite context or the binary
# is not cached, so callers can fall back to installing the .deb.

set -eo pipefail

exec ./buildkite/scripts/apps/restore_app.sh mina.exe mina
