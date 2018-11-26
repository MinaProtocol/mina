#!/bin/bash

set -e -o pipefail

TMP="$(mktemp -d)"
trap "rm -rf $TMP" EXIT

rm -rf usexp
mkdir -p usexp/src

(cd $TMP && git clone https://github.com/janestreet/usexp.git)

SRC=$TMP/usexp

cp -v $SRC/LICENSE.md usexp

cp -v $SRC/src/*.{ml,mli} usexp/src

git checkout usexp/src/jbuild
git add -A .
