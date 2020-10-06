#!/bin/sh
set -e -o pipefail
[ "$1" != "" ] || (echo 'missing argument' && exit 1)
graph_node="$1"
filename=$(echo "$graph_node" | sed -e 's/\//-/g')
gvpr -c "-a$graph_node" -fgvpr/rev.g deps.dot | gvpr "-a$graph_node" -fgvpr/fwd.g > "deps-$filename.dot"
dot -Tpng "deps-$filename.dot" > "deps-$filename.png"
