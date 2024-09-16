#!/bin/bash

# Script collects binaries and keys and builds deb archives.

set -eox pipefail

# In case of running this script on detached head, script has difficulties in finding out
# what is the current 
while [[ "$#" -gt 0 ]]; do case $1 in
  -b|--branch-name) BRANCH_NAME_OPT="-b $2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done


SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
source ${SCRIPTPATH}/../export-git-env-vars.sh "$BRANCH_NAME_OPT"

echo "after export"

source ${SCRIPTPATH}/builder-helpers.sh
  
if [ $# -eq 0 ]
  then
    echo "No arguments supplied. Building all known debian packages"
    build_logproc_deb
    build_keypair_deb
    build_archive_deb
    build_batch_txn_deb
    build_daemon_berkeley_deb
    build_daemon_mainnet_deb
    build_daemon_devnet_deb
    build_test_executive_deb
    build_functional_test_suite_deb
    build_zkapp_test_transaction_deb

  else 
    for i in "$@"; do
      if [[ $(type -t "build_${i}_deb") == function ]] 
      then 
          echo "Building $i debian package"
          "build_${i}_deb"
      else 
        echo "invalid debian package name '$i'"
        exit 1
      fi
    done
fi