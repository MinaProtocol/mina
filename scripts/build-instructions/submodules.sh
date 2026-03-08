#!/usr/bin/env bash

# Pull git submodules — required before building Mina.
# This corresponds to step 3 of the Quick Start section in README-dev.md.

set -eo pipefail

git submodule update --init --recursive
git config --local --add submodule.recurse true
