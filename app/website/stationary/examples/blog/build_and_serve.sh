#!/bin/bash

oasis setup
make
if [ -d "_site" ]; then
  rm -r _site
fi
./main.native
pushd _site
python -m SimpleHTTPServer
popd
