#!/bin/bash

# Script collects binaries and keys and builds deb archives.

set -euo pipefail

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd "${SCRIPTPATH}/../_build"

GITHASH=$(git rev-parse --short=7 HEAD)
GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD |  sed 's!/!-!; s!_!-!g' )
GITTAG=$(git describe --abbrev=0)
GITHASH_CONFIG=$(git rev-parse --short=8 --verify HEAD)

# Identify All Artifacts by Branch and Git Hash
set +u
PVKEYHASH=$(./default/src/app/cli/src/mina.exe internal snark-hashes | sort | md5sum | cut -c1-8)


# TODO: be smarter about this when we introduce a devnet package
#if [[ "$GITBRANCH" == "master" ]] ; then
DUNE_PROFILE="mainnet"
#fi

PROJECT="mina-$(echo "$DUNE_PROFILE" | tr _ -)"

BUILD_NUM=${BUILDKITE_BUILD_NUM}
BUILD_URL=${BUILDKITE_BUILD_URL}

# Load in env vars for githash/branch/etc.
source "${SCRIPTPATH}/../buildkite/scripts/export-git-env-vars.sh"

cd "${SCRIPTPATH}/../_build"

if [[ "$1" == "optimized" ]] ; then
    echo "Optimized deb"
    VERSION=${VERSION}_optimized
else
    echo "Standard deb"
    VERSION=${VERSION}
fi

BUILDDIR="deb_build"

##################################### GENERATE KEYPAIR PACKAGE #######################################

mkdir -p "${BUILDDIR}/DEBIAN"
cat << EOF > "${BUILDDIR}/DEBIAN/control"

Package: mina-generate-keypair
Version: ${GENERATE_KEYPAIR_VERSION}
License: Apache-2.0
Vendor: none
Architecture: amd64
Maintainer: o(1)Labs <build@o1labs.org>
Installed-Size:
Depends: libssl1.1, libprocps6, libgmp10, libffi6, libgomp1
Section: base
Priority: optional
Homepage: https://minaprotocol.com/
Description: Utility to generate mina private/public keys in new format
 Utility to regenerate mina private public keys in new format
 Built from ${GITHASH} by ${BUILD_URL}
EOF

echo "------------------------------------------------------------"
echo "Control File:"
cat "${BUILDDIR}/DEBIAN/control"

# Binaries
mkdir -p "${BUILDDIR}/usr/local/bin"
cp ./default/src/app/generate_keypair/generate_keypair.exe "${BUILDDIR}/usr/local/bin/mina-generate-keypair"
cp ./default/src/app/validate_keypair/validate_keypair.exe "${BUILDDIR}/usr/local/bin/mina-validate-keypair"

# echo contents of deb
echo "------------------------------------------------------------"
echo "Deb Contents:"
find "${BUILDDIR}"

# Build the package
echo "------------------------------------------------------------"
fakeroot dpkg-deb --build "${BUILDDIR}" mina-generate-keypair_${GENERATE_KEYPAIR_VERSION}.deb
ls -lh mina*.deb

# Remove generate-keypair, validate-keypair binaries before other builds with the same dir
rm -f "${BUILDDIR}/usr/local/bin/mina-generate-keypair"
rm -f "${BUILDDIR}/usr/local/bin/mina-validate-keypair"

##################################### END GENERATE KEYPAIR PACKAGE #######################################

mkdir -p "${BUILDDIR}/DEBIAN"
cat << EOF > "${BUILDDIR}/DEBIAN/control"
Package: ${PROJECT}
Version: ${VERSION}
Section: base
Priority: optional
Architecture: amd64
Depends: libffi6, libgmp10, libgomp1, libjemalloc1, libprocps6, libssl1.1, miniupnpc, postgresql
Conflicts: mina-discovery
License: Apache-2.0
Homepage: https://minaprotocol.com/
Maintainer: o(1)Labs <build@o1labs.org>
Description: Mina Client and Daemon
 Mina Protocol Client and Daemon
 Built from ${GITHASH} by ${BUILD_URL}
EOF

echo "------------------------------------------------------------"
echo "Control File:"
cat "${BUILDDIR}/DEBIAN/control"

echo "------------------------------------------------------------"
# Binaries
mkdir -p "${BUILDDIR}/usr/local/bin"
cp ./default/src/app/cli/src/mina.exe "${BUILDDIR}/usr/local/bin/mina"
cp ./default/src/app/rosetta/rosetta.exe "${BUILDDIR}/usr/local/bin/mina-rosetta"
ls -l ../src/app/libp2p_helper/result/bin
p2p_path="${BUILDDIR}/usr/local/bin/coda-libp2p_helper"
cp ../src/app/libp2p_helper/result/bin/libp2p_helper $p2p_path
chmod +w $p2p_path
# Only for nix builds
# patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 "${BUILDDIR}/usr/local/bin/coda-libp2p_helper"
chmod -w $p2p_path
cp ./default/src/app/logproc/logproc.exe "${BUILDDIR}/usr/local/bin/coda-logproc"
cp ./default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe "${BUILDDIR}/usr/local/bin/coda-create-genesis"

