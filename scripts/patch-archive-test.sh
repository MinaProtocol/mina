#!/bin/bash

# test replayer on known archive db

DUMP_FOLDER=/tmp/patch_archive_test
PRECOMPUTED_BLOCKS_FILTER=$DUMP_FOLDER/mainnet*.json
PATCH_ARCHIVE_TEST_APP=${PATCH_ARCHIVE_TEST_APP:-_build/default/src/test/archive/patch_archive_test/patch_archive_test.exe}
DUMP_BLOCK_APP=${EXTRACT_BLOCK_APP:-_build/default/src/app/dump_blocks/dump_blocks.exe}
EXTRACT_BLOCK_APP=${EXTRACT_BLOCK_APP:-_build/default/src/app/extract_blocks/extract_blocks.exe}
ARCHIVE_BLOCK_APP=${ARCHIVE_BLOCK_APP:-_build/default/src/app/archive_blocks/archive_blocks.exe}
PG_CONN=${PG_CONN:-postgres://postgres:postgres@localhost:5432/test}

function report () {
 if [[ $1 == 0 ]]; then
     echo SUCCEEDED
 else
     echo FAILED
 fi
}


mkdir -p $DUMP_FOLDER
$DUMP_BLOCK_APP sequence --size 40 $DUMP_FOLDER

PRECOMPUTED_BLOCKS=$(ls $PRECOMPUTED_BLOCKS_FILTER | xargs )
$ARCHIVE_BLOCK_APP --archive-uri $PG_CONN $PRECOMPUTED_BLOCKS -precomputed

echo "Running patch archive test"
$PATCH_ARCHIVE_TEST_APP --archive-uri $PG_CONN \
                        --num-blocks-to-patch 3 \
                        --archive-blocks-path $ARCHIVE_BLOCK_APP \
                        --extract-blocks-path $EXTRACT_BLOCK_APP \
                        --precomputed \
                        $(find $PRECOMPUTED_BLOCKS_FILTER -type f -printf "%p ")

RESULT=$?

report $RESULT

exit $RESULT
