#!/bin/bash

CLEAR='\033[0m'
RED='\033[0;31m'

set -u
set -e
set -E
set -o pipefail

MINA_NETWORK=devnet
PG_CONN=postgres://postgres@127.0.0.1:5432/archive_balances_migrated
ARCHIVE_BLOCKS=mina-archive-blocks
MISSING_BLOCKS_AUDITOR=mina-missing-blocks-auditor
BLOCK_BUCKET="https://storage.googleapis.com/mina_network_block_data"
CLI_NAME=./download-missing-blocks.sh


function help(){
  echo Downloading missing blocks for archive database
  echo ""
  echo "     $CLI_NAME [-n|--network network] [-a|--archive-uri uri] [-b|--archive-blocks path] [-m|--missing-blocks-auditor path] [-c|--bucket uri]"
  echo ""
  echo "Parameters:"
  echo ""
  printf "  %-25s %s\n" "-h | --help" "show help";
  printf "  %-25s %s\n" "-n | --network" "[str] name of network (for downloading precomputed blocks). NOTICE: there is an assumption that precomputed blocks are named with format: {network}-{height}-{state_hash}.json. Default: $MINA_NETWORK ";
  printf "  %-25s %s\n" "-a | --archive-uri" "[connection_str] connection string to database to be patched. Default: $PG_CONN ";
  printf "  %-25s %s\n" "-b | --archive-blocks path" "[fie] archive blocks app for archiving blocks path . Default: $ARCHIVE_BLOCKS ";
  printf "  %-25s %s\n" "-m | --missing-blocks-auditor" "[file] missing auditor app path. Default: $MISSING_BLOCKS_AUDITOR ";
  printf "  %-25s %s\n" "-c | --blocks-bucket" "[string] name of precomputed blocks bucket. NOTICE: there is an assumption that precomputed blocks are named with format: {network}-{height}-{state_hash}.json. Default: $BLOCK_BUCKET";  
  echo "Example:"
  echo ""
  echo "  " $CLI_NAME --network devnet --archive-uri postgres://postgres:pass@localhost:5432/archive_balances_migrated
  echo ""
  exit 0
}

if [ ${#} -eq 0 ]; then
  help
fi

while [ ${#} -gt 0 ]; do
  error_message="Error: a value is needed for '$1'";
  case $1 in
      -h | --help ) 
        help;
      ;;
      -n | --network )
        MINA_NETWORK=${2:?$error_message}
        shift 2;
      ;;
      -a | --archive-uri )
        PG_CONN=${2:?$error_message}
        shift 2;
      ;;
      -b | --archive-blocks )
        ARCHIVE_BLOCKS=${2:?$error_message}
        shift 2;
      ;;
      -m | --missing-blocks-auditor )
        MISSING_BLOCKS_AUDITOR=${2:?$error_message}
        shift 2;
      ;;
      -c | --blocks-bucket )
        BLOCK_BUCKET=${2:?$error_message}
        shift 2;
      ;;
      * )
        echo -e "${RED} !! Unknown option: $1${CLEAR}\n";
        echo "";
        help;
        exit 0;
      ;;
  esac
done


function jq_parent_json() {
   jq -rs 'map(select(.metadata.parent_hash != null and .metadata.parent_height != null)) | "\(.[0].metadata.parent_height)-\(.[0].metadata.parent_hash).json"'
}

function jq_parent_hash() {
   jq -rs 'map(select(.metadata.parent_hash != null and .metadata.parent_height != null)) | .[0].metadata.parent_hash'
}

function populate_db() {
   $ARCHIVE_BLOCKS --precomputed --archive-uri "$1" "$2" | jq -rs '"[BOOTSTRAP] Populated database with block: \(.[-1].message)"'
   rm "$2"
}

function download_block() {
    echo "Downloading $1 block"
    curl -sO "${BLOCK_BUCKET}/${1}"
}

# Bootstrap finds every missing state hash in the database and imports them from the o1labs bucket of .json blocks
function bootstrap() {
  echo "[BOOTSTRAP] Top 10 blocks before bootstrapping the archiveDB:"
  psql "${PG_CONN}" -c "SELECT state_hash,height FROM blocks ORDER BY height DESC LIMIT 10"
  echo "[BOOTSTRAP] Restoring blocks individually from ${BLOCK_BUCKET}..."

  set +o pipefail
  until [[ "$PARENT" == "null" ]] ; do
    PARENT_FILE="${MINA_NETWORK}-$($MISSING_BLOCKS_AUDITOR --archive-uri $PG_CONN | jq_parent_json)"
    download_block "${PARENT_FILE}"
    populate_db "$PG_CONN" "$PARENT_FILE"
    PARENT="$($MISSING_BLOCKS_AUDITOR --archive-uri $PG_CONN | jq_parent_hash)"
  done
  set -o pipefail

  echo "[BOOTSTRAP] Top 10 blocks in bootstrapped archiveDB:"
  psql "${PG_CONN}" -c "SELECT state_hash,height FROM blocks ORDER BY height DESC LIMIT 10"
  echo "[BOOTSTRAP] This archive node is synced with no missing blocks back to genesis!"

  echo "[BOOTSTRAP] Checking again in 60 minutes..."
  sleep 3000
}

# Wait until there is a block missing
PARENT=null
set +o pipefail
while true; do # Test once every 10 minutes forever, take an hour off when bootstrap completes
  PARENT="$($MISSING_BLOCKS_AUDITOR --archive-uri $PG_CONN | jq_parent_hash)"
  echo $PARENT
  echo "[BOOTSTRAP] $($MISSING_BLOCKS_AUDITOR --archive-uri $PG_CONN | jq -rs .[].message)"
  [[ "$PARENT" != "null" ]] && echo "[BOOSTRAP] Some blocks are missing, moving to recovery logic..." && bootstrap
  sleep 600 # Wait for the daemon to catchup and start downloading new blocks
done
set -o pipefail
