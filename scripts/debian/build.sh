#!/bin/bash

# Script collects binaries and keys and builds deb archives.

set -eox pipefail

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

source ${SCRIPTPATH}/../export-git-env-vars.sh

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
    build_rosetta_berkeley_deb
    build_rosetta_mainnet_deb
    build_rosetta_devnet_deb
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