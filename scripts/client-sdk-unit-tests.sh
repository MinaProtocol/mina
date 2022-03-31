#!/bin/bash

set -eo pipefail

# run client SDK tests in node

echo "Building client SDK..."
source ~/.profile
dune b src/app/client_sdk/client_sdk.bc.js --profile=dev
echo "Running unit tests in Javascript"
node src/app/client_sdk/tests/run_unit_tests.js

# the Rosetta encodings are not part of the client SDK as such,
# but the SDK relies on them, so it's reasonable to compare
# the encodings here, rather than create another CI test

# native
echo "Building native code for encodings..."
make rosetta_lib_encodings
echo "Running"
./_build/default/src/lib/rosetta_lib/test/test_encodings.exe > encodings.native

# js
echo "Building Javascript code for encodings..."
make client_sdk
echo "Running"
node src/app/client_sdk/tests/test_encodings.js > encodings.js

diff encodings.native encodings.js

if [ $? -ne 0 ]; then
    echo "Native and Javascript code generate different encodings";
    exit 1
fi

echo "SUCCESS"
