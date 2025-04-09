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
# global variables
################################################################################
CLI_VERSION='1.0.0';
CLI_NAME="$0";
PS4='debug($LINENO) ${FUNCNAME[0]:+${FUNCNAME[0]}}(): ';

DEFAULT_ARTIFACTS="mina-logproc,mina-archive,mina-rosetta,mina-daemon"
DEFAULT_NETWORKS="devnet,mainnet"
DEFAULT_CODENAMES="bullseye,focal"
DEFAULT_ARCHITECTURE="amd64"

DEBIAN_CACHE_FOLDER=~/.release/debian/cache
GCR_REPO="gcr.io/o1labs-192920"
DOCKER_IO_REPO="docker.io/minaprotocol"
DEBIAN_REPO=packages.o1test.net

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SUBCOMMAND_TAB="        "
HETZNER_USER=u434410
HETZNER_HOST=u434410-sub2.your-storagebox.de
HETZNER_KEY=${HETZNER_KEY:-$HOME/.ssh/id_rsa}
################################################################################
# pre-setup
################################################################################

function check_gsutil() {
    check_app "gsutil"
}

function check_docker() {
    check_app "docker"
}

function check_app() {
    if ! command -v $1 &> /dev/null; then
        echo -e "❌ ${RED} !! $1 program not found. Please install program to proceed. ${CLEAR}\n";
        exit 1
    fi
}

mkdir -p $DEBIAN_CACHE_FOLDER

################################################################################
# imports
################################################################################
. $SCRIPTPATH/../../../scripts/debian/reversion-helper.sh


################################################################################
# functions
################################################################################

function prefix_cmd {
    local PREF="${1//\//\\/}" # replace / with \/
    shift
    local CMD=("$@")
    "${CMD[@]}" 1> >(sed "s/^/${PREF}/") 2> >(sed "s/^/${PREF}/" 1>&2)
}

function main_help(){
    echo Publish/Promote mina build artifact. 
    echo Script can publish build based on buildkite build id to debian repository and docker registry. 
    echo "Script can also promote artifacts (debian packages and docker images) from one channel to another."
    echo ""
    echo "     $CLI_NAME [operation]"
    echo ""
    echo "Sub-commands:"
    echo ""
    echo " publish - publish build artifact to debian repository and docker registry";
    echo " promote - promote artifacts from one channel (registry) to another";
    echo " fix - fix debian package repository";
    echo " verify - verify artifacts in target channel (registry)";
    echo " version - show version";    
    echo ""
    echo ""
    echo "Defaults: "
    echo " artifacts: $DEFAULT_ARTIFACTS"
    echo " networks: $DEFAULT_NETWORKS"
    echo " codenames: $DEFAULT_CODENAMES"
    echo " architecture: $DEFAULT_ARCHITECTURE"
    echo ""
    echo "Available values: "
    echo " artifacts: mina-logproc,mina-archive,mina-rosetta,mina"
    echo " networks: devnet,mainnet"
    echo " codenames: bullseye,focal"
    echo " channels: unstable,alpha,beta,stable"
    echo ""
    
    exit "${1:-0}";
}

function version(){
    echo $CLI_NAME $CLI_VERSION;
    exit 0
}

function get_suffix() {
    local __artifact=$1
    local __network="${2:-""}"

    case $__artifact in
        mina-daemon)
            echo "-$__network"
        ;;
        mina-rosetta)
            echo "-$__network"
        ;;
     
        *)
            echo ""
        ;;
    esac
}

function get_repo() {
    local __publish_to_docker_io="$1"

    if [[ $__publish_to_docker_io == 1 ]]; then
        echo $DOCKER_IO_REPO
    else
        echo $GCR_REPO
    fi

}

function get_artifact_with_suffix() {
    local __artifact=$1
    local __network="${2:-""}"

    case $__artifact in
        mina-daemon)
            echo "mina-$__network"
        ;;
        mina-rosetta)
            echo "mina-rosetta-$__network"
        ;;
     
        *)
            echo "$__artifact"
        ;;
    esac
}


function calculate_debian_version() {
    local __artifact=$1
    local __target_version=$2
    local __codename=$3
    local __network=$4

    local __network_suffix=$(get_suffix $__artifact $__network)
    echo "$__artifact:$__target_version-$__codename$__network_suffix"
}


function calculate_docker_tag() {
    local __publish_to_docker_io=$1
    local __artifact=$2
    local __target_version=$3
    local __codename=$4
    local __network=$5

    local __network_suffix=$(get_suffix $__artifact $__network)
    
    if [[ $__publish_to_docker_io == 1 ]]; then
        echo "$DOCKER_IO_REPO/$__artifact:$__target_version-$__codename$__network_suffix"
    else
        echo "$GCR_REPO/$__artifact:$__target_version-$__codename$__network_suffix"
    fi
}

function storage_list() {
    local backend=$1
    local path=$2

    case $backend in
        gs)
            gsutil list "$path"
            ;;

        hetzner)
            ssh -p23 -i $HETZNER_KEY $HETZNER_USER@$HETZNER_HOST "ls $path"
            ;;
        *)
            echo "❌ Unsupported backend: $backend"
            exit 1
            ;;
    esac
}

