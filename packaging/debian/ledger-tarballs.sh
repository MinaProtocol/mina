#!/usr/bin/env bash
# Copies the ledger tarballs named by a genesis config into a directory.
#
# Usage: ledger-tarballs.sh <config.json> <output directory>
#
# The config names each ledger by the SHA3-256 of its tarball (s3_data_hash).
# The tarball of hash H is the one file in $LEDGER_TARBALLS_DIR/H/, and is
# checked against H after it is copied. So the tarballs are fixed by the config
# alone, whatever else is in LEDGER_TARBALLS_DIR.

set -euo pipefail

config="${1:?usage: $0 <config.json> <output directory>}"
out="${2:?usage: $0 <config.json> <output directory>}"
tarballs_dir="${LEDGER_TARBALLS_DIR:-/var/storagebox/ledger-tarballs}"

hashes=$(jq -r '[.ledger, .epoch_data.staking, .epoch_data.next]
  | map(.s3_data_hash? // empty) | unique[]' "$config")
if [[ -z "$hashes" ]]; then
  echo "ledger-tarballs: no s3_data_hash in ${config}" >&2
  exit 1
fi

mkdir -p "$out"
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
