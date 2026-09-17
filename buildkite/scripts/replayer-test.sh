#!/bin/bash

# devnet matches the sample_db fixture and the devnet build the binary came from.
source scripts/replayer-test.sh --profile devnet -i src/test/archive/sample_db/replayer_input_file.json -p $PG_CONN -a mina-replayer