function storage_md5() {
    local backend=$1
    local path=$2

    case $backend in
        gs)
            gsutil hash -h -m "$path" | grep "Hash (md5)" | awk '{print $3}'
            ;;
        hetzner)
            ssh -p23 -i $HETZNER_KEY $HETZNER_USER@$HETZNER_HOST  "md5sum $path" | awk '{print $1}'
            ;;
        *)
            echo "❌ Unsupported backend: $backend"
            exit 1
            ;;
    esac
}

function storage_download() {
    local backend=$1
    local remote_path=$2
    local local_path=$3

    case $backend in
        gs)
            gsutil cp "$remote_path" "$local_path"
            ;;
        hetzner)
           ssh -p 23 -i $HETZNER_KEY $HETZNER_USER@$HETZNER_HOST "ls $remote_path" | xargs -I {} rsync -avz --rsh="ssh -p 23 -i $HETZNER_KEY" $HETZNER_USER@$HETZNER_HOST:{} $local_path
            ;;
        *)
            echo "❌ Unsupported backend: $backend"
            exit 1
            ;;
    esac
}

function get_cached_debian_or_download() {
    local backend=$1
    local artifact=$2
    local codename=$3
    local network=$4

    local artifact_full_name=$(get_artifact_with_suffix "$artifact" "$network")
    local remote_path
    if [[ $backend == "gs" ]]; then
        remote_path="gs://buildkite_k8s/coda/shared/$BUILDKITE_BUILD_ID/debians/$codename/${artifact_full_name}_*"
    elif [[ $backend == "hetzner" ]]; then
        remote_path="/home/o1labs-generic/pvc-4d294645-6466-4260-b933-1b909ff9c3a1/$BUILDKITE_BUILD_ID/debians/$codename/${artifact_full_name}_*"
    else
        echo "❌ Unsupported backend: $backend"
        exit 1
    fi

    local check=$(storage_list "$backend" "$remote_path")

    if [[ -z "$check" ]]; then
        echo -e "❌ ${RED} !! No debian package found using $artifact_full_name. Are you sure ($BUILDKITE_BUILD_ID) buildkite build is correct? Exiting.${CLEAR}\n"
        exit 1
    fi

    local target_hash=$(storage_md5 "$backend" "$remote_path")

    mkdir -p "$DEBIAN_CACHE_FOLDER/$codename"

    echo " 🗂️  Checking cache for $codename/$artifact_full_name Debian package"

    if md5sum "$DEBIAN_CACHE_FOLDER/$codename/${artifact_full_name}"* | awk '{print $1}' | grep -q "$target_hash" > /dev/null; then
        echo "   🗂️  $artifact_full_name Debian package already cached. Skipping download."
    else
        echo "   📂  $artifact_full_name Debian package is not cached. Downloading from $backend."
        storage_download "$backend" "$remote_path" "$DEBIAN_CACHE_FOLDER/$codename"
    fi
}


function publish_debian() {
    local __artifact=$1
    local __codename=$2
    local __source_version=$3
    local __target_version=$4
    local __channel=$5
    local __network=$6
    local __verify=$7
    local __dry_run=$8
    local __backend=$9

    get_cached_debian_or_download $__backend $__artifact $__codename "$__network"
    local __artifact_full_name=$(get_artifact_with_suffix $__artifact $__network)
    local __deb=$DEBIAN_CACHE_FOLDER/$__codename/"${__artifact_full_name}"

    if [[ $__source_version != "$__target_version" ]]; then
        echo " 🗃️  Rebuilding $__artifact debian from $__source_version to $__target_version"
        prefix_cmd "$SUBCOMMAND_TAB" reversion --deb ${__deb} \
                --package ${__artifact_full_name} \
                --source-version ${__source_version} \
                --new-version ${__target_version} \
                --suite "unstable" \
                --new-suite ${__channel} \
                --new-name ${__artifact_full_name} \
                --new-release ${__channel} \
                --codename ${__codename}
    fi

    echo " 🍥  Publishing $__artifact debian to $__channel channel with $__target_version version"
    echo "     📦  Target debian version: $(calculate_debian_version $__artifact $__target_version $__codename "$__network" )"
    if [[ $__dry_run == 0 ]]; then
        prefix_cmd "$SUBCOMMAND_TAB" source $SCRIPTPATH/../../../scripts/debian/publish.sh \
            --names "$DEBIAN_CACHE_FOLDER/$__codename/${__artifact_full_name}_${__target_version}.deb" \
            --version $__target_version \
            -c $__codename \
            -r $__channel

        if [[ $__verify == 1 ]]; then

            echo "     📋 Verifying: $__artifact debian to $__channel channel with $__target_version version"
  
            prefix_cmd "$SUBCOMMAND_TAB" source $SCRIPTPATH/../../../scripts/debian/verify.sh \
                -p $__artifact_full_name \
                --version $__target_version \
                -m $__codename \
                -c $__channel 
        fi
    fi
}


