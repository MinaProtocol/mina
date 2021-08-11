#!/bin/bash

yarn build

cp dist/snarkyjs_chrome.js chrome_test/snarkyjs_chrome.js

pushd chrome_test/

python3 server.py

