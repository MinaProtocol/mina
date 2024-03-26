#!/usr/bin/env bash

# This script is adapted from https://github.com/MinaProtocol/mina/blob/develop/src/app/rosetta/download-missing-blocks.sh
# It is used to populate a postgres database with missing precomputed archiveDB blocks

# Function to display usage information
usage() {
    echo "Usage: $0 <subcommand> [options]"
    echo "Subcommands:"
    echo "  audit           Check database health"
    echo "  single-run      Check database health and recover it if broken"
    echo "  daemon          Run as a daemon checking health every 10 minutes"
    echo ""
    echo "Options:"
    echo "  --help          Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  Required:"
    echo "    DB_USERNAME             Database username"
    echo "    DB_HOST                 Database connection endpoint"
    echo "    DB_PORT                 Database connection port"
    echo "    DB_NAME                 Database name"
    echo "    PGPASSWORD              Postgresql password"
    echo "    PRECOMPUTED_BLOCKS_URL  Url of the bucket with the precomputed blocks"
    echo ""
    echo "  Optional:"
    echo "    MISSING_BLOCKS_AUDITOR  Path to the missing-blocks-auditor exe (default: mina-missing-blocks-auditor)"
    echo "    TIMEOUT                 Time to sleep in seconds when in daemon mode. After recovery it will sleep six times more (default: 600)"
    echo ""
    echo "Example:"
    echo "  $0 audit"
    echo "  $0 single-run"
    echo "  $0 daemon"
}

trap "echo $'\nRecieved termination signal. Exiting the script\n'; exit 1" 1 2 3

# Checks required env variables
check_env_vars() {
  if [ -z "$DB_USERNAME" ]; then
      echo $'[ERROR] The DB_USERNAME environment variable is not set or is empty. Exiting the script'
      exit 1
  fi
  
  if [ -z "$PGPASSWORD" ]; then
      echo $'[ERROR] The PGPASSWORD environment variable is not set or is empty. Exiting the script'             
      exit 1
  fi
  
  if [ -z "$DB_HOST" ]; then
      echo $'[ERROR] The DB_HOST environment variable is not set or is empty. Exiting the script'                
      exit 1
  fi
  
  if [ -z "$DB_PORT" ]; then
      echo $'[ERROR] The DB_PORT environment variable is not set or is empty. Exiting the script'                
      exit 1
  fi
  
  if [ -z "$DB_NAME" ]; then
      echo $'[ERROR] The DB_NAME environment variable is not set or is empty. Exiting the script'                
      exit 1
  fi
  
  if [ -z "$PRECOMPUTED_BLOCKS_URL" ]; then
      echo $'[ERROR] The PRECOMPUTED_BLOCKS_URL environment variable is not set or is empty. Exiting the script'  
      exit 1
  fi
  
  if [ -z "$MISSING_BLOCKS_AUDITOR" ]; then
      echo -e "[INFO] The MISSING_BLOCKS_AUDITOR environment variable is not set or is empty. Defaulting to \033[31mmina-missing-block-auditor\e[m."
      MISSING_BLOCKS_AUDITOR=mina-missing-blocks-auditor
  fi
  
  if [ -z "$TIMEOUT" ]; then
      echo -e "[INFO] The TIMEOUT environment variable is not set or is empty. Defaulting to \033[31m600\e[m."
      TIMEOUT=600
  fi
}


jq_parent_json() {
   jq -rs 'map(select(.metadata.parent_hash != null and .metadata.parent_height != null)) | "\(.[0].metadata.parent_height)-\(.[0].metadata.parent_hash).json"'
}

jq_parent_hash() {
   jq -rs 'map(select(.metadata.parent_hash != null and .metadata.parent_height != null)) | .[0].metadata.parent_hash'
}

populate_db() {
   mina-archive-blocks --precomputed --archive-uri "${1}" "${2}" | jq -rs '"[BOOTSTRAP] Populated database with block: \(.[-1].message)"'
   rm "${2}"
}

download_block() {
    echo "[INFO] Downloading ${1} block"
    curl -sO "${PRECOMPUTED_BLOCKS_URL}/${1}"
}