function promote_and_verify_docker() {
    local __artifact=$1
    local __source_version=$2
    local __target_version=$3
    local __codename=$4
    local __network=$5
    local __publish_to_docker_io=$6
    local __verify=$7
    local __dry_run=$8
    
    local __network_suffix=$(get_suffix $__artifact $__network)

    local __artifact_full_source_version=$__source_version-$__codename${__network_suffix}
    local __artifact_full_target_version=$__target_version-$__codename${__network_suffix}
   
    if [[ $__publish_to_docker_io == 1 ]]; then
        local __publish_arg="-p"
        local __repo=$DOCKER_IO_REPO
    else
        local __publish_arg=""
        local __repo=$GCR_REPO
    fi

    echo " 🐋 Publishing $__artifact docker for '$__network' network and '$__codename' codename with '$__target_version' version"
    echo "    📦 Target version: $(calculate_docker_tag $__publish_to_docker_io $__artifact $__target_version $__codename "$__network" )"
    echo ""
    if [[ $__dry_run == 0 ]]; then
        prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/docker/promote.sh \
            -q \
            -n "$__artifact" \
            -v $__artifact_full_source_version \
            -t $__artifact_full_target_version \
            $__publish_arg

            echo ""

        if [[ $__verify == 1 ]]; then

            echo "    📋 Verifying: $__artifact docker for '$__network' network and '$__codename' codename with '$__target_version' version"
            echo ""

            prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/docker/verify.sh \
                -p "$__artifact" \
                -v "$__target_version" \
                -c "$__codename" \
                -s "$__network_suffix" \
                -r "$__repo" 

            echo ""
        fi
    fi
}

function promote_debian() {
    local __artifact=$1
    local __codename=$2
    local __source_version=$3
    local __target_version=$4
    local __source_channel=$5
    local __target_channel=$6
    local __network=$7
    local __verify=$8
    local __dry_run=$9

    echo " 🍥 Promoting $__artifact debian from $__source_channel to $__target_channel, from $__source_version to $__target_version"
    echo "    📦 Target debian version: $(calculate_debian_version $__artifact $__target_version $__codename "$__network")"
    
    local __artifact_full_name=$(get_artifact_with_suffix $__artifact $__network)
    local __deb=$DEBIAN_CACHE_FOLDER/$__codename/"${__artifact_full_name}"

    if [[ $__dry_run == 0 ]]; then
        echo "    🗃️  Promoting $__artifact debian from $__codename/$__source_version to $__codename/$__target_version"
        prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/debian/reversion.sh \
                --deb ${__artifact_full_name} \
                --version ${__source_version} \
                --release ${__source_channel} \
                --new-version ${__target_version} \
                --suite ${__source_channel} \
                --repo ${DEBIAN_REPO} \
                --new-suite ${__target_channel} \
                --new-name ${__artifact_full_name} \
                --new-release ${__target_channel} \
                --codename ${__codename} \

        if [[ $__verify == 1 ]]; then
            echo "     📋 Verifying: $__artifact debian to $__target_channel channel with $__target_version version"
  
            prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/debian/verify.sh \
                -p $__artifact_full_name \
                --version $__target_version \
                -m $__codename \
                -c $__target_channel 
        fi
    fi
}


#========
# Publish
#========

function publish_help(){
    echo Publish mina build artifacts from google cloud cache to debian repository and docker registry.
    echo ""
    echo "     $CLI_NAME publish [-options]"
    echo ""
    echo "Parameters:"
    echo ""
    printf "  %-25s %s\n" "-h  | --help" "show help";
    printf "  %-25s %s\n" "--artifacts" "[comma separated list] list of artifacts to publish. e.g mina-logproc,mina-archive,mina-rosetta";
    printf "  %-25s %s\n" "--networks" "[comma separated list] list of networks to publish. e.g devnet,mainnet"; 
    printf "  %-25s %s\n" "--buildkite-build-id" "[string] buildkite build id of release build to publish"; 
    printf "  %-25s %s\n" "--source-version" "[path] source version of build to publish"; 
    printf "  %-25s %s\n" "--target-version" "[path] target version of build to publish"; 
    printf "  %-25s %s\n" "--codenames" "[comma separated list] list of debian codenames to publish. e.g bullseye,focal"; 
    printf "  %-25s %s\n" "--channel" "[string] target debian channel"; 
    printf "  %-25s %s\n" "--publish-to-docker-io" "[bool] publish to docker.io instead of gcr.io"; 
    printf "  %-25s %s\n" "--only-dockers" "[bool] publish only docker images"; 
    printf "  %-25s %s\n" "--only-debians" "[bool] publish only debian packages"; 
    printf "  %-25s %s\n" "--verify" "[bool] verify packages are published correctly. WARINING: it requires docker engine to be installed"; 
    printf "  %-25s %s\n" "--dry-run" "[bool] doesn't publish anything. Just print what would be published"; 
    printf "  %-25s %s\n" "--backend" "[string] backend to use for storage. e.g gs,hetzner. default: gs";
    echo ""
    echo "Example:"
    echo ""
    echo "  " $CLI_NAME publish --artifacts mina-logproc,mina-archive,mina-rosetta --networks devnet,mainnet --buildkite-build-id 123 --source-version 2.0.0-rc1-48efea4 --target-version 2.0.0-rc1-48efea5 --codenames bullseye,focal --channel alpha --publish-to-docker-io --only-dockers --verify --dry-run
    echo ""
    echo " Above command will publish mina-logproc,mina-archive,mina-rosetta artifacts to debian repository and docker registry"
    echo ""
    echo ""
}

