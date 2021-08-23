#!/bin/bash

yarn build-dev
pushd dist
python3 server.py

