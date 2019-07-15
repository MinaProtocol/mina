#!/bin/bash
set -euo pipefail

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd $SCRIPTPATH/../src/_build

PROJECT="coda-$(echo "$DUNE_PROFILE" | tr _ -)"
DATE=$(date +%Y-%m-%d)
GITHASH=$(git rev-parse --short=8 HEAD)
GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD |  sed 's!/!-!; s!_!-!' )

set +u
# Identify All Artifacts by Branch and Git Hash

VERSION="0.0.1-${GITBRANCH}-${GITHASH}"

BUILDDIR="${PROJECT}_${VERSION}"

mkdir -p ${BUILDDIR}/DEBIAN
cat << EOF > ${BUILDDIR}/DEBIAN/control
Package: ${PROJECT}
Version: ${VERSION}
Section: base
Priority: optional
Architecture: amd64
Depends: libssl1.1, libprocps6, libgmp10, libffi6, libgomp1, coda-kademlia
License: Apache-2.0
Homepage: https://codaprotocol.com/
Maintainer: o(1)Labs <build@o1labs.org>
Description: Coda Client and Daemon
 Coda Protocol Client and Daemon
 Built from ${GITHASH}
EOF

echo "------------------------------------------------------------"
echo "Control File:"
cat ${BUILDDIR}/DEBIAN/control

echo "------------------------------------------------------------"
mkdir -p ${BUILDDIR}/usr/local/bin
cp ./default/app/cli/src/coda.exe ${BUILDDIR}/usr/local/bin/coda
cp ./default/app/logproc/logproc.exe ${BUILDDIR}/usr/local/bin/logproc

# Look for static and generated proving/verifying keys
var_keys=$(shopt -s nullglob dotglob; echo /var/lib/coda/*)
if (( ${#var_keys} )) ; then
    echo "Found PV keys in /var/lib/coda - stock keys"
    ls /var/lib/coda/*
	mkdir -p ${BUILDDIR}/var/lib/coda
	cp /var/lib/coda/* ${BUILDDIR}/var/lib/coda
fi

tmp_keys=$(shopt -s nullglob dotglob; echo /tmp/coda_cache_dir/*)
if (( ${#tmp_keys} )) ; then
    echo "Found PV keys in /tmp/coda_cache_dir - snark may have changed"
    ls /tmp/coda_cache_dir/*
    mkdir -p ${BUILDDIR}/var/lib/coda
    cp /tmp/coda_cache_dir/* ${BUILDDIR}/var/lib/coda
fi

# Bash autocompletion
# NOTE: We do not list bash-completion as a required package,
#       but it needs to be present for this to be effective
mkdir -p ${BUILDDIR}/etc/bash_completion.d
cwd=$(pwd)
export PATH=${cwd}/${BUILDDIR}/usr/local/bin/:${PATH}
env COMMAND_OUTPUT_INSTALLATION_BASH=1 coda  > ${BUILDDIR}/etc/bash_completion.d/coda

# echo contents of deb
echo "------------------------------------------------------------"
echo "Deb Contents:"
find ${BUILDDIR}

# Build the package
echo "------------------------------------------------------------"
dpkg-deb --build ${BUILDDIR}
ln -s -f ${BUILDDIR}.deb coda.deb
