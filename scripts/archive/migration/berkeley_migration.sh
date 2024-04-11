#!/usr/bin/env bash


# bash strict mode
set -T # inherit DEBUG and RETURN trap for functions
set -C # prevent file overwrite by > &> <>
set -E # inherit -e
set -e # exit immediately on errors
set -u # exit on not assigned variables
set -o pipefail # exit on pipe failure

CLEAR='\033[0m'
RED='\033[0;31m'

################################################################################
# global variable
################################################################################
declare -r CLI_VERSION='1.0.0';
declare -r CLI_NAME='berkeley_migration.sh';
declare -r PS4='debug($LINENO) ${FUNCNAME[0]:+${FUNCNAME[0]}}(): ';

CHECKPOINT_PREFIX=migration

################################################################################
# functions
################################################################################
function check_required() {
    if ! command -v "$1" >/dev/null 2>&1; then echo "Missing required program '$1' in PATH"; exit 1; fi
}
check_required mina-berkeley-migration
check_required mina-berkeley-migration-verifier
check_required mina-migration-replayer
check_required mina-logproc
check_required jq
check_required gsutil

function main_help(){
    echo Script for archive migration from mainnet to berkeley
    echo ""
    echo "     $CLI_NAME [command] [-options]"
    echo ""
    echo "Commands:"
    echo ""
    printf "  %-23s %s\n" "help" "show help menu and commands";
    printf "  %-23s %s\n" "version" "show version of this script";
    printf "  %-23s %s\n" "initial" "run initial berkeley archive migration";
    printf "  %-23s %s\n" "incremental" "run incremenetal berkeley archive migration";
    printf "  %-23s %s\n" "final" "run final berkeley archive migration";
    echo ""
    exit "${1:-0}";
}

function version(){
    echo $CLI_NAME $CLI_VERSION;
    exit 0
}

function format_migration_args() { # keep_precomputed_blocks stream_blocks
    local __args=""
    case $1 in
    true )
        __args+=" --keep-precomputed-blocks"
        ;;
    esac

    case $2 in
    true )
        __args+=" --stream-precomputed-blocks"
        ;;
    esac

    echo $__args
}

function initial_help(){
    echo Initial migration based on genesis ledger and empty migration target database
    echo ""
    echo "     $CLI_NAME initial [-options]"
    echo ""
    echo "Parameters:"
    echo ""
    printf "  %-25s %s\n" "-h | --help" "show help";
    printf "  %-25s %s\n" "-g | --genesis-ledger" "[file] path to genesis ledger file";
    printf "  %-25s %s\n" "-s | --source-db" "[connection_str] connection string to database to be migrated";
    printf "  %-25s %s\n" "-t | --target-db" "[connection_str] connection string to database which will hold migrated data";
    printf "  %-25s %s\n" "-b | --blocks-bucket" "[string] name of precomputed blocks bucket. NOTICE: there is an assumption that precomputed blocks are named with format: {network}-{height}-{state_hash}.json";
    printf "  %-25s %s\n" "-bs | --blocks-batch-size" "[int] number of precomputed blocks to be fetch at once from Gcloud. Bigger number like 1000 can help speed up migration process";
    printf "  %-25s %s\n" "-n | --network" "[string] network name when determining precomputed blocks. NOTICE: there is an assumption that precomputed blocks are named with format: {network}-{height}-{state_hash}.json";
    printf "  %-25s %s\n" "-d | --delete-blocks" "[flag] delete blocks after they are processed (saves space with -sb)"
    printf "  %-25s %s\n" "-p | --prefetch-blocks" "[flag] downloads all blocks at once instead of incrementally"
    printf "  %-25s %s\n" "-c | --checkpoint-output-path" "[file] output folder for replayer checkpoints"
    printf "  %-25s %s\n" "-l | --precomputed-blocks-local-path" "[file] on-disk precomputed blocks location"
    echo ""
    echo "Example:"
    echo ""
    echo "  " $CLI_NAME initial --genesis-ledger "genesis_ledgers/mainnet.json" --source-db "postgres://postgres:pass@localhost:5432/archive_balances_migrated" --target-db "postgres://postgres:pass@localhost:5432/migrated" --blocks-batch-size 10 --blocks-bucket "mina_network_block_data" --network "mainnet" 
    echo ""
    echo "Notes:"
    echo "  1. After run migrated data will be filled with migrated blocks "
    echo "  2. Two logs files will be generated for archiving/debugging"
    echo "  3. Replayer checkpoints (migration-replayer-XXX.json) will be generated"
    echo ""
    echo "  All above data is required for incremental run"
    echo ""
    exit 0
}

