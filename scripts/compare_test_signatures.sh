#!/bin/sh

set -e

# compare test signatures generated:
# - in native executable
# - in JS code

# build executables

# native
echo "Building native code..."
make client_sdk_test_sigs
echo "Running"
./_build/default/src/app/client_sdk/tests/test_signatures.exe > nat.json

# js
echo "Building JS code..."
dune b src/app/client_sdk/client_sdk.bc.js --profile=dev
echo "Running"
node src/app/client_sdk/tests/test_signatures.js > js.json

# we've been careful so that the output formatting of all the signatures is the same
# so we can use diff (rather parsing the JSON with Python or such)

diff -q nat.json js.json

if [ $? -ne 0 ]; then
    echo "Native and JS code generate different signatures";
    exit 1
fi

echo "SUCCESS"
