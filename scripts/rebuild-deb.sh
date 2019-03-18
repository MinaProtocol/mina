#!/bin/bash

set -euo pipefail

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd $SCRIPTPATH/../src/_build

PROJECT="coda-$(echo "$DUNE_PROFILE" | tr _ -)"
DATE=$(date +%Y-%m-%d)
GITHASH=$(git rev-parse --short=8 HEAD)

# Identify CI builds by build number
if [[ -v CIRCLE_BUILD_NUM ]]; then
    VERSION="0.1.${CIRCLE_BUILD_NUM}-CI"
else
    VERSION="0.1.${DATE}-${GITHASH}"
fi
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

cat ${BUILDDIR}/DEBIAN/control

mkdir -p ${BUILDDIR}/usr/local/bin
cp ./default/app/cli/src/coda.exe ${BUILDDIR}/usr/local/bin/coda
cp ./default/app/logproc/logproc.exe ${BUILDDIR}/usr/local/bin/logproc


# Include proving/verifying

# Look in tmp first (compile time generated keys)
tmp_keys=$(shopt -s nullglob dotglob; echo /tmp/coda_cache_dir/*)
if (( ${#tmp_keys} ))
then
    mkdir -p ${BUILDDIR}/var/lib/coda
    cp /tmp/coda_cache_dir/* ${BUILDDIR}/var/lib/coda
else
    # Look instead for packaged keys (downloaded before build time)
    var_keys=$(shopt -s nullglob dotglob; echo /var/lib/coda/*)
    if (( ${#var_keys} ))
    then
	mkdir -p ${BUILDDIR}/var/lib/coda
	cp /var/lib/coda/* ${BUILDDIR}/var/lib/coda
    fi
fi

# Bash autocompletion
# NOTE: We do not list bash-completion as a required package,
#       but it needs to be present for this to be effective
mkdir -p ${BUILDDIR}/etc/bash_completion.d
cwd=$(pwd)
export PATH=${cwd}/${BUILDDIR}/usr/local/bin/:${PATH}
env COMMAND_OUTPUT_INSTALLATION_BASH=1 coda  > ${BUILDDIR}/etc/bash_completion.d/coda

# Build the package
dpkg-deb --build ${BUILDDIR}
ln -s -f ${BUILDDIR}.deb coda.deb