function publish(){
    if [[ ${#} == 0 ]]; then
        publish_help; exit 0;
    fi

    local __artifacts="$DEFAULT_ARTIFACTS"
    local __networks="$DEFAULT_NETWORKS"
    local __buildkite_build_id
    local __source_version
    local __target_version
    local __codenames="$DEFAULT_CODENAMES"
    local __channel
    local __publish_to_docker_io=0
    local __only_dockers=0
    local __only_debians=0
    local __verify=0
    local __dry_run=0
    local __backend="gs"

    while [ ${#} -gt 0 ]; do
        error_message="❌ Error: a value is needed for '$1'";
        case $1 in
            -h | --help ) 
                publish_help; exit 0;
            ;;
            --artifacts )
                __artifacts=${2:?$error_message}
                shift 2;
            ;;
            --networks )
                __networks=${2:?$error_message}
                shift 2;
            ;;
            --buildkite-build-id )
                __buildkite_build_id=${2:?$error_message}
                shift 2;
            ;;
            --source-version )
                __source_version=${2:?$error_message}
                shift 2;
            ;;
            --target-version )
                __target_version=${2:?$error_message}
                shift 2;
            ;;
            --codenames )
                __codenames=${2:?$error_message}
                shift 2;
            ;;
            --channel )
                __channel=${2:?$error_message}
                shift 2;
            ;;
            --publish-to-docker-io )
                __publish_to_docker_io=1
                shift 1;
            ;;
            --only-dockers )
                __only_dockers=1
                shift 1;
            ;;
            --only-debians )
                __only_debians=1
                shift 1;
            ;;
            --verify )
                __verify=1
                shift 1;
            ;;
            --dry-run )
                __dry_run=1
                shift 1;
            ;;
            --backend )
                __backend=${2:?$error_message}
                shift 2;
            ;;
            * )     
                echo -e "❌ ${RED} !! Unknown option: $1${CLEAR}\n";
                echo "";
                publish_help; exit 1;
            ;;
        esac
    done

    if [[ -z ${__target_version+x} ]]; then
        echo -e "❌ ${RED} !! Target version (--target-version) is required${CLEAR}\n";
        publish_help; exit 1;
    fi

    if [[ -z ${__source_version+x} ]]; then
        echo -e "❌ ${RED} !! Source version (--source-version) is required${CLEAR}\n";
        publish_help; exit 1;
    fi

    if [[ -z ${__buildkite_build_id+x} ]]; then
        echo -e "❌ ${RED} !! Buildkite build id (--buildkite-build-id) is required${CLEAR}\n";
        publish_help; exit 1;
    fi

    if [[ -z ${__channel+x} ]]; then
        echo -e "❌ ${RED} !! Channel (--channel) is required${CLEAR}\n";
        publish_help; exit 1;
    fi

    echo ""
    echo " ℹ️  Publishing mina artifacts with following parameters:"
    echo " - Publishing artifacts: $__artifacts"
    echo " - Publishing networks: $__networks"
    echo " - Buildkite build id: $__buildkite_build_id"
    echo " - Source version: $__source_version"
    echo " - Target version: $__target_version"
    echo " - Publishing codenames: $__codenames"
    echo " - Target channel: $__channel"
    echo " - Publish to docker.io: $__publish_to_docker_io"
    echo " - Only dockers: $__only_dockers"
    echo " - Only debians: $__only_debians"
    echo " - Verify: $__verify"
    echo " - Dry run: $__dry_run"
    echo ""

    if [[ $__backend != "gs" && $__backend != "hetzner" ]]; then
        echo -e "❌ ${RED} !! Backend (--backend) can be only gs or hetzner${CLEAR}\n";
        publish_help; exit 1;
    fi

    if [[ $__backend == "gs" ]]; then
        #check environment setup
        check_gsutil
    fi
   
    if [[ $__verify == 1 ]]; then
        check_docker
    fi
 
    export BUILDKITE_BUILD_ID=$__buildkite_build_id

    IFS=', '
    read -r -a __artifacts_arr <<< "$__artifacts"
    read -r -a __networks_arr <<< "$__networks"
    read -r -a __codenames_arr <<< "$__codenames"
    
    for artifact in "${__artifacts_arr[@]}"; do
        for __codename in "${__codenames_arr[@]}"; do
                case $artifact in
                        mina-logproc)
                            
                            if [[ $__only_dockers == 0 ]]; then
                                    publish_debian $artifact \
                                        $__codename \
                                        $__source_version \
                                        $__target_version \
                                        $__channel \
                                        "" \
                                        $__verify \
                                        $__dry_run \
                                        $__backend
                            fi

                            if [[ $__only_debians == 0 ]]; then
                                echo "ℹ️  There is no $artifact docker image to publish. skipping"
                            fi
                            
                        ;;
                        mina-archive)
                                if [[ $__only_dockers == 0 ]]; then
                                        publish_debian $artifact \
                                            $__codename \
                                            $__source_version \
                                            $__target_version \
                                            $__channel \
                                            "" \
                                            $__verify \
                                            $__dry_run \
                                            $__backend
                                fi

                                if [[ $__only_debians == 0 ]]; then
                                    promote_and_verify_docker $artifact $__source_version $__target_version $__codename "" $__publish_to_docker_io $__verify $__dry_run
                                fi
                        ;;
                        mina-rosetta)
                            for network in "${__networks_arr[@]}"; do
                                if [[ $__only_dockers == 0 ]]; then
                                    publish_debian $artifact \
                                            $__codename \
                                            $__source_version \
                                            $__target_version \
                                            $__channel \
                                            $network \
                                            $__verify \
                                            $__dry_run \
                                            $__backend
                                fi

                                if [[ $__only_debians == 0 ]]; then
                                    promote_and_verify_docker $artifact $__source_version $__target_version $__codename $network $__publish_to_docker_io $__verify $__dry_run
                                fi
                            done
                        ;;
                        mina-daemon)
                            for network in "${__networks_arr[@]}"; do
                                if [[ $__only_dockers == 0 ]]; then
                                    publish_debian $artifact \
                                            $__codename \
                                            $__source_version \
                                            $__target_version \
                                            $__channel \
                                            $network \
                                            $__verify \
                                            $__dry_run \
                                            $__backend
                                    
                                fi

                                if [[ $__only_debians == 0 ]]; then
                                    promote_and_verify_docker $artifact $__source_version $__target_version $__codename $network $__publish_to_docker_io $__verify $__dry_run
                                fi
                            done
                        ;;
                        *)
                            echo "❌ Unknown artifact: $artifact"
                            exit 1
                        ;;
                    esac
        done
    done

    echo " ✅  Publishing done."
    echo ""
}


