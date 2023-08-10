#!/bin/bash

set -eo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <dune-profile> <path-to-top-level-directory> <paths-to-ignore-space-delimited>"
    exit 1
fi

profile=$1
build_path=$2
ignore_paths=$3

#for some reason empty string/single space is not considered an argument when passed in dhall files
if [[ "${ignore_paths}" == "None" ]]; then
    ignore_paths=()
fi

source ~/.profile

export MINA_LIBP2P_PASS="naughty blue worm"
export NO_JS_BUILD=1 # skip some JS targets which have extra implicit dependencies

echo "--- Make build"
export LIBP2P_NIXLESS=1 PATH=/usr/lib/go/bin:$PATH GO=/usr/lib/go/bin/go
export DUNE_PROFILE="${profile}"
time make build

echo "--- Build all targets"
dune build "${build_path}" --profile="${profile}" -j16

dune_filename="dune"
source_paths_to_test=()

#(inline_tests) and tests stanza in dune files enable inline tests
grep --include=dune -ERl "${build_path}" -e "\(inline_tests|\(tests" | 
while read -r line;
do 
    source_path=${line%"$dune_filename"}
    execute="Y"
    for ignore_path in ${ignore_paths}; 
    do
        if [[ "${source_path}" == "${ignore_path}"* ]]; then #ignore sub-directories too
            execute="N"
            break
        fi
        execute="Y"
    done
    if [[ "${execute}" == "Y" ]]; then
            # Note: By attempting a re-run on failure here, we can avoid rebuilding and
            # skip running all of the tests that have already succeeded, since dune will
            # only retry those tests that failed.
            echo "--- Run unit tests in ${source_path}"
            time dune runtest "${source_path}" --profile="${profile}" -j16 || \
            (./scripts/link-coredumps.sh && \
            echo "--- Retrying failed unit tests" && \
            time dune runtest "${source_path}" --profile="${profile}" -j16 || \
            (./scripts/link-coredumps.sh && false))
    else
        echo "Skipping ${source_path}"
    fi
done
