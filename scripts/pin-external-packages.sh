#!/bin/sh

# update packages used by CI
git submodule sync && git submodule update --init --recursive
