#!/bin/bash

set -euo pipefail

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

cd $SCRIPTPATH/../src/_build

PROJECT='codaclient'

MAJORVERSION=0
DATE=`date +%m-%d`
GITHASH=`git rev-parse --short=8 HEAD`

VERSION="${MAJORVERSION}.${DATE}.${GITHASH}"
BUILDDIR="${PROJECT}_${VERSION}"

mkdir -p ${BUILDDIR}/DEBIAN
cat << EOF > ${BUILDDIR}/DEBIAN/control
Package: ${PROJECT}
Version: ${VERSION}
Section: base
Priority: optional
Architecture: amd64
Depends: libssl1.1, libprocps6, libgmp10, libffi6, libgomp1
Maintainer: O1Labs <build@o1labs.org>
Description: Coda Client
 Coda Protocol Client
EOF

mkdir -p ${BUILDDIR}/usr/local/bin
cp ./default/app/cli/src/coda.exe ${BUILDDIR}/usr/local/bin/coda
cp ./default/app/logproc/src/logproc.exe ${BUILDDIR}/usr/local/bin/logproc
cp ../app/kademlia-haskell/result/bin/kademlia ${BUILDDIR}/usr/local/bin/coda-kademlia

# verification keys
if [ -d "/var/lib/coda" ]; then
    mkdir -p ${BUILDDIR}/var/lib/coda
    cp /var/lib/coda/*_verification ${BUILDDIR}/var/lib/coda
else
    if [ -d "/tmp/coda_cache_dir" ]; then
        mkdir -p ${BUILDDIR}/var/lib/coda
        cp /tmp/coda_cache_dir/*_verification ${BUILDDIR}/var/lib/coda
    fi
fi

# Ugly hack #1 to patch elf interpreter to get past nix-build
if [ ! -f /usr/bin/patchelf ]; then
    sudo apt install patchelf
fi
sudo patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2  ${BUILDDIR}/usr/local/bin/coda-kademlia

# Ugly hack #2 to support expected location of kademlia binary
mkdir -p ${BUILDDIR}/app/kademlia-haskell/result/bin/
ln -s /usr/local/bin/coda-kademlia ${BUILDDIR}/app/kademlia-haskell/result/bin/kademlia

# Bash autocompletion for coda
# NOTE: We do not list bash-completion as a required package, 
#       but it needs to be present for this to be effective
mkdir -p ${BUILDDIR}/etc/bash_completion.d
cwd=$(pwd)
export PATH=${cwd}/${BUILDDIR}/usr/local/bin/:${PATH}
env COMMAND_OUTPUT_INSTALLATION_BASH=1 coda  > ${BUILDDIR}/etc/bash_completion.d/coda

# Build the package
dpkg-deb --build ${BUILDDIR}

ln -s -f ${BUILDDIR}.deb codaclient.deb
