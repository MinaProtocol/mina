#!/bin/bash

if [ -z $MINA_DEB_CODENAME ]; then 
    echo "MINA_DEB_CODENAME env var is not defined"
    exit 1
fi

# Parse command line arguments
ARCH="amd64"  # default architecture
ROOT=${BUILDKITE_BUILD_ID}

while [[ $# -gt 0 ]]; do
    case $1 in
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --root)
            ROOT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

LOCAL_DEB_FOLDER=_build

set -eou pipefail
set -x

# Download locally static debians (for example mina-legacy )

source ./buildkite/scripts/export-git-env-vars.sh

export ROOT
export LOCAL_DEB_FOLDER
./buildkite/scripts/debian/read_all_from_cache.sh
./scripts/debian/aptly.sh start --codename $MINA_DEB_CODENAME --debians $LOCAL_DEB_FOLDER --component unstable --clean --background --wait --archs $ARCH