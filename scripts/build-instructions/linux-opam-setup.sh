#!/usr/bin/env bash

# Set up the OCaml/opam environment for building Mina on Linux.
# This corresponds to the "Developer Setup (Linux)" section in README-dev.md.
#
# Prerequisites:
#   - opam must already be installed (e.g. via your distro's package manager)
#   - Run this script from the root of the Mina repository

set -eo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="${SCRIPT_DIR}/../.."

# Add the o1-labs opam repository
opam repository add --yes --all --set-default o1-labs https://github.com/o1-labs/opam-repository.git

# Import the opam switch with all required dependencies
opam switch import --yes "${REPO_ROOT}/opam.export"
