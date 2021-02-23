#!/bin/bash

set -eo pipefail

eval `opam config env`
export PATH=/home/opam/.cargo/bin:/usr/lib/go/bin:$PATH
export GO=/usr/lib/go/bin/go

artifact-cache-helper.sh _build/default/src/app/archive/archive.exe --miss-cmd "make build_archive"
artifact-cache-helper.sh _build/default/src/app/archive_blocks/archive_blocks.exe --miss-cmd "make archive_blocks"
artifact-cache-helper.sh _build/default/src/app/missing_subchain/missing_subchain.exe --miss-cmd "make missing_subchain"
artifact-cache-helper.sh _build/default/src/app/missing_blocks_auditor/missing_blocks_auditor.exe --miss-cmd "make missing_blocks_auditor"

./scripts/archive/build-release-archives.sh
