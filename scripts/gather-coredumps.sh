#!/bin/sh

# gather core files for CI to help debug test failures

CORE_DIR=core_dumps

rm -rf $CORE_DIR
mkdir $CORE_DIR

for file in `find . -name "core.[0-9]*.*"` ;
  do cp "$file" $CORE_DIR/ ;
done
