#!/bin/bash

#
# Selects the correct versions of particular opam deps
#

set -eou pipefail

RES=()
for lib in $@; do
  RES+=($(cat src/opam.export | grep '"'"$lib"'\.' | awk -F'"' '{ print $2 }'))
done

echo "${RES[@]}"