#==============
# promote
#==============
function promote_help(){
    echo Promote mina artifacts from channel/docker registry to new location.
    echo ""
    echo "     $CLI_NAME promote [-options]"
    echo ""
    echo "Parameters:"
    echo ""
    printf "  %-25s %s\n" "-h  | --help" "show help";
    printf "  %-25s %s\n" "--artifacts" "[comma separated list] list of artifacts to publish. e.g mina-logproc,mina-archive,mina-rosetta";
    printf "  %-25s %s\n" "--networks" "[comma separated list] list of networks to publish. e.g devnet,mainnet"; 
    printf "  %-25s %s\n" "--source-version" "[path] source version of build to publish"; 
    printf "  %-25s %s\n" "--target-version" "[path] target version of build to publish"; 
    printf "  %-25s %s\n" "--codenames" "[comma separated list] list of debian codenames to publish. e.g bullseye,focal"; 
    printf "  %-25s %s\n" "--source-channel" "[string] source debian channel"; 
    printf "  %-25s %s\n" "--target-channel" "[string] target debian channel"; 
    printf "  %-25s %s\n" "--publish-to-docker-io" "[bool] publish to docker.io instead of gcr.io"; 
    printf "  %-25s %s\n" "--only-dockers" "[bool] publish only docker images"; 
    printf "  %-25s %s\n" "--only-debians" "[bool] publish only debian packages"; 
    printf "  %-25s %s\n" "--verify" "[bool] verify packages are published correctly. WARINING: it requires docker engine to be installed"; 
    printf "  %-25s %s\n" "--dry-run" "[bool] doesn't publish anything. Just print what would be published"; 
    echo ""
    echo "Example:"
    echo ""
    echo "  " $CLI_NAME promote --artifacts mina-logproc,mina-archive,mina-rosetta --networks devnet,mainnet --buildkite-build-id 123 --source-version 2.0.0-rc1-48efea4 --target-version 2.0.0-rc1-48efea5 --codenames bullseye,focal --source-channel unstable --target-channel nightly --publish-to-docker-io --only-dockers --verify --dry-run
    echo ""
    echo " Above command will promote mina-logproc,mina-archive,mina-rosetta artifacts to debian repository and docker registry"
    echo ""
    echo ""
}

