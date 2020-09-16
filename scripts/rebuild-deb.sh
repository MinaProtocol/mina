#!/bin/bash

# Script collects binaries and keys and builds deb archives.

set -euo pipefail

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd "${SCRIPTPATH}/../_build"

GITHASH=$(git rev-parse --short=7 HEAD)
GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD |  sed 's!/!-!; s!_!-!g' )
GITTAG=$(git describe --abbrev=0)

# Identify All Artifacts by Branch and Git Hash
set +u
PVKEYHASH=$(./default/src/app/cli/src/coda.exe internal snark-hashes | sort | md5sum | cut -c1-8)

PROJECT="coda-$(echo "$DUNE_PROFILE" | tr _ -)"

BUILD_NUM=${BUILDKITE_BUILD_NUM}
BUILD_URL=${BUILDKITE_BUILD_URL}

if [ "$GITBRANCH" == "master" ]; then
    VERSION="${GITTAG}-${GITHASH}"
else
    VERSION="${GITTAG}+${BUILD_NUM}-${GITBRANCH}-${GITHASH}-PV${PVKEYHASH}"
fi

# Export variables for use with downstream steps
echo "export CODA_DEB_VERSION=$VERSION" >> /tmp/DOCKER_DEPLOY_ENV
echo "export CODA_PROJECT=$PROJECT" >> /tmp/DOCKER_DEPLOY_ENV
echo "export CODA_GIT_HASH=$GITHASH" >> /tmp/DOCKER_DEPLOY_ENV
echo "export CODA_GIT_BRANCH=$GITBRANCH" >> /tmp/DOCKER_DEPLOY_ENV
echo "export CODA_GIT_TAG=$GITTAG" >> /tmp/DOCKER_DEPLOY_ENV

if [[ "$1" == "optimized" ]] ; then
    echo "Optimized deb"
    VERSION=${VERSION}_optimized
else
    echo "Standard deb"
    VERSION=${VERSION}
fi

BUILDDIR="deb_build"

mkdir -p "${BUILDDIR}/DEBIAN"
cat << EOF > "${BUILDDIR}/DEBIAN/control"
Package: ${PROJECT}
Version: ${VERSION}
Section: base
Priority: optional
Architecture: amd64
Depends: libffi6, libgmp10, libgomp1, libjemalloc1, libprocps6, libssl1.1, miniupnpc, postgresql
Conflicts: coda-discovery
License: Apache-2.0
Homepage: https://codaprotocol.com/
Maintainer: o(1)Labs <build@o1labs.org>
Description: Coda Client and Daemon
 Coda Protocol Client and Daemon
 Built from ${GITHASH} by ${BUILD_URL}
EOF

echo "------------------------------------------------------------"
echo "Control File:"
cat "${BUILDDIR}/DEBIAN/control"

echo "------------------------------------------------------------"
# Binaries
mkdir -p "${BUILDDIR}/usr/local/bin"
cp ./default/src/app/cli/src/coda.exe "${BUILDDIR}/usr/local/bin/coda"
ls -l ../src/app/libp2p_helper/result/bin
p2p_path="${BUILDDIR}/usr/local/bin/coda-libp2p_helper"
cp ../src/app/libp2p_helper/result/bin/libp2p_helper $p2p_path
chmod +w $p2p_path
# Only for nix builds
# patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 "${BUILDDIR}/usr/local/bin/coda-libp2p_helper"
chmod -w $p2p_path
cp ./default/src/app/logproc/logproc.exe "${BUILDDIR}/usr/local/bin/coda-logproc"
cp ./default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe "${BUILDDIR}/usr/local/bin/coda-create-genesis"

# Build Config
mkdir -p "${BUILDDIR}/etc/coda/build_config"
cp ../src/config/"$DUNE_PROFILE".mlh "${BUILDDIR}/etc/coda/build_config/BUILD.mlh"
rsync -Huav ../src/config/* "${BUILDDIR}/etc/coda/build_config/."

# Keys
# Identify actual keys used in build
echo "Checking PV keys"
mkdir -p "${BUILDDIR}/var/lib/coda"
compile_keys=$(./default/src/app/cli/src/coda.exe internal snark-hashes)
for key in $compile_keys
do
    echo -n "Looking for keys matching: ${key} -- "

    # Awkward, you can't do a filetest on a wildcard - use loops
    for f in  /tmp/s3_cache_dir/${key}*; do
        if [ -e "$f" ]; then
            echo " [OK] found key in s3 key set"
            cp /tmp/s3_cache_dir/${key}* "${BUILDDIR}/var/lib/coda/."
            break
        fi
    done

    for f in  /var/lib/coda/${key}*; do
        if [ -e "$f" ]; then
            echo " [OK] found key in stable key set"
            cp /var/lib/coda/${key}* "${BUILDDIR}/var/lib/coda/."
            break
        fi
    done

    for f in  /tmp/coda_cache_dir/${key}*; do
        if [ -e "$f" ]; then
            echo " [WARN] found key in compile-time set"
            cp /tmp/coda_cache_dir/${key}* "${BUILDDIR}/var/lib/coda/."
            break
        fi
    done
done

# Genesis Ledger Copy
for f in /tmp/coda_cache_dir/genesis*; do
    cp /tmp/coda_cache_dir/genesis_state/genesis* "${BUILDDIR}/var/lib/coda/."
    cp /tmp/s3_cache_dir/genesis_state/genesis* "${BUILDDIR}/var/lib/coda/."
done

#copy config.json
cp ../genesis_ledgers/phase_three/config.json "${BUILDDIR}/var/lib/coda/config_${VERSION}.json"

# Bash autocompletion
# NOTE: We do not list bash-completion as a required package,
#       but it needs to be present for this to be effective
mkdir -p "${BUILDDIR}/etc/bash_completion.d"
cwd=$(pwd)
export PATH=${cwd}/${BUILDDIR}/usr/local/bin/:${PATH}
env COMMAND_OUTPUT_INSTALLATION_BASH=1 coda  > "${BUILDDIR}/etc/bash_completion.d/coda"

# echo contents of deb
echo "------------------------------------------------------------"
echo "Deb Contents:"
find "${BUILDDIR}"

# Build the package
echo "------------------------------------------------------------"
fakeroot dpkg-deb --build "${BUILDDIR}" ${PROJECT}_${VERSION}.deb
ls -lh coda*.deb

# Tar up keys for an artifact
echo "------------------------------------------------------------"
if [ -z "$(ls -A ${BUILDDIR}/var/lib/coda)" ]; then
    echo "PV Key Dir Empty"
    touch "${cwd}/coda_pvkeys_EMPTY"
else
    echo "Creating PV Key Tar"
    pushd "${BUILDDIR}/var/lib/coda"
    tar -cvjf "${cwd}"/coda_pvkeys_"${GITHASH}"_"${DUNE_PROFILE}".tar.bz2 * ; \
    popd
fi
ls -lh coda_pvkeys_*

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
Homepage: https://codaprotocol.com/
Maintainer: o(1)Labs <build@o1labs.org>
Description: Coda Client and Daemon
 Coda Protocol Client and Daemon
 Built from ${GITHASH} by ${BUILD_URL}
EOF

# remove proving keys
rm -f "${BUILDDIR}"/var/lib/coda/*_proving

# build another deb
fakeroot dpkg-deb --build "${BUILDDIR}" ${PROJECT}-noprovingkeys_${VERSION}.deb
ls -lh coda*.deb