function initial(){
    if [[ ${#} == 0 ]]; then
        initial_help;
    fi

    local __batch_size=10
    local __mainnet_archive_uri=''
    local __migrated_archive_uri='' 
    local __genesis_ledger=''
    local __blocks_bucket=''
    local __keep_precomputed_blocks=true
    local __stream_blocks=true
    local __network='' 
    local __checkpoint_output_path='.'
    local __precomputed_blocks_local_path='.'
    
    while [ ${#} -gt 0 ]; do
        error_message="Error: a value is needed for '$1'";
        case $1 in
            -h | --help ) 
                initial_help;
            ;;
            -g | --genesis-ledger )
                __genesis_ledger=${2:?$error_message}
                shift 2;
            ;;
            -s | --source-db )
                __mainnet_archive_uri=${2:?$error_message}
                shift 2;
            ;;
            -t | --target-db )
                __migrated_archive_uri=${2:?$error_message}
                shift 2;
            ;;
            -b | --blocks-bucket )
                __blocks_bucket=${2:?$error_message}
                shift 2;
            ;;
            -bs | --blocks-batch-size )
                __batch_size=${2:?$error_message}
                shift 2;
            ;;
            -n | --network )
                __network=${2:?$error_message}
                shift 2;
            ;;
            -d | --delete-blocks )
                __keep_precomputed_blocks=false
                shift 1;
            ;;
            -p | --prefetch-blocks )
                __stream_blocks=false
                shift 1;
            ;;
            -c | --checkpoint-output-path )
                __checkpoint_output_path=${2:?$error_message}
                shift 2;
            ;;
            -l | --precomputed-blocks-local-path )
                __precomputed_blocks_local_path=${2:?$error_message}
                shift 2;
            ;;
            * )
                echo -e "${RED} !! Unknown option: $1${CLEAR}\n";
                echo "";
                initial_help;
            ;;
        esac
    done
    
    if [ -z "$__mainnet_archive_uri" ]; then
        echo ""
        echo "Source db not defined"
        exit 1
    fi

    if [ -z "$__migrated_archive_uri" ]; then
        echo ""
        echo "'-t|--target-db' argument is not provided. Please provide valid connection string"
        echo "In order to generate database please follow steps below:" 
        echo ""
        echo "wget -nv https://raw.githubusercontent.com/MinaProtocol/mina/berkeley/src/app/archive/create_schema.sql"
        echo "wget -nv https://raw.githubusercontent.com/MinaProtocol/mina/berkeley/src/app/archive/zkapp_tables.sql"
        echo "psql {CONN_STRING} -c \"CREATE DATABASE migrated\""
        echo "psql {CONN_STRING}/migrated < create_schema.sql"
        exit 1
    fi

    if [ -z "$__genesis_ledger" ]; then
        echo ""
        echo "Genesis ledger not defined"
        exit 1
    fi
    if [ -z "$__blocks_bucket" ]; then
        echo ""
        echo "Precomputed blocks google cloud bucket not defined"
        exit 1
    fi
    if [ -z "$__network" ]; then
        echo ""
        echo "Network not defined"
        exit 1
    fi

    run_initial_migration "$__batch_size" \
        "$__mainnet_archive_uri" \
        "$__migrated_archive_uri" \
        "$__genesis_ledger" \
        "$__blocks_bucket" \
        "$__keep_precomputed_blocks" \
        "$__stream_blocks" \
        "$__network" \
        "$__checkpoint_output_path" \
        "$__precomputed_blocks_local_path"
}