function promote(){
    if [[ ${#} == 0 ]]; then
        promote_help; exit 0;
    fi

    local __artifacts="$DEFAULT_ARTIFACTS"
    local __networks="$DEFAULT_NETWORKS"
    local __source_version
    local __target_version
    local __codenames="$DEFAULT_CODENAMES"
    local __source_channel
    local __target_channel
    local __publish_to_docker_io=0
    local __only_dockers=0
    local __only_debians=0
    local __verify=0
    local __dry_run=0


    while [ ${#} -gt 0 ]; do
        error_message="❌ Error: a value is needed for '$1'";
        case $1 in
            -h | --help ) 
                promote_help; exit 0;
            ;;
            --artifacts )
                __artifacts=${2:?$error_message}
                shift 2;
            ;;
            --networks )
                __networks=${2:?$error_message}
                shift 2;
            ;;
            --source-version )
                __source_version=${2:?$error_message}
                shift 2;
            ;;
            --target-version )
                __target_version=${2:?$error_message}
                shift 2;
            ;;
            --codenames )
                __codenames=${2:?$error_message}
                shift 2;
            ;;
            --source-channel )
                __source_channel=${2:?$error_message}
                shift 2;
            ;;
            --target-channel )
                __target_channel=${2:?$error_message}
                shift 2;
            ;;
            --publish-to-docker-io )
                __publish_to_docker_io=1
                shift 1;
            ;;
            --only-dockers )
                __only_dockers=1
                shift 1;
            ;;
            --only-debians )
                __only_debians=1
                shift 1;
            ;;
            --verify )
                __verify=1
                shift 1;
            ;;
            --dry-run )
                __dry_run=1
                shift 1;
            ;;
            * )     
                echo -e "${RED} !! Unknown option: $1${CLEAR}\n";
                echo "";
                promote_help; exit 1;
            ;;
        esac
    done

    if [[ -z ${__target_version+x} ]]; then
        echo -e "❌ ${RED} !! Target version (--target-version) is required${CLEAR}\n";
        promote_help; exit 1;
    fi

    if [[ -z ${__source_version+x} ]]; then
        echo -e "❌ ${RED} !! Source version (--source-version) is required${CLEAR}\n";
        promote_help; exit 1;
    fi

    if [[ -z ${__source_channel+x} && $__only_dockers == 0 ]]; then
        echo -e "❌ ${RED} !! Source channel (--source-channel) is required${CLEAR}\n";
        promote_help; exit 1;
    fi

    if [[ -z ${__target_channel+x} && $__only_dockers == 0 ]]; then
        echo -e "❌ ${RED} !! Target channel (--target-channel) is required${CLEAR}\n";
        promote_help; exit 1;
    fi

    echo ""
    echo " ℹ️   Promotion mina artifacts with following parameters:"
    echo " - Promoting artifacts: $__artifacts"
    echo " - Networks: $__networks"
    echo " - Promoting codenames: $__codenames"
    if [[ $__only_dockers == 1 ]]; then
        if [[ -n ${__source_channel+x} ]]; then
            echo " - Source channel: $__source_channel"
        fi
        if [[ -n ${__target_channel+x} ]]; then
            echo " - Target channel: $__target_channel"
        fi
        if [[ -n ${__source_version+x} ]]; then
            echo " - Source version: $__source_version"
        fi
        if [[ -n ${__target_version+x} ]]; then
            echo " - Target version: $__target_version"
        fi
    fi
    echo " - Publish to docker.io: $__publish_to_docker_io"
    echo " - Only dockers: $__only_dockers"
    echo " - Only debians: $__only_debians"
    echo " - Verify: $__verify"
    echo " - Dry run: $__dry_run"
    echo ""

    #check environment setup
    if [[ $__verify == 1 ]]; then
        check_docker
    fi

    if [[ $__source_version == "$__target_version" ]]; then
        echo " ⚠️  Warning: Source version and target version are the same. 
    Script will do promotion but it won't have an effect at the end unless you are publishing dockers from gcr.io to docker.io ..."
        echo ""
    fi

    IFS=', '
    read -r -a __artifacts_arr <<< "$__artifacts"
    read -r -a __networks_arr <<< "$__networks"
    read -r -a __codenames_arr <<< "$__codenames"

    for artifact in "${__artifacts_arr[@]}"; do
        for __codename in "${__codenames_arr[@]}"; do
                    case $artifact in
                        mina-logproc)
                            
                            if [[ $__only_dockers == 0 ]]; then
                                promote_debian $artifact \
                                    $__codename \
                                    $__source_version \
                                    $__target_version \
                                    $__source_channel \
                                    $__target_channel \
                                    "" \
                                    $__verify \
                                    $__dry_run
                            fi

                            if [[ $__only_debians == 0 ]]; then
                                echo "   ℹ️  There is no mina-logproc docker image to promote. skipping"
                            fi

                            
                        ;;
                        mina-archive)
                                if [[ $__only_dockers == 0 ]]; then
                                    promote_debian $artifact \
                                        $__codename \
                                        $__source_version \
                                        $__target_version \
                                        $__source_channel \
                                        $__target_channel \
                                        "" \
                                        $__verify \
                                        $__dry_run
                                fi

                                if [[ $__only_debians == 0 ]]; then
                                    promote_and_verify_docker $artifact $__source_version $__target_version $__codename "" $__publish_to_docker_io $__verify $__dry_run
                                fi
                        ;;
                        mina-rosetta)
                            for network in "${__networks_arr[@]}"; do
                                if [[ $__only_dockers == 0 ]]; then
                                        promote_debian $artifact \
                                            $__codename \
                                            $__source_version \
                                            $__target_version \
                                            $__source_channel \
                                            $__target_channel \
                                            $network \
                                            $__verify \
                                            $__dry_run
                                    
                                fi

                                if [[ $__only_debians == 0 ]]; then
                                        promote_and_verify_docker $artifact $__source_version $__target_version $__codename $network $__publish_to_docker_io $__verify $__dry_run 
                                fi
                            done
                        ;;
                        mina-daemon)
                            for network in "${__networks_arr[@]}"; do
                                if [[ $__only_dockers == 0 ]]; then
                                         promote_debian $artifact \
                                            $__codename \
                                            $__source_version \
                                            $__target_version \
                                            $__source_channel \
                                            $__target_channel \
                                            $network \
                                            $__verify \
                                            $__dry_run
                                    
                                fi

                                if [[ $__only_debians == 0 ]]; then
                                    promote_and_verify_docker $artifact $__source_version $__target_version $__codename $network $__publish_to_docker_io $__verify $__dry_run
                                fi
                            done
                        ;;
                        *)
                            echo "❌ Unknown artifact: $artifact"
                            exit 1
                        ;;
                    esac
        done
    done

    echo " ✅  Promoting done."
    echo ""
}


