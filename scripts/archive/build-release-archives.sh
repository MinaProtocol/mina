#!/bin/bash

# This script makes a .deb archive for the Mina Archive process
# and releases it to the AWS .deb repository packages.o1test.net

set -euo pipefail

# Set up variables for build
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd "${SCRIPTPATH}/../.."

source "buildkite/scripts/export-git-env-vars.sh"

cd _build

# Set dependencies based on debian release
SHARED_DEPS="libssl1.1, libgomp1, libpq-dev, "
case "${MINA_DEB_CODENAME}" in
  buster|focal|bullseye)
    ARCHIVE_DEPS="libjemalloc2"
    ;;
  stretch|bionic)
    ARCHIVE_DEPS="libjemalloc1"
    ;;
  *)
    echo "Unknown Debian codename provided: ${MINA_DEB_CODENAME}"; exit 1
    ;;
esac

echo "--- Building Mina archive package"


# Determina suffix for mina name. To preserve backward compatibility devnet profile won't have any suffix. 
# For others profiles we are adding suffix. For example '-lightnet'
case "${DUNE_PROFILE}" in
  devnet)
    PROJECT_SUFFIX=""
    ;;
  *)
    PROJECT_SUFFIX="-${DUNE_PROFILE}"
    ;;
esac



PROJECT="mina-archive${PROJECT_SUFFIX}"
BUILD_DIR="deb_build"

###### archiver deb

mkdir -p "${BUILD_DIR}/DEBIAN"
cat << EOF > "${BUILD_DIR}/DEBIAN/control"
Package: ${PROJECT}
Version: ${MINA_DEB_VERSION}
Section: base
Priority: optional
Architecture: amd64
Depends: ${SHARED_DEPS}${ARCHIVE_DEPS}
License: Apache-2.0
Homepage: https://minaprotocol.com/
Maintainer: O(1)Labs <build@o1labs.org>
Description: Mina Archive Process
 Compatible with Mina Daemon
 Built from ${GITHASH} by ${BUILDKITE_BUILD_URL:-"Mina CI"}
EOF

echo "------------------------------------------------------------"
echo "Control File:"
cat "${BUILD_DIR}/DEBIAN/control"

echo "------------------------------------------------------------"
# Binaries
mkdir -p "${BUILD_DIR}/usr/local/bin"
pwd
ls
cp ./default/src/app/archive/archive.exe "${BUILD_DIR}/usr/local/bin/mina-archive"
cp ./default/src/app/archive_blocks/archive_blocks.exe "${BUILD_DIR}/usr/local/bin/mina-archive-blocks"
cp ./default/src/app/extract_blocks/extract_blocks.exe "${BUILD_DIR}/usr/local/bin/mina-extract-blocks"
cp ./default/src/app/berkeley_migration/berkeley_migration.exe "${BUILD_DIR}/usr/local/bin/mina-berkeley-migration"
cp ./default/src/app/berkeley_account_tables/berkeley_account_tables.exe "${BUILD_DIR}/usr/local/bin/mina-berkeley-account-tables"

cp ./default/src/app/missing_blocks_auditor/missing_blocks_auditor.exe "${BUILD_DIR}/usr/local/bin/mina-missing-blocks-auditor"
cp ./default/src/app/replayer/replayer.exe "${BUILD_DIR}/usr/local/bin/mina-replayer"
cp ./default/src/app/swap_bad_balances/swap_bad_balances.exe "${BUILD_DIR}/usr/local/bin/mina-swap-bad-balances"
chmod --recursive +rx "${BUILD_DIR}/usr/local/bin"

# echo contents of deb
echo "------------------------------------------------------------"
echo "Deb Contents:"
find "${BUILD_DIR}"

# Build the package
echo "------------------------------------------------------------"
dpkg-deb --build "${BUILD_DIR}" ${PROJECT}_${MINA_DEB_VERSION}.deb
ls -lh mina*.deb

echo "--- Built ${PROJECT}_${MINA_DEB_VERSION}.deb"
