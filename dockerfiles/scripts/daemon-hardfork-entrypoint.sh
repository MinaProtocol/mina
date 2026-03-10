#!/bin/bash

# This script is used to determine which Mina application to run based on the presence of a hardfork signal directory.
# If the directory exists, it runs the `mina` application; otherwise, it runs the `mina-legacy` application.
# It also sets up the environment for the Mina daemon and executes the entrypoint script with the provided arguments.
# Should be used as an entrypoint for Docker containers running Mina.

set -euo pipefail

MINA_HF_SIGNAL_DIR="${MINA_HF_SIGNAL_DIR:-.mina-config/after-hardfork}"
MINA=mina
MINA_LEGACY=mina-legacy

if ! command -v ${MINA_LEGACY} >/dev/null 2>&1; then
   echo "Error: ${MINA_LEGACY} does not exist or is not in PATH." >&2
   echo "This entrypoint should be used only in hardfork docker images." >&2s
   echo "Please ensure that the ${MINA_LEGACY} binary is installed and available in your PATH." >&2
   exit 1
fi


# Check if the hardfork signal directory exists to determine which Mina application to run
if [ -d "${MINA_HF_SIGNAL_DIR}" ]; then
    MINA_APP=${MINA}
else
    MINA_APP=${MINA_LEGACY}
fi

MINA_APP="${MINA_APP}" /entrypoint.sh "$@"