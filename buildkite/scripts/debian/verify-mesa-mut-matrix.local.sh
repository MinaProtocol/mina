#!/usr/bin/env bash

# LOCAL convenience driver (not a Buildkite step itself).
#
# Runs buildkite/scripts/debian/verify-package-commit.sh inside a fresh container
# for every codename x {automode, legacy}. It documents the verification matrix a
# Buildkite job should encode in Dhall: one verify-package-commit.sh invocation per
# (codename, package) cell, the codename selecting the container image.
#
# Usage:  buildkite/scripts/debian/verify-mesa-mut-matrix.local.sh
# Override the targets via env vars below.

set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1

CHANNEL="${CHANNEL:-umt}"

AUTO_PKG="${AUTO_PKG:-mina-mesa-mut-automode}"
AUTO_VER="${AUTO_VER:-4.0.0-rc1-mesa-mut-d7513d4}"
AUTO_EXPECT="${AUTO_EXPECT:-mina-mesa-mut-prefork-mesa=3.4.0-alpha1-automode-fix-3d88e1c916 mina-mesa-mut-postfork-mesa=4.0.0-rc1-mesa-mut-d7513d4}"

LEG_PKG="${LEG_PKG:-mina-mesa-mut}"
LEG_VER="${LEG_VER:-3.4.0-alpha1-mesa-mut-stop-slot-1a6a8f5}"
LEG_EXPECT="${LEG_EXPECT:-mina-mesa-mut-config=3.4.0-alpha1-mesa-mut-stop-slot-1a6a8f5}"

declare -A IMG=( [bullseye]=debian:bullseye [bookworm]=debian:bookworm \
                 [focal]=ubuntu:focal [jammy]=ubuntu:jammy [noble]=ubuntu:noble )

run_cell() {
    local cn="$1" pkg="$2" ver="$3" expect="$4"
    echo "==================== ${cn} / ${pkg} ===================="
    docker run --rm -v "$PWD:/workdir:ro" -w /workdir \
        -e CODENAME="$cn" -e CHANNEL="$CHANNEL" \
        -e PACKAGE="$pkg" -e VERSION="$ver" -e EXPECT="$expect" \
        "${IMG[$cn]}" bash buildkite/scripts/debian/verify-package-commit.sh
}

RC=0
for cn in bullseye bookworm focal jammy noble; do
    run_cell "$cn" "$AUTO_PKG" "$AUTO_VER" "$AUTO_EXPECT" || RC=1
    run_cell "$cn" "$LEG_PKG"  "$LEG_VER"  "$LEG_EXPECT"  || RC=1
done

if [[ "$RC" -ne 0 ]]; then echo "MATRIX FAILED"; else echo "MATRIX PASSED"; fi
exit "$RC"
