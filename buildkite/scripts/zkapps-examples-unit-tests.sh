#!/bin/bash

set -eo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <dune-profile>"
    exit 1
fi

profile=$1

if [ "$NIGHTLY" = true ]
then
  source ~/.profile

  echo "--- Building zkapps_examples"
  time dune build --profile=$profile src/app/zkapps_examples

  echo "--- Testing zkapps_examples"
  time dune runtest --profile=$profile src/app/zkapps_examples
fi
