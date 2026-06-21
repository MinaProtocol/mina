#!/bin/bash

set -eox pipefail

# PG_CONN is set by RunWithPostgres Dhall module.
# Runs in the toolchain image with mina-dump-slot-ledger restored bare from the
# apps cache (falling back to the mina-archive deb on a cache miss); both put it
# on PATH, so this is invoked by name regardless.

./scripts/dump-slot-test.sh -a mina-dump-slot-ledger -p "$PG_CONN"
