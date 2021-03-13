#!/bin/bash

set -eo pipefail

artifact-cache-helper.sh _build/default/src/app/archive/archive.exe
artifact-cache-helper.sh _build/default/src/app/archive_blocks/archive_blocks.exe
artifact-cache-helper.sh _build/default/src/app/missing_subchain/missing_subchain.exe
artifact-cache-helper.sh _build/default/src/app/missing_blocks_auditor/missing_blocks_auditor.exe
