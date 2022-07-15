#!/bin/bash

set -eo pipefail

echo "THE ENVIRONMENT"

env

echo "END OF ENV"

# for release branch, PR base branch, PR branch, build mina.exe, dump type shapes

function dump_type_shapes {
    BRANCH=$1
    if [ ! -z $BRANCH ]; then
	echo "Dumping versioned type shapes for branch" $BRANCH
#	git checkout $BRANCH
#	make build
#	./_build/default/src/app/cli/src/mina.exe internal dump-type-shapes > $BRANCH.type_shapes
#	ls -l $BRANCH.type_shapes
    fi
}

git fetch

dump_type_shapes $BRANCH_NAME
dump_type_shapes $BASE_BRANCH_NAME
dump_type_shapes $RELEASE_BRANCH_NAME
