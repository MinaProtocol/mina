#!/usr/bin/env bash

set -e

both(){git apply $1 && git apply -R $1}
both scripts/hardfork/localnet-patches/berkeley.patch
both buildkite/scripts/caqti-upgrade.patch
both buildkite/scripts/caqti-upgrade-plus-archive-init-speedup.patch
