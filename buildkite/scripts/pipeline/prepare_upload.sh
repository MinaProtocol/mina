#!/usr/bin/env bash

# Decide what a build actually runs: everything triage picks, or only the steps
# that were asked for.
#
# Prepare.dhall is the first thing every pipeline uploads, and it is the only
# place both answers are reachable, so the choice is made here. It is made in
# bash and not in dhall because dhall has no equality for text and so cannot
# tell an empty selection from a full one.
#
#   BUILDKITE_PIPELINE_SELECTION      patterns for step keys, comma separated
#   BUILDKITE_PIPELINE_DEB_SELECTION  patterns for debian package tokens
#
# With either of them set, the build uploads Entrypoints/RunSelection.dhall,
# which runs run-selection.sh and reads the patterns out of the environment.
# The tag, scope and dirty-when filters are then not consulted at all: someone
# who names a step is asking for that step, not for whatever the pull request
# happened to touch.
#
# With neither set, the monorepo triage expression given as $1 is uploaded and
# nothing changes.
#
# The values are written by whoever wrote the pull request comment. They are
# never put into a dhall expression, here or anywhere below: dhall can read the
# environment, so a value that closed its quote would evaluate on the agent.
#
# Usage: prepare_upload.sh '<monorepo dhall expression>'

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPLOAD="${SCRIPT_DIR}/upload.sh"

MONOREPO_EXPR="${1:-}"

if [[ -z "$MONOREPO_EXPR" ]]; then
  echo "ERROR: the monorepo triage expression is required." >&2
  exit 2
fi

SELECTION="${BUILDKITE_PIPELINE_SELECTION:-}"
DEB_SELECTION="${BUILDKITE_PIPELINE_DEB_SELECTION:-}"

if [[ -n "$SELECTION" || -n "$DEB_SELECTION" ]]; then
  echo "--- Building only what was asked for"
  [[ -n "$SELECTION" ]] && echo "    steps:    ${SELECTION}"
  [[ -n "$DEB_SELECTION" ]] && echo "    packages: ${DEB_SELECTION}"
  echo "    (tag, scope and dirty-when filters are not consulted)"
  exec "$UPLOAD" '(./buildkite/src/Entrypoints/RunSelection.dhall)'
fi

exec "$UPLOAD" "$MONOREPO_EXPR"
