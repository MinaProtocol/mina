#!/bin/bash

# test replayer on known archive db

DUMP_FOLDER=/tmp/patch_archive_test
PATCH_ARCHIVE_TEST_APP=${PATCH_ARCHIVE_TEST_APP:-_build/default/src/test/archive/patch_archive_test/patch_archive_test.exe}
EXTRACT_BLOCK_APP=${EXTRACT_BLOCK_APP:-_build/default/src/app/extract_blocks/extract_blocks.exe}
ARCHIVE_BLOCK_APP=${ARCHIVE_BLOCK_APP:-_build/default/src/app/archive_blocks/archive_blocks.exe}
PG_CONN=${PG_CONN:-postgres://postgres:postgres@localhost:5432}

echo "Running patch archive test"
$PATCH_ARCHIVE_TEST_APP --db $PG_CONN \
                        --network_data_folder /
                        --archive-blocks-path $ARCHIVE_BLOCK_APP \
                        --extract-blocks-path $EXTRACT_BLOCK_APP \
                        --missing-blocks-guardian $EXTRACT_BLOCK_APP
                        --precomputed \
                        $PRECOMPUTED_BLOCKS
