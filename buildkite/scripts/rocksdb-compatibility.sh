#!/usr/bin/env bash 

set -euox pipefail

ROCKSDB_VERSION=10.5.1

ROCKSDB_SOURCE=`mktemp -d --tmpdir rocksdb-$ROCKSDB_VERSION.XXXXXX`
trap "rm -rf $ROCKSDB_SOURCE" EXIT

curl -L https://github.com/facebook/rocksdb/archive/refs/tags/v${ROCKSDB_VERSION}.tar.gz | tar xz -C $ROCKSDB_SOURCE

cd $ROCKSDB_SOURCE/rocksdb-${ROCKSDB_VERSION}

# NOTE: 
# `-Wno-unused-parameter` is to fix this error:
# util/compression.cc:684:40: error: unused parameter ‘args’ [-Werror=unused-parameter]
# 684 |   Status ExtractUncompressedSize(Args& args) override {
#     |                                  ~~~~~~^~~~
EXTRA_CXXFLAGS="-Wno-unused-parameter" make -j$(nproc) install

S3_URL="https://snark-keys.o1test.net.s3.amazonaws.com/"

TMP_BASE="$(mktemp -d)"
trap "rm -rf $TMP_BASE" EXIT

PATTERN='^(genesis_ledger|epoch_ledger)_.*\.tar\.gz$'

echo "Fetching list of objects from S3..."
xml=$(curl -s "$S3_URL")

tar_keys=()
while IFS= read -r key; do
    tar_keys+=("$key")
done < <(xmllint --xpath '//Key/text()' <<< "$xml" | tr ' ' '\n' | grep -E "$PATTERN")

if [[ ${#tar_keys[@]} -eq 0 ]]; then
  echo "No ledger tar files found."
  exit 1
fi

# Shuffle and take 5
mapfile -t sample_keys < <(printf "%s\n" "${tar_keys[@]}" | shuf | head -n 5)

for tar_key in "${sample_keys[@]}"; do
  tar_uri="https://s3-us-west-2.amazonaws.com/snark-keys.o1test.net/${tar_key}"
  echo "Testing RocksDB compatibility on ${tar_uri}"

  dir=$(mktemp -d -p "$TMP_BASE")
  tar_path="${dir}/$(basename "$tar_key")"
  db_path="${dir}/extracted"

  echo "  Downloading to ${tar_path}..."
  curl -s -L "$tar_uri" -o "$tar_path"

  echo "  Extracting to ${db_path}..."
  mkdir -p "$db_path"
  tar -xzf "$tar_path" -C "$db_path"

  echo "  Testing extracted RocksDB at ${db_path}..."
  if ! command -v ldb >/dev/null 2>&1; then
    echo "Error: ldb command not found (install RocksDB CLI tools)."
    exit 1
  fi

  # Try listing a few entries
  if ldb --db="$db_path" scan | head -n 5; then
    echo "  ✅ RocksDB opened successfully."
  else
    echo "  ❌ Failed to open RocksDB at ${db_path}"
    exit 1
  fi
done

echo "All tests completed successfully."

