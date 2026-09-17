#!/bin/bash

# The replayer resolves its constraint constants from the runtime profile
# (Genesis_constants.profiled), which falls back to "dev" when neither
# MINA_PROFILE nor the deb-installed /etc/coda/build_config/PROFILE file is
# present. The bare replayer.exe restored from the apps cache has neither, so we
# pin the profile to devnet -- matching the devnet sample_db fixture and the
# devnet build the binary came from (otherwise dev's ledger_depth/fees produce a
# mismatching ledger hash).
export MINA_PROFILE=devnet

source scripts/replayer-test.sh -i src/test/archive/sample_db/replayer_input_file.json -p $PG_CONN -a mina-replayer