mkdir -p "${BUILDDIR}/usr/lib/systemd/user"
cp ../scripts/mina.service "${BUILDDIR}/usr/lib/systemd/user/"

# Build Config
mkdir -p "${BUILDDIR}/etc/coda/build_config"
cp ../src/config/"$DUNE_PROFILE".mlh "${BUILDDIR}/etc/coda/build_config/BUILD.mlh"
rsync -Huav ../src/config/* "${BUILDDIR}/etc/coda/build_config/."


# TODO: Find a way to package keys properly without blocking/locking in CI
# For now, deleting keys in /tmp/ so that the complicated logic below for moving them short-circuits and both packages are built without keys
rm -rf /tmp/s3_cache_dir /tmp/coda_cache_dir

# Keys
# Identify actual keys used in build
#NOTE: Moving the keys from /tmp because of storage constraints. This is OK
# because building deb is the last step and therefore keys, genesis ledger, and
# proof are not required in /tmp
echo "Checking PV keys"
mkdir -p "${BUILDDIR}/var/lib/coda"
compile_keys=("step" "vk-step" "wrap" "vk-wrap" "tweedledee" "tweedledum")
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

# Copy the genesis ledgers and proofs as these are fairly small and very valueable to have l
# Genesis Ledger/proof/epoch ledger Copy
for f in /tmp/coda_cache_dir/genesis*; do
    if [ -e "$f" ]; then
        mv /tmp/coda_cache_dir/genesis* "${BUILDDIR}/var/lib/coda/."
    fi
done

# Copy genesis Ledger/proof/epoch ledger if they were downloaded from s3
for f in /tmp/s3_cache_dir/genesis*; do
    if [ -e "$f" ]; then
        mv /tmp/s3_cache_dir/genesis* "${BUILDDIR}/var/lib/coda/."
    fi
done

#copy config.json
cp '../genesis_ledgers/mainnet.json' "${BUILDDIR}/var/lib/coda/mainnet.json"
cp ../genesis_ledgers/devnet.json "${BUILDDIR}/var/lib/coda/devnet.json"
# The default configuration:
cp ../genesis_ledgers/mainnet.json "${BUILDDIR}/var/lib/coda/config_${GITHASH_CONFIG}.json"


# Bash autocompletion
# NOTE: We do not list bash-completion as a required package,
#       but it needs to be present for this to be effective
mkdir -p "${BUILDDIR}/etc/bash_completion.d"
cwd=$(pwd)
export PATH=${cwd}/${BUILDDIR}/usr/local/bin/:${PATH}
env COMMAND_OUTPUT_INSTALLATION_BASH=1 mina  > "${BUILDDIR}/etc/bash_completion.d/mina"

# echo contents of deb
echo "------------------------------------------------------------"
echo "Deb Contents:"
find "${BUILDDIR}"

# Build the package
echo "------------------------------------------------------------"
fakeroot dpkg-deb --build "${BUILDDIR}" ${PROJECT}_${VERSION}.deb
ls -lh mina*.deb


# second deb without the proving keys -- FIXME: DRY
echo "------------------------------------------------------------"
echo "Building deb without keys:"

cat << EOF > "${BUILDDIR}/DEBIAN/control"
Package: ${PROJECT}-noprovingkeys
Version: ${VERSION}
Section: base
Priority: optional
Architecture: amd64
Depends: libffi6, libgmp10, libgomp1, libjemalloc1, libprocps6, libssl1.1, miniupnpc
License: Apache-2.0
Homepage: https://minaprotocol.com/
Maintainer: o(1)Labs <build@o1labs.org>
Description: Mina Client and Daemon
 Mina Protocol Client and Daemon
 Built from ${GITHASH} by ${BUILD_URL}
EOF

# remove proving keys
rm -f "${BUILDDIR}"/var/lib/coda/step*
rm -f "${BUILDDIR}"/var/lib/coda/wrap*

# build another deb
fakeroot dpkg-deb --build "${BUILDDIR}" ${PROJECT}-noprovingkeys_${VERSION}.deb
ls -lh mina*.deb

#remove build dir to prevent running out of space on the host machine
rm -rf "${BUILDDIR}"

# Build mina block producer sidecar 
source ../automation/services/mina-bp-stats/sidecar/build.sh
ls -lh mina*.deb


# Export variables for use with downstream circle-ci steps (see buildkite/scripts/publish-deb.sh for BK DOCKER_DEPLOY_ENV)
echo "export CODA_DEB_VERSION=$VERSION" >> /tmp/DOCKER_DEPLOY_ENV
echo "export CODA_PROJECT=$PROJECT" >> /tmp/DOCKER_DEPLOY_ENV
echo "export CODA_GIT_HASH=$GITHASH" >> /tmp/DOCKER_DEPLOY_ENV
echo "export CODA_GIT_BRANCH=$GITBRANCH" >> /tmp/DOCKER_DEPLOY_ENV
echo "export CODA_GIT_TAG=$GITTAG" >> /tmp/DOCKER_DEPLOY_ENV
