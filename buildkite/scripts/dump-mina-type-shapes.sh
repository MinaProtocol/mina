#!/bin/bash

set -eo pipefail

buildkite/scripts/debian/update.sh --verbose

TESTNET_NAME="devnet-generic"

# Build variant whose binaries this job consumes from the apps cache. Matches
# the VersionLint dependsOn default (Bullseye / Devnet network / Devnet profile).
CODENAME="${MINA_DEB_CODENAME:-bullseye}"
APPS_VARIANT="devnet-devnet"
MINA_EXE="mina_testnet_signatures.exe"

git config --global --add safe.directory /workdir
source buildkite/scripts/export-git-env-vars.sh

# dump-type-shapes only reads the binary's compiled-in type registry, so the
# freshly-built bare binary from the apps cache is sufficient; no debian package
# (and its config/genesis payload) is required. Fall back to the .deb when the
# bare binary is unavailable (e.g. branch without the namespaced apps cache).
if MINA_BIN=$(./buildkite/scripts/apps/restore_binary.sh "$CODENAME" "$APPS_VARIANT" "$MINA_EXE" ./_apps_bin); then
  MINA_CMD=("$MINA_BIN")
  echo "Using bare binary from apps cache: $MINA_BIN"
else
  source buildkite/scripts/debian/install.sh "mina-${TESTNET_NAME}" 1
  MINA_CMD=(mina)
  echo "Using debian-installed mina"
fi

MINA_COMMIT_SHA1=$(git log -n 1 --format=%h --abbrev=7)
export TYPE_SHAPE_FILE=${MINA_COMMIT_SHA1}-type_shape.txt

echo "--- Create type shapes git note for commit: ${MINA_COMMIT_SHA1}"
"${MINA_CMD[@]}" internal dump-type-shapes > ${TYPE_SHAPE_FILE}

source buildkite/scripts/gsutil-upload.sh ${TYPE_SHAPE_FILE} gs://mina-type-shapes
