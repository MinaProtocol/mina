#!/bin/bash

set -eo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <dune-profile> <path-to-source-tests>"
    exit 1
fi

profile=$1
path=$2

source ~/.profile

# Functions to help persist and restore the lagrange basis cache
# Function to create cache directory
create_cache_dir() {
  local cache_dir=$1
  mkdir -p "$cache_dir"
}

# Function to compute checksum
compute_checksum() {
  local cache_dir=$1
  find "$cache_dir" -type f -exec md5sum {} + | sort -k 2 | md5sum | awk '{ print $1 }'
}

# Function to download and extract cache
restore_cache() {
  local bucket_name=$1
  local object_name=$2
  local cache_dir=$3

  if gcloud storage cp "gs://$bucket_name/$object_name" lagrange_cache.tar.gz; then
    tar -xzf lagrange_cache.tar.gz -C "$cache_dir"
    echo "Cache restored from GCS."
  else
    echo "No cache found. Starting with a fresh cache."
  fi
}

# Function to upload cache if changed
upload_cache_if_changed() {
  local bucket_name=$1
  local object_name=$2
  local cache_dir=$3
  local old_checksum=$4

  new_checksum=$(compute_checksum "$cache_dir")

  if [ "$old_checksum" != "$new_checksum" ]; then
    tar -czf lagrange_cache.tar.gz -C "$cache_dir" .
    gcloud storage cp lagrange_cache.tar.gz "gs://$bucket_name/$object_name"
    echo "Cache has changed. Updated cache saved to GCS."
  else
    echo "Cache has not changed. No update needed."
  fi
}

export MINA_LIBP2P_PASS="naughty blue worm"
export NO_JS_BUILD=1 # skip some JS targets which have extra implicit dependencies

export LAGRANGE_CACHE_DIR="/tmp/lagrange-cache"
export LAGRANGE_CACHE_GC_BUCKET="o1labs-ci-test-data"
export LAGRANGE_CACHE_GC_OBJECT="lagrange-cache.tar.gz"

create_cache_dir "$LAGRANGE_CACHE_DIR"
restore_cache "$LAGRANGE_CACHE_GC_BUCKET" "$LAGRANGE_CACHE_GC_OBJECT" "$LAGRANGE_CACHE_DIR"
old_checksum=$(compute_checksum "$LAGRANGE_CACHE_DIR")


echo "--- Make build"
export LIBP2P_NIXLESS=1 PATH=/usr/lib/go/bin:$PATH GO=/usr/lib/go/bin/go
time make build

echo "--- Build all targets"
dune build "${path}" --profile="${profile}" -j16

echo "--- Check for changes to verification keys"
time dune runtest "src/app/print_blockchain_snark_vk" --profile="${profile}" -j16

# Turn on the proof-cache assertion, so that CI will fail if the proofs need to
# be updated.
export ERROR_ON_PROOF=true


# Note: By attempting a re-run on failure here, we can avoid rebuilding and
# skip running all of the tests that have already succeeded, since dune will
# only retry those tests that failed.
echo "--- Run unit tests"
time dune runtest "${path}" --profile="${profile}" -j16 || \
(./scripts/link-coredumps.sh && \
 echo "--- Retrying failed unit tests" && \
 time dune runtest "${path}" --profile="${profile}" -j16 || \
 (./scripts/link-coredumps.sh && false))

new_checksum = $(compute_checksum "$LAGRANGE_CACHE_DIR")
upload_cache_if_changed "$LAGRANGE_CACHE_GC_BUCKET" "$LAGRANGE_CACHE_GC_OBJECT" "$LAGRANGE_CACHE_DIR" "$old_checksum"