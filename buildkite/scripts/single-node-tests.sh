#!/bin/bash

set -eo pipefail

git config --global --add safe.directory /workdir

source buildkite/scripts/export-git-env-vars.sh

# mina-command-line-tests spins up a real lightnet daemon but generates its own
# random genesis/config, so it needs no deb config -- only binaries. Restore them
# bare from the apps cache, each from the build variant that produced it:
#   - mina (lightnet daemon) + libp2p_helper  <- the lightnet build (devnet-lightnet)
#   - mina-command-line-tests (the driver)     <- the instrumented build's test-suite
#     (devnet-devnet-instrumented), so bisect_ppx coverage still works.
# The daemon finds the helper as coda-libp2p_helper on PATH, exactly like the deb.
# Fall back to the debs on any cache miss (e.g. outside Buildkite).
if APPS_PROFILE=lightnet ./buildkite/scripts/apps/restore_binary.sh devnet \
  && APPS_PROFILE=lightnet ./buildkite/scripts/apps/restore_app.sh devnet libp2p_helper coda-libp2p_helper \
  && APPS_PROFILE=devnet APPS_BUILD_FLAG=instrumented ./buildkite/scripts/apps/restore_app.sh devnet command_line_tests.exe mina-command-line-tests; then
  echo "Using bare mina + libp2p_helper + mina-command-line-tests from apps cache"
else
  echo "Falling back to debian-installed test-suite + lightnet daemon"
  source buildkite/scripts/debian/install.sh "mina-test-suite,mina-devnet-generic-lightnet" 1
fi

export MINA_LIBP2P_PASS="naughty blue worm"
export MINA_PRIVKEY_PASS="naughty blue worm"

mina-command-line-tests test -v