#==============
# verify
#==============
function verify_help(){
    echo Verify mina artifacts in target channel/docker registry to new location.
    echo ""
    echo "     $CLI_NAME verify [-options]"
    echo ""
    echo "Parameters:"
    echo ""
    printf "  %-25s %s\n" "-h  | --help" "show help";
    printf "  %-25s %s\n" "--artifacts" "[comma separated list] list of artifacts to publish. e.g mina-logproc,mina-archive,mina-rosetta";
    printf "  %-25s %s\n" "--networks" "[comma separated list] list of networks to publish. e.g devnet,mainnet"; 
    printf "  %-25s %s\n" "--version" "[path] target version of build to publish"; 
    printf "  %-25s %s\n" "--codenames" "[comma separated list] list of debian codenames to publish. e.g bullseye,focal"; 
    printf "  %-25s %s\n" "--channel" "[string] target debian channel"; 
    printf "  %-25s %s\n" "--docker-io" "[bool] publish to docker.io instead of gcr.io"; 
    printf "  %-25s %s\n" "--only-dockers" "[bool] publish only docker images"; 
    printf "  %-25s %s\n" "--only-debians" "[bool] publish only debian packages"; 
    echo ""
    echo "Example:"
    echo ""
    echo "  " $CLI_NAME verify --artifacts mina-logproc,mina-archive,mina-rosetta --networks devnet,mainnet --buildkite-build-id 123 --source-version 2.0.0-rc1-48efea4 --version 2.0.0-rc1-48efea5 --codenames bullseye,focal --channel nightly --docker-io --only-dockers
    echo ""
    echo " Above command will promote mina-logproc,mina-archive,mina-rosetta artifacts to debian repository and docker registry"
    echo ""
    echo ""
}

function verify(){
    if [[ ${#} == 0 ]]; then
        verify_help; exit 0;
    fi

    local __artifacts="$DEFAULT_ARTIFACTS"
    local __networks="$DEFAULT_NETWORKS"
    local __version
    local __codenames="$DEFAULT_CODENAMES"
    local __channel
    local __docker_io=0
    local __only_dockers=0
    local __only_debians=0


    while [ ${#} -gt 0 ]; do
        error_message="Error: a value is needed for '$1'";
        case $1 in
            -h | --help ) 
                promote_help; exit 0;
            ;;
            --artifacts )
                __artifacts=${2:?$error_message}
                shift 2;
            ;;
            --networks )
                __networks=${2:?$error_message}
                shift 2;
            ;;
            --version )
                __version=${2:?$error_message}
                shift 2;
            ;;
            --codenames )
                __codenames=${2:?$error_message}
                shift 2;
            ;;
            --channel )
                __channel=${2:?$error_message}
                shift 2;
            ;;
            --docker-io )
                __publish_to_docker_io=1
                shift 1;
            ;;
            --only-dockers )
                __only_dockers=1
                shift 1;
            ;;
            --only-debians )
                __only_debians=1
                shift 1;
            ;;
            * )
                echo -e "${RED} !! Unknown option: $1${CLEAR}\n";
                echo "";
                verify_help; exit 1;
            ;;
        esac
    done

    echo ""
    echo " ℹ️  Verifying mina artifacts with following parameters:"
    echo " - Verifying artifacts: $__artifacts"
    echo " - Networks: $__networks"
    echo " - Version: $__version"
    echo " - Promoting codenames: $__codenames"
    echo " - Channel: $__channel"
    echo " - Published to docker.io: $__docker_io"
    echo " - Only dockers: $__only_dockers"
    echo " - Only debians: $__only_debians"
    echo ""
    
    #check environment setup
    check_docker

    IFS=', '
    read -r -a __artifacts_arr <<< "$__artifacts"
    read -r -a __networks_arr <<< "$__networks"
    read -r -a __codenames_arr <<< "$__codenames"
    
    local __repo=$(get_repo $__docker_io)
    
    for artifact in "${__artifacts_arr[@]}"; do
        for __codename in "${__codenames_arr[@]}"; do
                    case $artifact in
                        mina-logproc)
                            
                            if [[ $__only_dockers == 0 ]]; then
                                    echo "     📋  Verifying: $artifact debian on $__channel channel with $__version version for $__codename codename"
  
                                    prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/debian/verify.sh \
                                        -p $artifact \
                                        --version $__version \
                                        -m $__codename \
                                        -c $__channel
                            fi

                            if [[ $__only_debians == 0 ]]; then
                                echo "    ℹ️  There is no mina-logproc docker image. skipping"
                            fi

                            
                        ;;
                        mina-archive)
                               if [[ $__only_dockers == 0 ]]; then
                                    echo "     📋  Verifying: $artifact debian on $__channel channel with $__version version for $__codename codename"
                                    
                                    prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/debian/verify.sh \
                                        -p $artifact \
                                        --version $__version \
                                        -m $__codename \
                                        -c $__channel

                                    echo ""
                                fi

                                if [[ $__only_debians == 0 ]]; then
                                
                                    echo "      📋  Verifying: $artifact docker on $(calculate_docker_tag "$__docker_io" $__artifact_full_name $__version $__codename "")"
                                
                                    prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/docker/verify.sh \
                                        -p "$artifact" \
                                        -v $__version \
                                        -c "$__codename" \
                                        -s "" \
                                        -r "$__repo" 

                                    echo ""
                                fi
                        ;;
                        mina-rosetta)
                            for network in "${__networks_arr[@]}"; do
                               local __artifact_full_name=$(get_artifact_with_suffix $artifact $network)
                               
                               if [[ $__only_dockers == 0 ]]; then
                                    echo "     📋  Verifying: $__artifact_full_name debian on $__channel channel with $__version version for $__codename codename"
                                    echo ""
                                    
                                    prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/debian/verify.sh \
                                        -p $__artifact_full_name \
                                        --version $__version \
                                        -m $__codename \
                                        -c $__channel

                                    echo ""
                                fi

                                if [[ $__only_debians == 0 ]]; then
                                    
                                    echo "      📋  Verifying: $artifact docker on $(calculate_docker_tag "$__docker_io" $__artifact_full_name $__version $__codename "")"
                                    echo ""
                                    
                                    prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/docker/verify.sh \
                                        -p "$artifact" \
                                        -v $__version \
                                        -c "$__codename" \
                                        -s "-$network" \
                                        -r "$__repo" 
                                    
                                    echo ""
                                fi
                            done
                        ;;
                        mina-daemon)
                            for network in "${__networks_arr[@]}"; do
                                local __artifact_full_name=$(get_artifact_with_suffix $artifact $network)
                                if [[ $__only_dockers == 0 ]]; then
                                echo "     📋  Verifying: $__artifact_full_name debian on $__channel channel with $__version version for $__codename codename"
                                echo ""
                                       prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/debian/verify.sh \
                                        -p $__artifact_full_name \
                                        --version $__version \
                                        -m $__codename \
                                        -c $__channel
                                    echo ""
                                fi

                                if [[ $__only_debians == 0 ]]; then
                                      echo "      📋  Verifying: $artifact docker on $(calculate_docker_tag "$__docker_io" $__artifact_full_name $__version $__codename "")"
                                echo ""
                                    prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/docker/verify.sh \
                                        -p "$artifact" \
                                        -v $__version \
                                        -c "$__codename" \
                                        -s "-$network" \
                                        -r "$__repo" 

                                      echo ""
                                fi
                            done
                        ;;
                        *)
                            echo "Unknown artifact: $artifact"
                            exit 1
                        ;;
                    esac
        done
    done

    echo " ✅  Verification done."
    echo ""
}



