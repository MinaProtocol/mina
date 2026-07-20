#!/bin/bash

set -eo pipefail

git config --global --add safe.directory /workdir

source buildkite/scripts/export-git-env-vars.sh

# `ledger test apply` builds its own throwaway genesis ledger from generated
# accounts (mina ledger test generate-accounts -> mina-create-genesis ->
# mina ledger test apply) and never touches the .deb's genesis payload or
# /etc/mina config -- the deb-based path even deletes those config files below.
# So the freshly-built bare binaries from the apps cache are sufficient. This
# job depends on the instrumented build, so restore from that variant (and the
# instrumented binaries still emit bisect_ppx coverage). Restore both the daemon
# (`mina`) and the genesis tool (`mina-create-genesis`); fall back to the .deb if
# either is unavailable.
export APPS_BUILD_FLAG=instrumented

# The bare cache binary (and the network-free mina-generic-instrumented fallback)
# resolve the node profile from MINA_PROFILE, defaulting to "dev" (ledger_depth
# 10) when unset -- too small for the 20k-account test ledger. The .deb daemon
# gets this from /etc/coda/build_config/PROFILE; set it explicitly here so
# mina-create-genesis uses the devnet constants (ledger_depth 35).
export MINA_PROFILE=devnet

if ./buildkite/scripts/apps/restore_binary.sh devnet \
  && ./buildkite/scripts/apps/restore_app.sh devnet runtime_genesis_ledger.exe mina-create-genesis; then
  echo "Using bare mina + mina-create-genesis from apps cache"
else
  echo "Falling back to debian-installed mina"
  # This job depends on the instrumented build, whose daemon binaries ship in
  # the network-free mina-generic-instrumented package (it Provides mina-generic
  # to satisfy the profile package's dependency).
  source buildkite/scripts/debian/install.sh "mina-generic-instrumented" 1

  echo "removing magic config files"
  sudo rm -f /var/lib/coda/config_*
fi

./scripts/tests/ledger_test_apply.sh \
    --mina-app mina \
    --runtime-ledger-app mina-create-genesis