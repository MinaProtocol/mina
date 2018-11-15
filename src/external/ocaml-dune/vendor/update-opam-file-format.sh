#!/bin/bash

version=2.0.0~beta

set -e -o pipefail

TMP="$(mktemp -d)"
trap "rm -rf $TMP" EXIT

rm -rf opam-file-format
mkdir -p opam-file-format/src

(cd $TMP && opam source opam-file-format.$version)

SRC=$TMP/opam-file-format.$version

cp -v $SRC/src/*.{ml,mli,mll,mly} opam-file-format/src

git checkout opam-file-format/src/jbuild
git add -A .