function check_log_for_error() {
    local __log=$1;

    grep '"level":"Error"' "$__log";
    local __have_errors=$?;

    if [ $__have_errors -eq 0 ]; then 
        echo "$__log contains errors, which means migration might produce invalid migrated database. Exiting with error..."
        exit 1
    fi
}

function check_logs() {
    local __berkely_migration_log=$1
    local __replayer_log=$2

    check_log_for_error "$__berkely_migration_log"
    check_log_for_error "$__replayer_log"
}

function check_output_replayer_for_initial() {
    local __checkpoint_prefix=$1
    local __count_checkpoints=$(find . -maxdepth 1 -name "${__checkpoint_prefix}-checkpoint*.json" -print0 | xargs -0 ls -t | wc -l)

    if [ "$__count_checkpoints" -eq "0" ]; then
        echo " There are no new replayer checkpoints. It means that there are no transactions in archive or there are \
               no blocks at all. Please verify source database"
        exit 1
    fi

}

function run_initial_migration() {
    local __batch_size=$1
    local __mainnet_archive_uri=$2
    local __migrated_archive_uri=$3 
    local __genesis_ledger=$4
    local __blocks_bucket=$5
    local __keep_precomputed_blocks=$6
    local __stream_blocks=$7
    local __network=$8
    local __checkpoint_output_path=$9
    local __precomputed_blocks_local_path=${10}
    
    local __date=$(date '+%Y-%m-%d_%H_%M_%S')
    local __berkely_migration_log="berkeley_migration_$__date.log"
    local __replayer_log="replayer_$__date.log"
    local __config_file="initial_replayer_config_$__date.json"

    if [ ! -f "$__genesis_ledger" ]; then
        echo ""
        echo "Genesis ledger file not found: $__genesis_ledger"
        exit 1
    fi

    echo "creating initial replayer config file ($__config_file) based on $__genesis_ledger"
    jq '.ledger.accounts' "$__genesis_ledger" | jq  '{genesis_ledger: {accounts: .}}' > "$__config_file"		

    mina-berkeley-migration \
        --mainnet-archive-uri "$__mainnet_archive_uri" \
        --migrated-archive-uri "$__migrated_archive_uri" \
        --batch-size "$__batch_size" \
        --config-file "$__genesis_ledger" \
        --blocks-bucket "$__blocks_bucket" \
        $(format_migration_args "$__keep_precomputed_blocks" "$__stream_blocks") \
        --network "$__network" \
        --log-file "$__berkely_migration_log" \
        --precomputed-blocks-local-path "$__precomputed_blocks_local_path"

    set +e # skip error because we will do validations and we are better than replayer i reporting

    mina-migration-replayer \
        --migration-mode \
        --archive-uri "$__migrated_archive_uri" \
        --input-file "$__config_file" \
        --checkpoint-interval 1000 \
        --checkpoint-file-prefix "$CHECKPOINT_PREFIX" \
        --checkpoint-output-folder "$__checkpoint_output_path" \
        --log-file "$__replayer_log"

    check_logs "$__berkely_migration_log" "$__replayer_log"

    set -e # exit immediately on errors

    check_output_replayer_for_initial "$CHECKPOINT_PREFIX"
    
    mina-berkeley-migration-verifier pre-fork \
        --mainnet-archive-uri "$__mainnet_archive_uri" \
        --migrated-archive-uri "$__migrated_archive_uri"
}


