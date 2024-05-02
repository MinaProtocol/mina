#!/bin/bash

# Script collects binaries and keys and builds deb archives.

source scripts/deb-builder-helpers.sh

# always build log proc since it is often an dependency
# TODO: remove logproc as external dependency 
build_logproc_deb
   
if [ $# -eq 0 ]
  then
    echo "No arguments supplied. Building all known debian packages"
    build_keypair_deb
    build_archive_deb
    build_archive_migration_deb
    build_batch_txn_deb
    build_daemon_deb
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

# TODO: Find a way to package keys properly without blocking/locking in CI
# TODO: Keys should be their own package, which this 'non-noprovingkeys' deb depends on
# For now, deleting keys in /tmp/ so that the complicated logic below for moving them short-circuits and both packages are built without keys
rm -rf /tmp/s3_cache_dir /tmp/coda_cache_dir

# Keys
# Identify actual keys used in build
# NOTE: Moving the keys from /tmp because of storage constraints. This is OK
# because building deb is the last step and therefore keys, genesis ledger, and
# proof are not required in /tmp
echo "Checking PV keys"
mkdir -p "${BUILDDIR}/var/lib/coda"
compile_keys=("step" "vk-step" "wrap" "vk-wrap")
for key in ${compile_keys[*]}
do
    echo -n "Looking for keys matching: ${key} -- "

    # Awkward, you can't do a filetest on a wildcard - use loops
    for f in  /tmp/s3_cache_dir/${key}*; do
        if [ -e "$f" ]; then
            echo " [OK] found key in s3 key set"
            mv /tmp/s3_cache_dir/${key}* "${BUILDDIR}/var/lib/coda/."
            break
        fi
    done

    for f in  /var/lib/coda/${key}*; do
        if [ -e "$f" ]; then
            echo " [OK] found key in stable key set"
            mv /var/lib/coda/${key}* "${BUILDDIR}/var/lib/coda/."
            break
        fi
    done

    for f in  /tmp/coda_cache_dir/${key}*; do
        if [ -e "$f" ]; then
            echo " [WARN] found key in compile-time set"
            mv /tmp/coda_cache_dir/${key}* "${BUILDDIR}/var/lib/coda/."
            break
        fi
    done
done

# Build mina block producer sidecar
if ${MINA_BUILD_MAINNET} # only builds on mainnet-like branches
then
  ../automation/services/mina-bp-stats/sidecar/build.sh # only builds on mainnet-like branches
  rm -rf "${BUILDDIR}"
fi

if ${MINA_BUILD_MAINNET} # only builds on mainnet-like branches
then
  echo "---- Built all packages including mainnet, devnet, and the sidecar"
else
  echo "---- Not a mainnet-like branch, only built berkeley and beyond packages"
fi

echo "pwd"

pwd

echo "deb"

ls -lh mina*.deb
