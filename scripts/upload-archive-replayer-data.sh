#!/usr/bin/env bash

set -e

ARCHIVE_DATA_SQL=./src/test/archive/sample_db/archive_db.sql
PRECOMPUTED_BLOCKS_TAR=./src/test/archive/sample_db/precomputed_blocks.tar.xz
VERSION_FILE_PATH="./src/test/archive/sample_db/latest_version"
CURRENT_VERSION=$(<"$VERSION_FILE_PATH")


if ! [[ -f "$ARCHIVE_DATA_SQL" && -f "$PRECOMPUTED_BLOCKS_TAR" ]]; then
    echo "Required archive data files not found."
    echo "Please run 'scripts/regenerate-archive.sh' first to generate them."
    echo "And follow the instructions in the README.md (src/test/archive/sample_db/README.md) to set up the database."
    exit 1;
fi

echo "Current data version: $CURRENT_VERSION"
NEW_VERSION=$((CURRENT_VERSION + 1))
echo "New data version: $NEW_VERSION"

echo "$NEW_VERSION" > "$VERSION_FILE_PATH"

# Upload the archive data to the replayer
echo "Uploading archive data to GCP bucket..."

curl -X POST --data-binary @$ARCHIVE_DATA_SQL \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H "Content-Type: application/sql" \
    "https://storage.googleapis.com/upload/storage/v1/b/o1labs-ci-test-data/o?uploadType=media&name=replay/v"$NEW_VERSION"/archive_db.sql"

echo "Uploaded archive_db.sql to o1labs-ci-test-data bucket."


curl -X POST --data-binary @$PRECOMPUTED_BLOCKS_TAR \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H "Content-Type: application/octet-stream" \
    "https://storage.googleapis.com/upload/storage/v1/b/o1labs-ci-test-data/o?uploadType=media&name=replay/v"$NEW_VERSION"/precomputed_blocks.tar.xz"

echo "Uploaded precomputed_blocks.tar.xz to o1labs-ci-test-data bucket."
echo ":)"
echo "Archive data upload completed successfully."