function incremental_help(){
    echo Incremental migration based on latest source database and last replayer checkpoint 
    echo while migrating into already existing migrated database
    echo ""
    echo "     $CLI_NAME incremental [-options]"
    echo ""
    echo "Parameters:"
    echo ""
    printf "  %-25s %s\n" "-h | --help" "show help";
    printf "  %-25s %s\n" "-g | --genesis-ledger" "[file] path to genesis ledger file";
    printf "  %-25s %s\n" "-r | --replayer-checkpoint" "[file] path to genesis ledger file";
    printf "  %-25s %s\n" "-s | --source-db" "[connection_str] connection string to database to be migrated";
    printf "  %-25s %s\n" "-t | --target-db" "[connection_str] connection string to database which will hold migrated data";
    printf "  %-25s %s\n" "-b | --blocks-bucket" "[string] name of precomputed blocks bucket. NOTICE: there is an assumption that precomputed blocks are named with format: {network}-{height}-{state_hash}.json";
    printf "  %-25s %s\n" "-bs | --blocks-batch-size" "[int] number of precomputed blocks to be fetch at once from Gcloud. Bigger number like 1000 can help speed up migration process";
    printf "  %-25s %s\n" "-n | --network" "[string] network name when determining precomputed blocks. NOTICE: there is an assumption that precomputed blocks are named with format: {network}-{height}-{state_hash}.json";
    printf "  %-25s %s\n" "-d | --delete-blocks" "delete blocks after they are processed (saves space with -sb)"
    printf "  %-25s %s\n" "-p | --prefetch-blocks" "downloads all blocks at once instead of incrementally"
    printf "  %-25s %s\n" "-c | --checkpoint-output-path" "[file] output folder for replayer checkpoints"
    printf "  %-25s %s\n" "-l | --precomputed-blocks-local-path" "[file] on-disk precomputed blocks location"
    echo ""
    echo "Example:"
    echo ""
    echo "  " $CLI_NAME incremental --replayer-checkpoint migration-replayer-1234.json --genesis-ledger "genesis_ledgers/mainnet.json" --source-db "postgres://postgres:pass@localhost:5432/archive_balances_migrated" --target-db "postgres://postgres:pass@localhost:5432/migrated" --blocks-batch-size 10 --blocks-bucket "mina_network_block_data" --network "mainnet" 
    echo ""
    echo "Notes:"
    echo "  1. After run migrated data will be filled with migrated blocks till last block in source db"
    echo "  2. Two logs files will be generated for archiving/debugging operations"
    echo "  3. Replayer checkpoints (migration-replayer-XXX.json) will be generated"
    echo ""
    echo "  All above data is required for incremental run"
    echo ""
    exit 0
}

function check_incremental_migration_progress() {
    local __checkpoint=$1
    local __migrated_archive_uri=$2
    local __global_slot_from_last_checkpoint=$(cat "$__checkpoint" | jq '.start_slot_since_genesis')
    # xargs is used to remove whitespaces
    local __migrated_blocks_count=$(echo "SELECT count(*) FROM blocks WHERE global_slot_since_genesis > $__global_slot_from_last_checkpoint" | psql "$__migrated_archive_uri" -t | xargs)

    if [ "$__migrated_blocks_count" -lt 1 ]; then 
        echo ""
        echo "No progress in incremental migration detected. Exitting with error..."
        exit 1
    fi
}

function check_new_replayer_checkpoints_for_incremental() {
    local __checkpoint_prefix=$1
    local __count_checkpoints=$(find . -maxdepth 1 -name "${__checkpoint_prefix}-checkpoint*.json" -print0 | xargs -0 ls -t | wc -l)

    if [ "$__count_checkpoints" -eq "1" ]; then
      echo "There are no new checkpoints apart from the one downloaded before migration"
      echo "It means that no transactions are archived before this and last incremental migration."
      echo "Please ensure that source database has at least one more canoncial block that migrated one"
      exit 1
    fi

}

