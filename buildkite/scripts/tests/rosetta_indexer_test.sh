#!/bin/bash

# script requires to have side postgres docker with setup archive

set -eox pipefail

SCRIPTPATH="$( cd "$(dirname "$0")" || exit 1 ; pwd -P )"
source "${SCRIPTPATH}/../export-git-env-vars.sh"
source "${SCRIPTPATH}/../debian/install.sh" "mina-rosetta-berkeley" 1

mina-rosetta-indexer-test --archive_uri $PG_CONN