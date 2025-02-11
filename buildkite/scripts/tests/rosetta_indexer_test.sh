#!/bin/bash

# script requires to have side postgres docker with setup archive

set -eox pipefail

SCRIPTPATH="$( cd "$(dirname "$0")" || exit 1 ; pwd -P )"
source "${SCRIPTPATH}/../debian/install.sh" "mina-rosetta-devnet"

mina-rosetta-indexer-test --archive_uri $PG_CONN