function incremental(){
    if [[ ${#} == 0 ]]; then
        incremental_help;
    fi

    local __batch_size=10
    local __mainnet_archive_uri=''
    local __migrated_archive_uri=''
    local __genesis_ledger=''
    local __replayer_checkpoint=''
    local __blocks_bucket=''
    local __keep_precomputed_blocks=true
    local __stream_blocks=true
    local __network=''
    local __checkpoint_interval=1000
    local __checkpoint_output_path='.'
    local __precomputed_blocks_local_path='.'

    while [ ${#} -gt 0 ]; do
        error_message="Error: a value is needed for '$1'";
        case $1 in
            -h | --help )
                incremental_help;
            ;;
            -g | --genesis-ledger )
                __genesis_ledger=${2:?$error_message}
                shift 2;
            ;;
            -r | --replayer-checkpoint )
                __replayer_checkpoint=${2:?$error_message}
                shift 2;
            ;;
            -i | --checkpoint-interval )
                __checkpoint_interval=${2:?$error_message}
                shift 2;
            ;;
            -s | --source-db )
                __mainnet_archive_uri=${2:?$error_message}
                shift 2;
            ;;
            -t | --target-db )
                __migrated_archive_uri=${2:?$error_message}
                shift 2;
            ;;
            -b | --blocks-bucket )
                __blocks_bucket=${2:?$error_message}
                shift 2;
            ;;
            -bs | --blocks-batch-size )
                __batch_size=${2:?$error_message}
                shift 2;
            ;;
            -n | --network )
                __network=${2:?$error_message}
                shift 2;
            ;;
            -d | --delete-blocks )
                __keep_precomputed_blocks=false
                shift 1;
            ;;
            -p | --prefetch-blocks )
                __stream_blocks=false
                shift 1;
            ;;
            -c | --checkpoint-output-path )
                __checkpoint_output_path=${2:?$error_message}
                shift 2;
            ;;
            -l | --precomputed-blocks-local-path )
                __precomputed_blocks_local_path=${2:?$error_message}
                shift 2;
            ;;
            * )
                echo -e "${RED} !! Unknown option: $1${CLEAR}\n";
                echo "";
                incremental_help;
            ;;
        esac
    done
    
    if [ -z "$__mainnet_archive_uri" ]; then
        echo ""
        echo "Source db not defined"
        exit 1
    fi

    if [ -z "$__migrated_archive_uri" ]; then
        echo ""
        echo "'-t|--target-db' argument is not provided. Please provide valid connection string"
        echo "to existing and initially migrated database. If you don't have such schema please refer to help in 'initial' subcommand" 
        exit 1
    fi

    if [ -z "$__replayer_checkpoint" ]; then
        echo ""
        echo "Replayer checkpoint not defined. Please provide path to latest replayer checkpoint file"
        echo "which should be generated on previous incremental run or inital"
        exit 1
    fi

    if [ -z "$__genesis_ledger" ]; then
        echo ""
        echo "Genesis ledger not defined"
        exit 1
    fi
    if [ -z "$__blocks_bucket" ]; then
        echo ""
        echo "Precomputed blocks google cloud bucket not defined"
        exit 1
    fi
    if [ -z "$__network" ]; then
        echo ""
        echo "Network not defined"
        exit 1
    fi
    
    run_incremental_migration "$__batch_size" \
        "$__mainnet_archive_uri" \
        "$__migrated_archive_uri" \
        "$__genesis_ledger" \
        "$__blocks_bucket" \
        "$__keep_precomputed_blocks" \
        "$__stream_blocks" \
        "$__network" \
        "$__checkpoint_interval" \
        "$__replayer_checkpoint" \
        "$__checkpoint_output_path" \
        "$__precomputed_blocks_local_path"

}

