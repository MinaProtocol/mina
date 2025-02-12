#!/bin/bash

# script requires to have side postgres docker with setup archive

SCRIPTPATH="$( cd "$(dirname "$0")" || exit 1 ; pwd -P )"

source "${SCRIPTPATH}/../export-git-env-vars.sh"
source "${SCRIPTPATH}/../debian/install.sh" "mina-test-suite"
source "${SCRIPTPATH}/../../scripts/replayer-test.sh -i /etc/mina/test/archive/sample_db/replayer_input_file.json -p $PG_CONN -a mina-replayer