#!/bin/sh
set -e -o pipefail
maintenance_dir="$(realpath $(dirname $0))"
[ "$(which dune-deps)" != '' ] || (echo 'missing required executable "dune-deps"; try `opam install dune-deps`' && exit 1)
[ "$(pwd)" == "$maintenance_dir" ] && cd ..
dune-deps | tred > "$maintenance_dir/deps.dot"
dot -Tpng "$maintenance_dir/deps.dot" > "$maintenance_dir/deps.png"
