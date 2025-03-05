#!/usr/bin/env bash

function check_buildkite_vars() {
    if [ ! -v "BUILDKITE_JOB_ID" ]; then
        echo -e "Script is executed outside buildkite context.. BUILDKITE_JOB_ID env var not find \n";
        exit 1
    fi
}

function check_cache_exists() {
    if ! test -d "$STORAGE_MOUNTPOINT"; then
        echo -e "Cache directory does not exists (or permission denied) : '$STORAGE_MOUNTPOINT'\n";
        exit 1
    fi
}

check_buildkite_vars

export STORAGE_MOUNTPOINT="/var/storagebox"
export STORAGE_ROOT_FOLDER="buildkite/${BUILDKITE_JOB_ID}"
export STORAGE_FOLDER="${STORAGE_MOUNTPOINT}/${STORAGE_ROOT_FOLDER}"


check_cache_exists

mkdir -p $STORAGE_FOLDER