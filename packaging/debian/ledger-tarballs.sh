#!/usr/bin/env bash
# Runs a command with the ledger tarballs named by a genesis config.
#
# Usage: ledger-tarballs.sh <config.json> <command> [<argument> ...]
#
# Copies the tarballs into a temporary directory, runs the command with that
# directory as its last argument, and removes the directory afterwards.
#
# The config names each ledger by the SHA3-256 of its tarball (s3_data_hash).
# The tarball of hash H is the one file in $LEDGER_TARBALLS_DIR/H/, and is
# checked against H after it is copied. So the tarballs are fixed by the config
# alone, whatever else is in LEDGER_TARBALLS_DIR.

set -euo pipefail

config="${1:?usage: $0 <config.json> <command> [<argument> ...]}"
shift
if [[ $# -eq 0 ]]; then
  echo "usage: $0 <config.json> <command> [<argument> ...]" >&2
  exit 2
fi
tarballs_dir="${LEDGER_TARBALLS_DIR:-/var/storagebox/ledger-tarballs}"

hashes=$(jq -r '[.ledger, .epoch_data.staking, .epoch_data.next]
  | map(.s3_data_hash? // empty) | unique[]' "$config")
if [[ -z "$hashes" ]]; then
  echo "ledger-tarballs: no s3_data_hash in ${config}" >&2
  exit 1
fi

out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
for hash in $hashes; do
  files=("${tarballs_dir}/${hash}"/*.tar.gz)
  if [[ ${#files[@]} -ne 1 || ! -f "${files[0]}" ]]; then
    echo "ledger-tarballs: expected one tarball in ${tarballs_dir}/${hash}" >&2
    exit 1
  fi
  dest="${out}/${files[0]##*/}"
  cp "${files[0]}" "$dest"
  actual=$(openssl dgst -sha3-256 -r "$dest" | cut -d' ' -f1)
  if [[ "$actual" != "$hash" ]]; then
    echo "ledger-tarballs: ${files[0]} has SHA3-256 ${actual}, not ${hash}" >&2
    exit 1
  fi
done

"$@" "$out"
