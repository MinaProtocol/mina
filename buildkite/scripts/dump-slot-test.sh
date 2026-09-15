#!/bin/bash

set -eox pipefail

# PG_CONN is set by RunWithPostgres Dhall module
# This script runs inside the mina-archive Docker container

./scripts/dump-slot-test.sh -a mina-dump-slot-ledger -p "$PG_CONN"
