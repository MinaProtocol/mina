#!/bin/bash

set -euo pipefail

PROJECT='codaclient'

MAJORVERSION=0
DATE=`date +%m-%d`
GITHASH=`git rev-parse --short HEAD`

VERSION="${MAJORVERSION}.${DATE}.${GITHASH}"
BUILDDIR="${PROJECT}_${VERSION}"

cd _build

mkdir -p ${BUILDDIR}/DEBIAN
cat << EOF > ${BUILDDIR}/DEBIAN/control
Package: ${PROJECT}
Version: ${VERSION}
Section: base
Priority: optional
Architecture: amd64
Depends: libssl1.1, libprocps6, libgmp10, libffi6
Maintainer: O1Labs <build@o1labs.org>
Description: Coda Client
 Coda Protocol Client
EOF

mkdir -p ${BUILDDIR}/usr/local/bin
cp ./default/app/nanobit/src/cli.exe ${BUILDDIR}/usr/local/bin/cli
cp ./default/app/logproc/src/logproc.exe ${BUILDDIR}/usr/local/bin/logproc
cp .././app/kademlia-haskell/result/bin/kademlia ${BUILDDIR}/usr/local/bin/kademlia

# Ugly hack #1 to patch elf interpreter to get past nix-build
if [ ! -f /usr/bin/patchelf ]; then
    sudo apt install patchelf
fi
sudo patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2  ${BUILDDIR}/usr/local/bin/kademlia

# Ugly hack #2 to support expected location of kademlia binary
mkdir -p ${BUILDDIR}/app/kademlia-haskell/result/bin/
ln -s /usr/local/bin/kademlia ${BUILDDIR}/app/kademlia-haskell/result/bin/kademlia

dpkg-deb --build ${BUILDDIR}

ln -s -f ${BUILDDIR}.deb codaclient.deb
