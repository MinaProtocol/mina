#!/usr/bin/env bash

# Pin external OCaml packages that override opam versions.
# This corresponds to the note about scripts/pin-external-packages.sh in
# the "Developer Setup (Linux)" section of README-dev.md.
#
# Run this script from the root of the Mina repository after setting up
# the opam switch (linux-opam-setup.sh).

set -eo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

"${SCRIPT_DIR}/../pin-external-packages.sh"
