#!/usr/bin/env bash

# Common utilities and constants for release management

# Colors for output
CLEAR='\033[0m'
RED='\033[0;31m'

# Default values
DEFAULT_ARTIFACTS="mina-logproc,mina-archive,mina-rosetta,mina-daemon"
DEFAULT_NETWORKS="devnet,mainnet"
DEFAULT_CODENAMES="bullseye,focal"
DEFAULT_ARCHITECTURE="amd64"

# Repository configuration
DEBIAN_CACHE_FOLDER=~/.release/debian/cache
GCR_REPO="gcr.io/o1labs-192920"
DOCKER_IO_REPO="docker.io/minaprotocol"
DEBIAN_REPO=packages.o1test.net

# Hetzner configuration
HETZNER_USER=u434410
HETZNER_HOST=u434410-sub2.your-storagebox.de
HETZNER_KEY=${HETZNER_KEY:-$HOME/.ssh/id_rsa}

# Formatting
SUBCOMMAND_TAB="        "

# Utility functions
function prefix_cmd {
    local PREF="${1//\//\\/}" # replace / with \/
    shift
    local CMD=("$@")
    "${CMD[@]}" 1> >(sed "s/^/${PREF}/") 2> >(sed "s/^/${PREF}/" 1>&2)
}

function check_app() {
    if ! command -v $1 &> /dev/null; then
        echo -e "❌ ${RED} !! $1 program not found. Please install " \
                "program to proceed. ${CLEAR}\n";
        exit 1
    fi
}

function check_gsutil() {
    check_app "gsutil"
}

function check_docker() {
    check_app "docker"
}

# Initialize cache folder
mkdir -p $DEBIAN_CACHE_FOLDER