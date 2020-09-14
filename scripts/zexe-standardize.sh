#!/bin/bash

set -eo pipefail

echo "--- zexe standardize"
sed -i 's/+bmi2,+adx/-bmi2,-adx/g' src/lib/zexe/snarky-bn382/dune