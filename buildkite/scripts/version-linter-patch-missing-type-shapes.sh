#!/bin/bash

set -eo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <release-branch>"
    exit 1
fi

git config --global --add safe.directory /workdir

source buildkite/scripts/handle-fork.sh
source buildkite/scripts/export-git-env-vars.sh

release_branch=${REMOTE}/$1

RELEASE_BRANCH_COMMIT=$(git log -n 1 --format="%h" --abbrev=7 --no-merges $release_branch)

if ! $(gsutil ls gs://mina-type-shapes/$BUILDKITE_COMMIT 2>/dev/null); then
    git checkout $BASE_BRANCH_COMMIT
    eval $(opam config env)
    export PATH=/home/opam/.cargo/bin:/usr/lib/go/bin:$PATH
    export GO=/usr/lib/go/bin/go
    make -C src/app/libp2p_helper

    dune exec src/app/cli/src/mina.exe internal dump-mina-shapes 2> ${BASE_BRANCH_COMMIT}_type-shapes.txt
    gsutil cp ${BASE_BRANCH_COMMIT}_type-shapes.txt gs://mina-type-shapes
fi

if ! $(gsutil ls gs://mina-type-shapes/$RELEASE_BRANCH_COMMIT 2>/dev/null); then
    git checkout $RELEASE_BRANCH_COMMIT
    eval $(opam config env)
    export PATH=/home/opam/.cargo/bin:/usr/lib/go/bin:$PATH
    export GO=/usr/lib/go/bin/go
    make -C src/app/libp2p_helper

    dune exec src/app/cli/src/mina.exe internal dump-mina-shapes 2> ${RELEASE_BRANCH_COMMIT}_type-shapes.txt
    gsutil cp ${RELEASE_BRANCH_COMMIT}_type-shapes.txt gs://mina-type-shapes
fi