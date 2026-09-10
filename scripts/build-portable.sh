#!/usr/bin/env bash

set -eoux pipefail
PROFILE=$1

# List of dyn libraries we don't want to package in portable build
DONT_PACKAGE='linux-vdso\.so\..+|ld-linux-.+\.so\..+|libc\.so\..+|libpthread\.so\..+|librt\.so\..+|libm\.so\..+|libdl\.so\..+|libresolv\.so\..+'

GIT_ROOT=`git rev-parse --show-toplevel`
pushd $GIT_ROOT 

portable_root=$PWD/_build_portable
rm -rf $portable_root

echo "Building mina"
portable_bin=$portable_root/bin
mkdir -p $portable_bin

[ -z "${IN_NIX_SHELL-}" ] && eval `opam env`
DUNE_PROFILE=$PROFILE make build
DUNE_PROFILE=$PROFILE dune build @install

build_bin=_build/install/default/bin

portable_lib=$portable_root/lib
mkdir -p $portable_lib

for source_exe in $build_bin/*; do
  target_exe=$portable_bin/`basename $source_exe`

  echo "Packaging executable $source_exe -> $target_exe"
  cp $source_exe $target_exe

  ldd "$target_exe" | awk '/=>/ {print $3}' | while read -r resolved_lib; do

      [[ -z "$resolved_lib" ]] && continue
      libname=$(basename "$resolved_lib")

      target_lib="$portable_lib/$libname"
      
      if [[ ! $libname =~ $DONT_PACKAGE ]] && [[ ! -f $target_lib ]]; then
          echo "Packaging dynamic library $resolved_lib -> $target_lib"
          cp $resolved_lib $target_lib
      fi
  done

  chmod u+w "$target_exe"
  patchelf --set-rpath '$ORIGIN/../lib' --force-rpath $target_exe
  chmod u-w "$target_exe"
done

echo "Copying libp2p_helper"
libp2p_binary=${MINA_LIBP2P_HELPER_PATH:-$PWD/src/app/libp2p_helper/result/bin/libp2p_helper}
cp $libp2p_binary $portable_bin/mina-libp2p_helper

popd