function run_incremental_migration() {
    local __batch_size=$1
    local __mainnet_archive_uri=$2
    local __migrated_archive_uri=$3 
    local __genesis_ledger=$4
    local __blocks_bucket=$5
    local __keep_precomputed_blocks=$6
    local __stream_blocks=$7
    local __network=$8
    local __checkpoint_interval=$9
    local __replayer_checkpoint=${10}
    local __checkpoint_output_path=${11}
    local __precomputed_blocks_local_path=${12}

    local __date=$(date '+%Y-%m-%d_%H%M')
    local __berkely_migration_log="berkeley_migration_$__date.log"
    local __replayer_log="replayer_$__date.log"
    
    if [ ! -f "$__genesis_ledger" ]; then
        echo ""
        echo "Genesis ledger file not found: $__genesis_ledger"
        exit 1
    fi
    
    mina-berkeley-migration \
        --mainnet-archive-uri "$__mainnet_archive_uri" \
        --migrated-archive-uri "$__migrated_archive_uri" \
        --batch-size "$__batch_size" \
        --config-file "$__genesis_ledger" \
        --blocks-bucket "$__blocks_bucket" \
        $(format_migration_args "$__keep_precomputed_blocks" "$__stream_blocks") \
        --network "$__network" \
        --log-file "$__berkely_migration_log" \
        --precomputed-blocks-local-path "$__precomputed_blocks_local_path"
    
    set +e # skip error because we will do validations and we are better than replayer i reporting

    mina-migration-replayer \
        --migration-mode \
        --archive-uri "$__migrated_archive_uri" \
        --input-file "$__replayer_checkpoint" \
        --checkpoint-interval "$__checkpoint_interval" \
        --checkpoint-file-prefix "$CHECKPOINT_PREFIX" \
        --checkpoint-output-folder "$__checkpoint_output_path" \
        --log-file "$__replayer_log"

    check_logs "$__berkely_migration_log" "$__replayer_log"

    set -e # exit immediately on errors

    check_new_replayer_checkpoints_for_incremental "$CHECKPOINT_PREFIX"

    mina-berkeley-migration-verifier pre-fork \
        --mainnet-archive-uri "$__mainnet_archive_uri" \
        --migrated-archive-uri "$__migrated_archive_uri"
}

function final_help(){
    echo Final migration based on latest source database and last replayer checkpoint 
    echo while migrating into already existing migrated database.
    echo It also require fork-state-hash parameter which is fork block hash. Such fork block should
    echo "be announced by mina foundation of o(1)labs team"
    echo ""
    echo "     $CLI_NAME final [-options]"
    echo ""
    echo "Parameters:"
    echo ""
    printf "  %-25s %s\n" "-h | --help" "show help";
    printf "  %-25s %s\n" "-g | --genesis-ledger" "[file] path to genesis ledger file";
    printf "  %-25s %s\n" "-r | --replayer-checkpoint" "[file] path to genesis ledger file";
    printf "  %-25s %s\n" "-s | --source-db" "[connection_str] connection string to database to be migrated";
    printf "  %-25s %s\n" "-t | --target-db" "[connection_str] connection string to database which will hold migrated data";
    printf "  %-25s %s\n" "-b | --blocks-bucket" "[string] name of precomputed blocks bucket. NOTICE: there is an assumption that precomputed blocks are named with format: {network}-{height}-{state_hash}.json";
    printf "  %-25s %s\n" "-bs | --blocks-batch-size" "[int] number of precomputed blocks to be fetch at once from Gcloud. Bigger number like 1000 can help speed up migration process";
    printf "  %-25s %s\n" "-n | --network" "[string] network name when determining precomputed blocks. NOTICE: there is an assumption that precomputed blocks are named with format: {network}-{height}-{state_hash}.json";
    printf "  %-25s %s\n" "-fc | --fork-genesis-config" "[file] Genesis config file for the fork network. It should be provied by MF or O(1)Labs team after fork block is announced";
    printf "  %-25s %s\n" "-d | --delete-blocks" "delete blocks after they are processed (saves space with -sb)"
    printf "  %-25s %s\n" "-p | --prefetch-blocks" "downloads all blocks at once instead of incrementally"
    printf "  %-25s %s\n" "-c | --checkpoint-output-path" "[file] output folder for replayer checkpoints"
    printf "  %-25s %s\n" "-l | --precomputed-blocks-local-path" "[file] on-disk precomputed blocks location"
    echo ""
    echo "Example:"
    echo ""
    echo "  " $CLI_NAME final --replayer-checkpoint migration-replayer-checkpoint-1233.json --genesis-ledger "genesis_ledgers/mainnet.json" --source-db "postgres://postgres:pass@localhost:5432/archive_balances_migrated" --target-db "postgres://postgres:pass@localhost:5432/migrated" --blocks-batch-size 10 --blocks-bucket "mina_network_block_data" --network "mainnet" --fork-genesis-config fork_genesis_config.json 
    echo ""
    echo "Notes:"
    echo "  1. After run migrated data will be filled with migrated blocks till last block in source db"
    echo "  2. Two logs files will be generated for archiving/debugging operations"
    echo "  3. Replayer checkpoints (migration-replayer-XXX.json) will be generated"
    echo ""
    exit 0
}

