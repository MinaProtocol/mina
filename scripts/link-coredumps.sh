#!/bin/sh

# link core files for CI to help debug test failures

CORE_DIR=core_dumps

mkdir -p $CORE_DIR

for file in `find . -name "core.[0-9]*.*"` ;
  do ln -s "`pwd`/$file" $CORE_DIR/ ;
done
