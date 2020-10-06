#!/bin/bash

set -eo pipefail

eval `opam config env`
export PATH=/home/opam/.cargo/bin:/usr/lib/go/bin:$PATH
export GO=/usr/lib/go/bin/go

make build_archive

./scripts/archive/build-release-archives.sh
