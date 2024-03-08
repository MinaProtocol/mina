#!/bin/bash

CLEAR='\033[0m'
RED='\033[0;31m'

set -u

local __default_mina_network=devnet
local __default_pg_conn=postgres://postgres@127.0.0.1:5432/archive_balances_migrated
local __default_archive_blocks_app=mina-archive-blocks
local __default_missing_blocks_auditor=mina-missing-blocks-auditor
local __default_block_bucket="https://storage.googleapis.com/mina_network_block_data"
CLI_NAME=./download-missing-blocks.sh


MINA_NETWORK=${1:-$__default_mina_network}
PG_CONN=${2:-$__default_pg_conn}
ARCHIVE_BLOCKS_APP=${3:-$__default_archive_blocks_app}
MISSING_BLOCKS_AUDITOR=${4:-$__default_missing_blocks_auditor}
BLOCKS_BUCKET=${5:-$__default_block_bucket}

function help(){
	echo Downloading missing blocks for archive database
	echo ""
  echo "     $CLI_NAME [-n|--network network] [-a|--archive-uri uri] [-b|--archive-blocks path] [-m|--missing-blocks-auditor path] [-c|--bucket uri]"
  echo ""
  echo "Parameters:"
  echo ""
	printf "  %-25s %s\n" "-h | --help" "show help";
  printf "  %-25s %s\n" "-n | --network" "[str] name of network (for downloading precomputed blocks). NOTICE: there is an assumption that precomputed blocks are named with format: {network}-{height}-{state_hash}.json. Default: $__default_mina_network ";
  printf "  %-25s %s\n" "-a | --archive-uri" "[connection_str] connection string to database to be patched. Default: $__default_pg_conn ";
  printf "  %-25s %s\n" "-b | --archive-blocks path" "[fie] archive blocks app for archiving blocks path . Default: $__default_archive_blocks_app ";
  printf "  %-25s %s\n" "-m | --missing-blocks-auditor" "[file] missing auditor app path. Default: $__default_missing_blocks_auditor ";
  printf "  %-25s %s\n" "-m | --missing-blocks-auditor" "[file] missing auditor app path. Default: $__default_missing_blocks_auditor ";
  printf "  %-25s %s\n" "-c | --blocks-bucket" "[string] name of precomputed blocks bucket. NOTICE: there is an assumption that precomputed blocks are named with format: {network}-{height}-{state_hash}.json. Default: $__default_block_bucket";  
  echo "Example:"
  echo ""
  echo "  " $CLI_NAME --network devnet --archive-uri postgres://postgres:pass@localhost:5432/archive_balances_migrated
  echo ""
  echo ""
  exit 0
}


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
        ARCHIVE_BLOCKS_APP=${2:?$error_message}
				shift 2;
      ;;
      -m | --missing-blocks-auditor )
        MISSING_BLOCKS_AUDITOR=${2:?$error_message}
        shift 2;
      ;;
      -c | --blocks-bucket )
        BLOCKS_BUCKET=${2:?$error_message}
        shift 2;
      ;;
      * )
        echo -e "${RED} !! Unknown option: $1${CLEAR}\n";
	  		echo "";
				initial_help;
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
   $ARCHIVE_BLOCKS_APP --precomputed --archive-uri "$1" "$2" | jq -rs '"[BOOTSTRAP] Populated database with block: \(.[-1].message)"'
   rm "$2"
}

function download_block() {
    echo "Downloading $1 block"
    curl -sO "${BLOCKS_BUCKET}/${1}"
}

HASH='map(select(.metadata.parent_hash != null and .metadata.parent_height != null)) | .[0].metadata.parent_hash'
# Bootstrap finds every missing state hash in the database and imports them from the o1labs bucket of .json blocks
function bootstrap() {
  echo "[BOOTSTRAP] Top 10 blocks before bootstrapping the archiveDB:"
  psql "${PG_CONN}" -c "SELECT state_hash,height FROM blocks ORDER BY height DESC LIMIT 10"
  echo "[BOOTSTRAP] Restoring blocks individually from ${BLOCKS_BUCKET}..."

  until [[ "$PARENT" == "null" ]] ; do
    PARENT_FILE="${MINA_NETWORK}-$($MISSING_BLOCKS_AUDITOR --archive-uri $PG_CONN | jq_parent_json)"
    download_block "${PARENT_FILE}"
    populate_db "$PG_CONN" "$PARENT_FILE"
    PARENT="$($MISSING_BLOCKS_AUDITOR --archive-uri $PG_CONN | jq_parent_hash)"
  done

  echo "[BOOTSTRAP] Top 10 blocks in bootstrapped archiveDB:"
  psql "${PG_CONN}" -c "SELECT state_hash,height FROM blocks ORDER BY height DESC LIMIT 10"
  echo "[BOOTSTRAP] This rosetta node is synced with no missing blocks back to genesis!"

  echo "[BOOTSTRAP] Checking again in 60 minutes..."
  sleep 3000
}

# Wait until there is a block missing
PARENT=null
while true; do # Test once every 10 minutes forever, take an hour off when bootstrap completes
  PARENT="$($MISSING_BLOCKS_AUDITOR --archive-uri $PG_CONN | jq_parent_hash)"
  echo "[BOOTSTRAP] $($MISSING_BLOCKS_AUDITOR --archive-uri $PG_CONN | jq -rs .[].message)"
  [[ "$PARENT" != "null" ]] && echo "[BOOSTRAP] Some blocks are missing, moving to recovery logic..." && bootstrap
  sleep 600 # Wait for the daemon to catchup and start downloading new blocks
done
echo "[BOOTSTRAP] This rosetta node is synced with no missing blocks back to genesis!"