function final(){
    if [[ ${#} == 0 ]]; then
        final_help;
    fi

    local __batch_size=10
    local __mainnet_archive_uri=''
    local __migrated_archive_uri='' 
    local __genesis_ledger=''
    local __replayer_checkpoint=''
    local __blocks_bucket=''
    local __keep_precomputed_blocks=true
    local __stream_blocks=true
    local __network='' 
    local __checkpoint_interval=1000
    local __fork_genesis_config=''
    local __checkpoint_output_path='.'
    local __precomputed_blocks_local_path='.'
    
    while [ ${#} -gt 0 ]; do
        error_message="Error: a value is needed for '$1'";
        case $1 in
            -h | --help ) 
                final_help;
            ;;
            -g | --genesis-ledger )
                __genesis_ledger=${2:?$error_message}
                shift 2;
            ;;
            -fc | --fork-genesis-config )
                __fork_genesis_config=${2:?$error_message}
                shift 2;
            ;;
            -r | --replayer-checkpoint )
                __replayer_checkpoint=${2:?$error_message}
                shift 2;
            ;;
            -i | --checkpoint-interval )
                __checkpoint_interval=${2:?$error_message}
                shift 2;
            ;;
            -s | --source-db )
                __mainnet_archive_uri=${2:?$error_message}
                shift 2;
            ;;
            -t | --target-db )
                __migrated_archive_uri=${2:?$error_message}
                shift 2;
            ;;
            -b | --blocks-bucket )
                __blocks_bucket=${2:?$error_message}
                shift 2;
            ;;
            -bs | --blocks-batch-size )
                __batch_size=${2:?$error_message}
                shift 2;
            ;;
            -n | --network )
                __network=${2:?$error_message}
                shift 2;
            ;;
            -d | --delete-blocks )
                __keep_precomputed_blocks=false
                shift 1;
            ;;
            -p | --prefetch-blocks )
                __stream_blocks=false
                shift 1;
            ;;
            -c | --checkpoint-output-path )
                __checkpoint_output_path=${2:?$error_message}
                shift 2;
            ;;
            -l | --precomputed-blocks-local-path )
                __precomputed_blocks_local_path=${2:?$error_message}
                shift 2;
            ;;
            * )
                echo -e "${RED} !! Unknown option: $1${CLEAR}\n";
                echo "";
                final_help;
            ;;
        esac
    done
    
    if [ -z "$__mainnet_archive_uri" ]; then
        echo ""
        echo "Source db not defined"
        exit 1
    fi

    if [ -z "$__migrated_archive_uri" ]; then
        echo ""
        echo "'-t|--target-db' argument is not provided. Please provide valid connection string"
        echo "to existing and initially migrated database. If you don't have such schema please refer to help in 'initial' subcommand" 
        exit 1
    fi
    if [ -z "$__replayer_checkpoint" ]; then
        echo ""
        echo "Replayer checkpoint not defined. Please provide path to latest replayer checkpoint file"
        echo "which should be generated on previous incremental run or inital"
        exit 1
    fi
    if [ -z "$__genesis_ledger" ]; then
        echo ""
        echo "Genesis ledger not defined"
        exit 1
    fi
    if [ -z "$__fork_genesis_config" ]; then
        echo ""
        echo "Fork genesis config file is not defined. Please refer to mina or o(1) Labs team announcements regarding fork block state hash"
        echo "which is required to run final migration"
        exit 1
    fi

    if [ -z "$__blocks_bucket" ]; then
        echo ""
        echo "Precomputed blocks google cloud bucket not defined"
        exit 1
    fi
    if [ -z "$__network" ]; then
        echo ""
        echo "Network not defined"
        exit 1
    fi
    
    run_final_migration "$__batch_size" \
        "$__mainnet_archive_uri" \
        "$__migrated_archive_uri" \
        "$__genesis_ledger" \
        "$__blocks_bucket" \
        "$__keep_precomputed_blocks" \
        "$__stream_blocks" \
        "$__network" \
        "$__checkpoint_interval" \
        "$__replayer_checkpoint" \
        "$__fork_genesis_config" \
        "$__checkpoint_output_path" \
        "$__precomputed_blocks_local_path"
}

