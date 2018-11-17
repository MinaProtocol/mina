#!/bin/bash

version=1.7.1

set -e -o pipefail

TMP="$(mktemp -d)"
trap "rm -rf $TMP" EXIT

rm -rf re
mkdir -p re/src

(cd $TMP && opam source re.$version)

SRC=$TMP/re.$version

cp -v $SRC/LICENSE re

for m in re re_automata re_cset re_fmt; do
    for ext in ml mli; do
        fn=$SRC/lib/$m.$ext
        [[ -f $fn ]] && cp -v $fn re/src
    done
done

git checkout re/src/jbuild
git add -A .
