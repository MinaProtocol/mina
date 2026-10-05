#!/bin/sh

# link core files for CI to help debug test failures

CORE_DIR=core_dumps

mkdir -p "$CORE_DIR"

# -exec rather than a for loop over the output: a core file name that
# contained whitespace would otherwise be split into several bad links.
# $CORE_DIR is pruned because -exec links as it walks, so without it find
# descends into the directory and trips over the links it just made.
find . -path "./$CORE_DIR" -prune -o \
  -name "core.[0-9]*.*" -exec ln -s "$(pwd)/{}" "$CORE_DIR/" \;
