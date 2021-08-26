#!/bin/bash

set -eo pipefail

echo "zexe standardize"
# Mac uses an ancient sed that needs an extra argument to -i..
case "$(uname -s)" in
    Darwin*) sed -i "" 's/+bmi2,+adx/-bmi2,-adx/g' src/lib/marlin_plonk_bindings/stubs/dune;;
    *) sed -i 's/+bmi2,+adx/-bmi2,-adx/g' src/lib/marlin_plonk_bindings/stubs/dune;;
esac