HASH='map(select(.metadata.parent_hash != null and .metadata.parent_height != null)) | .[0].metadata.parent_hash'
# Bootstrap finds every missing state hash in the database and imports them from a bucket of precomputed .json blocks
bootstrap() {
  echo "[BOOTSTRAP] Top 10 blocks before bootstrapping the archiveDB:"
  psql -b -e "${PG_CONN}" -c "SELECT state_hash,height FROM blocks ORDER BY height DESC LIMIT 10"
  echo "[BOOTSTRAP] Restoring blocks individually from ${PRECOMPUTED_BLOCKS_URL}..."

  until [[ "$PARENT" == "null" ]] ; do
    PARENT_FILE="${MINA_NETWORK}-$($MISSING_BLOCKS_AUDITOR --archive-uri $PG_CONN | jq_parent_json)"
    download_block "${PARENT_FILE}"
    populate_db "$PG_CONN" "$PARENT_FILE"
    PARENT="$($MISSING_BLOCKS_AUDITOR --archive-uri $PG_CONN | jq_parent_hash)"
  done

  echo "[BOOTSTRAP] Top 10 blocks in bootstrapped archiveDB:"
  psql -b -e "${PG_CONN}" -c "SELECT state_hash,height FROM blocks ORDER BY height DESC LIMIT 10"
  echo "[RESOLUTION] This Archive node is synced with no missing blocks back to genesis!"
  
  if [ $1 = false ]; then
    echo "[INFO] Checking again in $((6*${TIMEOUT}/60)) minutes..."
    sleep $((6*${TIMEOUT}))
  fi
}

main() {

  # Check if at least one argument is provided
  if [ $# -lt 1 ]; then
    usage
    exit 1
  fi
  
  # Parse argument
  subcommand="$1"
  shift

  # Check for help option
  if [ "$subcommand" = "--help" ]; then
    usage
    exit 0
  fi

  check_env_vars

  echo "[INFO] Using connection string postgres://${DB_USERNAME}:<your_password>@${DB_HOST}:${DB_PORT}/${DB_NAME}"
  PG_CONN=postgres://${DB_USERNAME}:${PGPASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}

  # Wait until there is a block missing
  PARENT=null
  case "$subcommand" in

    audit)
      echo "[INFO] Running in audit mode"
      PARENT="$($MISSING_BLOCKS_AUDITOR --archive-uri $PG_CONN | jq_parent_hash)"
      echo "[BOOTSTRAP] $($MISSING_BLOCKS_AUDITOR --archive-uri $PG_CONN | jq -rs .[].message)"
      [[ "$PARENT" != "null" ]] && echo "Some blocks are missing" && exit 0
      echo "[RESOLUTION] This Archive node is synced with no missing blocks back to genesis!"
      exit 0
      ;;

    single-run)
      echo "[INFO] Running in single-run mode"
      SINGLE_RUN=true
      PARENT="$($MISSING_BLOCKS_AUDITOR --archive-uri $PG_CONN | jq_parent_hash)"
      echo "[BOOTSTRAP] $($MISSING_BLOCKS_AUDITOR --archive-uri $PG_CONN | jq -rs .[].message)"
      [[ "$PARENT" != "null" ]] && echo "[BOOTSTRAP] Some blocks are missing, moving to recovery logic..." && bootstrap $SINGLE_RUN
      echo "[RESOLUTION] The bootstrap process finished, the Archive node should be synced with no missing blocks! Rerun the script in audit mode to be sure."
      exit 0
      ;; 

    daemon)
      echo "[INFO] Running in daemon mode"
      SINGLE_RUN=false
      while true; do # Test once every 10 minutes forever, take an hour off when bootstrap completes
        PARENT="$($MISSING_BLOCKS_AUDITOR --archive-uri $PG_CONN | jq_parent_hash)"
        echo "[BOOTSTRAP] $($MISSING_BLOCKS_AUDITOR --archive-uri $PG_CONN | jq -rs .[].message)"
        if [[ "$PARENT" != "null" ]]; then
          echo "[BOOTSTRAP] Some blocks are missing, moving to recovery logic..." && bootstrap $SINGLE_RUN
        else
          echo "[INFO] Waiting for $((${TIMEOUT}/60)) minutes"
          sleep $TIMEOUT # Wait for the daemon to catchup and start downloading new blocks
        fi
      done
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