#==============
# verify
#==============
function fix_help(){
    echo Fixes repository manifests.
    echo ""
    echo "     $CLI_NAME fix [-options]"
    echo ""
    echo "Parameters:"
    echo ""
    printf "  %-25s %s\n" "-h  | --help" "show help";
    printf "  %-25s %s\n" "--codenames" "[comma separated list] list of debian codenames to publish. e.g bullseye,focal"; 
    printf "  %-25s %s\n" "--channel" "[string] target debian channel"; 
    echo ""
    echo "Example:"
    echo ""
    echo "  " $CLI_NAME fix --codenames bullseye,focal --channel nightly
    echo ""
    echo " Above command will verify that nightly channel in bullseye and focal codenames are correct eventually fixes manifests "
    echo ""
    echo ""
}

function fix(){
    if [[ ${#} == 0 ]]; then
        fix_help; exit 0;
    fi

    local __codenames="$DEFAULT_CODENAMES"
    local __channel
    local __bucket_arg="--bucket=packages.o1test.net"
    local __s3_region_arg="--s3-region=us-west-2"
    

    while [ ${#} -gt 0 ]; do
        error_message="Error: a value is needed for '$1'";
        case $1 in
            -h | --help ) 
                fix_help; exit 0;
            ;;
            --codenames )
                __codenames=${2:?$error_message}
                shift 2;
            ;;
            --channel )
                __channel=${2:?$error_message}
                shift 2;
            ;;
            * )
                echo -e "${RED} !! Unknown option: $1${CLEAR}\n";
                echo "";
                fix_help; exit 1;
            ;;
        esac
    done

    echo ""
    echo " ℹ️  Fixing debian repository with following parameters:"
    echo " - Codenames: $__codenames"
    echo " - Channel: $__channel"
    echo ""
    
    

    IFS=', '
    read -r -a __codenames_arr <<< "$__codenames"
        
        for __codename in "${__codenames_arr[@]}"; do
            deb-s3 verify \
            --fix-manifests \
            $__bucket_arg \
            $__s3_region_arg \
            --codename=${__codename} \
            --component=${__channel}
        done
    
    echo " ✅  Done."
    echo ""
}


function main(){
    if (( ${#} == 0 )); then
        main_help 0;
    fi

    case ${1} in
        help )
            main_help 0;
        ;;
        publish | promote | verify | fix )
            $1 "${@:2}";
        ;;
        * )
            echo -e "${RED} !! Unknown command: $1${CLEAR}\n";
            main_help 1;
        ;;
    esac
}

main "$@";