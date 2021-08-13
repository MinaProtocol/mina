#!/bin/bash

yarn build

cp chrome_test/server.py ./dist

cp chrome_test/index.html ./dist

pushd dist

python3 server.py

