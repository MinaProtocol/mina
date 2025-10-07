#!/bin/bash

set -eo pipefail

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

git config --global --add safe.directory /workdir
source buildkite/scripts/export-git-env-vars.sh

source buildkite/scripts/debian/update.sh --verbose

source buildkite/scripts/debian/install.sh "mina-test-suite-instrumented,mina-base-instrumented" 1

pip3 install -r scripts/benchmarks/requirements.txt