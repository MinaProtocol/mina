#!/bin/bash
set -euo pipefail

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd $SCRIPTPATH/../src/_build

PROJECT="coda-$(echo "$DUNE_PROFILE" | tr _ -)"
DATE=$(date +%Y-%m-%d)
GITHASH=$(git rev-parse --short=8 HEAD)
GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD |  sed 's!/!-!; s!_!-!g' )

set +u
# Identify All Artifacts by Branch and Git Hash

PVKEYHASH=$(./default/app/cli/src/coda.exe internal snark-hashes | sort | md5sum | cut -c1-8)
VERSION="${CIRCLE_BUILD_NUM}-${GITBRANCH}-${GITHASH}-PV${PVKEYHASH}"

BUILDDIR="${PROJECT}_${VERSION}"

mkdir -p ${BUILDDIR}/DEBIAN
cat << EOF > ${BUILDDIR}/DEBIAN/control
Package: ${PROJECT}
Version: ${VERSION}
Section: base
Priority: optional
Architecture: amd64
Depends: libssl1.1, libprocps6, libgmp10, libffi6, libgomp1, miniupnpc, coda-kademlia
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
cp ./default/app/logproc/logproc.exe ${BUILDDIR}/usr/local/bin/coda-logproc

# Better approach for packaging keys
# Identify actual keys used in build
echo "Checking PV keys"
mkdir -p ${BUILDDIR}/var/lib/coda
compile_keys=$(./default/app/cli/src/coda.exe internal snark-hashes)
for key in $compile_keys
do
    echo -n "Looking for keys matching: ${key} -- "
    if [ -f "/var/lib/coda/${key}_proving" ]; then
        echo " [OK] found in stable key set"
        cp /var/lib/coda/${key}* ${BUILDDIR}/var/lib/coda/.
    elif [ -f "/tmp/coda_cache_dir/${key}_proving" ]; then
        echo " [WARN] found in compile-time set"
        cp /tmp/coda_cache_dir/${key}* ${BUILDDIR}/var/lib/coda/.
    else
        echo "Key not found!"
    fi
done

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
ls -lh coda*.deb

# Tar up keys for an artifact
echo "------------------------------------------------------------"
if [ -z "$(ls -A ${BUILDDIR}/var/lib/coda)" ]; then
    echo "PV Key Dir Empty"
    touch ${cwd}/coda_pvkeys_EMPTY
else
    echo "Creating PV Key Tar"
    pushd ${BUILDDIR}/var/lib/coda
    tar -cvjf ${cwd}/coda_pvkeys_${GITHASH}_${DUNE_PROFILE}.tar.bz2 * ; \
    popd
fi
ls -lh coda_pvkeys_*


# second deb without the proving keys
echo "------------------------------------------------------------"
echo "Building deb without keys:"
BUILDDIRNOKEYS="${PROJECT}-noprovingkeys_${VERSION}"

cat << EOF > ${BUILDDIR}/DEBIAN/control
Package: ${PROJECT}-noprovingkeys
Version: ${VERSION}
Section: base
Priority: optional
Architecture: amd64
Depends: libssl1.1, libprocps6, libgmp10, libffi6, libgomp1, miniupnpc, coda-kademlia
License: Apache-2.0
Homepage: https://codaprotocol.com/
Maintainer: o(1)Labs <build@o1labs.org>
Description: Coda Client and Daemon
 Coda Protocol Client and Daemon
 Built from ${GITHASH}
EOF

# remove proving keys
rm -f ${BUILDDIR}/var/lib/coda/*_proving
mv ${BUILDDIR} ${BUILDDIRNOKEYS}

# build another deb
dpkg-deb --build ${BUILDDIRNOKEYS}
ls -lh coda*.deb
