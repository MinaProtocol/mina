#!/bin/bash

# script requires to have side postgres docker with setup archive

SCRIPTPATH="$( cd "$(dirname "$0")" || exit 1 ; pwd -P )"

source "${SCRIPTPATH}/../export-git-env-vars.sh"
source "${SCRIPTPATH}/../debian/install.sh" "mina-test-suite"
source "${SCRIPTPATH}/../../scripts/tests/archive_patch_test.sh"