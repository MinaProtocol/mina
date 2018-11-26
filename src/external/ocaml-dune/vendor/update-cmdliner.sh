#!/bin/bash

version=1.0.0

set -e -o pipefail

TMP="$(mktemp -d)"
trap "rm -rf $TMP" EXIT

rm -rf cmdliner
mkdir -p cmdliner/src

(cd $TMP && opam source cmdliner.$version)

SRC=$TMP/cmdliner.$version

cp -v $SRC/LICENSE.md cmdliner
cp -v $SRC/src/*.{ml,mli} cmdliner/src

git checkout cmdliner/src/jbuild
git add -A .
