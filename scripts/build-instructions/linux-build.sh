#!/usr/bin/env bash

# Build Mina on Linux.
# This corresponds to "Invoke make build" in the "Developer Setup (Linux)"
# section of README-dev.md.
#
# Run this script from the root of the Mina repository after completing the
# opam setup (linux-opam-setup.sh) and dependency pinning (linux-pin-deps.sh).

set -eo pipefail

make build