function run_final_migration() {
    local __batch_size=$1
    local __mainnet_archive_uri=$2
    local __migrated_archive_uri=$3 
    local __genesis_ledger=$4
    local __blocks_bucket=$5
    local __keep_precomputed_blocks=$6
    local __stream_blocks=$7
    local __network=$8
    local __checkpoint_interval=$9
    local __replayer_checkpoint=${10}
    local __fork_genesis_config=${11}
    local __checkpoint_output_path=${12}
    local __precomputed_blocks_local_path=${13}
    
    local __fork_state_hash="$(jq -r .proof.fork.state_hash "$__fork_genesis_config")"
    local __date=$(date '+%Y-%m-%d_%H%M')
    local __berkely_migration_log="berkeley_migration_$__date.log"
    local __replayer_log="replayer_$__date.log"
    
    if [ ! -f "$__genesis_ledger" ]; then
        echo ""
        echo "Genesis ledger file not found: $__genesis_ledger"
        exit 1
    fi
    
    mina-berkeley-migration \
        --mainnet-archive-uri "$__mainnet_archive_uri" \
        --migrated-archive-uri "$__migrated_archive_uri" \
        --batch-size "$__batch_size" \
        --config-file "$__genesis_ledger" \
        --blocks-bucket "$__blocks_bucket" \
        $(format_migration_args "$__keep_precomputed_blocks" "$__stream_blocks") \
        --fork-state-hash "$__fork_state_hash" \
        --network "$__network" \
        --log-file "$__berkely_migration_log" \
        --precomputed-blocks-local-path "$__precomputed_blocks_local_path"
    
    set +e # skip error because we will do validations and we are better than replayer i reporting

    mina-migration-replayer \
        --migration-mode \
        --archive-uri "$__migrated_archive_uri" \
        --input-file "$__replayer_checkpoint" \
        --checkpoint-interval "$__checkpoint_interval" \
        --checkpoint-file-prefix "$CHECKPOINT_PREFIX" \
        --checkpoint-output-folder "$__checkpoint_output_path" \
        --log-file "$__replayer_log"

    check_logs "$__berkely_migration_log" "$__replayer_log"
    set -e # exit immediately on errors

    check_incremental_migration_progress "$__replayer_checkpoint" "$__migrated_archive_uri" 
    check_new_replayer_checkpoints_for_incremental "$CHECKPOINT_PREFIX"

    # sort by https://stackoverflow.com/questions/60311787/how-to-sort-by-numbers-that-are-part-of-a-filename-in-bash
    local migrated_replayer_output=$(find . -maxdepth 1 -name "$CHECKPOINT_PREFIX-checkpoint*.json"  | sort -Vrt - -k3,3 | head -n 1)

    mina-berkeley-migration-verifier post-fork \
        --mainnet-archive-uri "$__mainnet_archive_uri" \
        --migrated-archive-uri "$__migrated_archive_uri" \
        --fork-genesis-config "$__fork_genesis_config" \
        --migrated-replayer-output "$migrated_replayer_output"

}

function main(){
    if (( ${#} == 0 )); then
        main_help 0;
    fi

    case ${1} in
        help )
            main_help 0;
        ;;
        version | initial | incremental | final )
            $1 "${@:2}";
        ;;
        * )
            echo -e "${RED} !! Unknown command: $1${CLEAR}\n";
            main_help 1;
        ;;
    esac
}

main "$@";
