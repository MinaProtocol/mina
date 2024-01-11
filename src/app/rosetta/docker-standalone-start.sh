#!/bin/bash

set -eou pipefail

# Allows configuring the port that each service runs on.
# To interact with rosetta, use MINA_ROSETTA_PORT.
MINA_ROSETTA_PORT=${MINA_ROSETTA_PORT:=3087}
# This script does not run a daemon or archive node at all, so the remaining MINA_*_PORTs from other scripts are not used here
LOG_LEVEL=${LOG_LEVEL:=Debug}

# rosetta
echo "========================= STARTING ROSETTA API on PORT ${MINA_ROSETTA_PORT} ==========================="
mina-rosetta \
  -log-level "${LOG_LEVEL}" \
  -port "${MINA_ROSETTA_PORT}" $@
