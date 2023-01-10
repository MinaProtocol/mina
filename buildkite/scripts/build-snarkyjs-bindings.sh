#!/bin/bash

set -eo pipefail
source ~/.profile

echo "Build SnarkyJS..."
./scripts/update-snarkyjs-bindings.sh
