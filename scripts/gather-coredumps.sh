#!/bin/sh

for file in `find . -name "core.[0-9]*.*"` ;
  do cp "$file" . ;
done
