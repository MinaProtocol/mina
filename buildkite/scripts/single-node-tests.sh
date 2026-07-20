#!/bin/bash

set -eo pipefail

git config --global --add safe.directory /workdir

source buildkite/scripts/export-git-env-vars.sh

# mina-command-line-tests spins up a real lightnet daemon but generates its own
# random genesis/config, so it needs no deb config -- only binaries. Restore them
# bare from the apps cache, each from the build variant that produced it:
#   - mina (daemon) + libp2p_helper  <- the generic devnet build (devnet-devnet).
#     The apps build only compiles one profile; the lightnet behaviour is selected
#     at runtime via MINA_PROFILE=lightnet (set below), which node_config_profiled
#     resolves at startup -- there is no separate lightnet binary in the cache.
#   - mina-command-line-tests (the driver) + mina-node-status-mock-server (a
#     subprocess the suite spawns)  <- the instrumented build's test-suite
#     (devnet-devnet-instrumented), so bisect_ppx coverage still works.
# The daemon finds the helper as coda-libp2p_helper on PATH, exactly like the deb.
# Fall back to the debs on any cache miss (e.g. outside Buildkite).
if ./buildkite/scripts/apps/restore_binary.sh devnet \
  && ./buildkite/scripts/apps/restore_app.sh devnet libp2p_helper coda-libp2p_helper \
  && APPS_PROFILE=devnet APPS_BUILD_FLAG=instrumented ./buildkite/scripts/apps/restore_app.sh devnet command_line_tests.exe mina-command-line-tests \
  && APPS_PROFILE=devnet APPS_BUILD_FLAG=instrumented ./buildkite/scripts/apps/restore_app.sh devnet node_status_mock_server.exe mina-node-status-mock-server; then
  echo "Using bare mina + libp2p_helper + mina-command-line-tests + mina-node-status-mock-server from apps cache"
else
  echo "Falling back to debian-installed test-suite + lightnet daemon"
  # The daemon binary lives in the network-free mina-generic package; the
  # profile is selected at runtime via MINA_PROFILE=lightnet (set below), so no
  # lightnet-specific daemon package is needed. mina-test-suite supplies the
  # mina-command-line-tests driver and the node-status mock server.
  source buildkite/scripts/debian/install.sh "mina-test-suite,mina-generic" 1
fi

export MINA_LIBP2P_PASS="naughty blue worm"
export MINA_PRIVKEY_PASS="naughty blue worm"

export MINA_PROFILE=lightnet

mina-command-line-tests test -v
