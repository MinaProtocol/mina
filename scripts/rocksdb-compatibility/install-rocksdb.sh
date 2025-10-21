#!/usr/bin/env bash 

set -euox pipefail

ROCKSDB_VERSION=10.5.1

ROCKSDB_SOURCE=$(mktemp -d --tmpdir rocksdb-$ROCKSDB_VERSION.XXXXXX)

# shellcheck disable=SC2064
trap "rm -rf $ROCKSDB_SOURCE" EXIT

curl -L https://github.com/facebook/rocksdb/archive/refs/tags/v${ROCKSDB_VERSION}.tar.gz | tar xz -C $ROCKSDB_SOURCE

cd $ROCKSDB_SOURCE/rocksdb-${ROCKSDB_VERSION}

# NOTE: 
# `-Wno-unused-parameter` is to fix this error:
# util/compression.cc:684:40: error: unused parameter ‘args’ [-Werror=unused-parameter]
# 684 |   Status ExtractUncompressedSize(Args& args) override {
#     |                                  ~~~~~~^~~~
sudo EXTRA_CXXFLAGS="-Wno-unused-parameter" make -j"$(nproc)" install-shared

# Refresh LD cache so follow up programs can locate the dyn libaray
sudo ldconfig
