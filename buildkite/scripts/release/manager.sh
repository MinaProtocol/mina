#!/usr/bin/env bash

# Mina Protocol Release Manager Script
# 
# This script provides comprehensive release management functionality for the Mina Protocol project.
# It handles the complete lifecycle of build artifacts including publishing, promotion, verification,
# and maintenance of packages across different channels and platforms.
#
# Main capabilities:
# - PUBLISH: Publish build artifacts from cache to Debian repositories and Docker registries
# - PROMOTE: Promote artifacts from one channel/registry to another (e.g., unstable -> stable)
# - VERIFY: Verify that artifacts are correctly published in target channels/registries
# - FIX: Repair Debian repository manifests when needed
# - PERSIST: Archive artifacts to long-term storage backends
#
# Supported artifacts: mina-daemon, mina-archive, mina-rosetta, mina-logproc
# Supported networks: devnet, mainnet
# Supported platforms: Debian (bullseye, focal), Docker (GCR, Docker.io)
# Supported channels: unstable, alpha, beta, stable
# Supported backends: Google Cloud Storage (gs), Hetzner, local filesystem
#
# Usage examples:
#   ./manager.sh publish --buildkite-build-id 12345 --source-version 1.0.0 --target-version 1.0.1 --channel stable
#   ./manager.sh promote --source-version 1.0.0 --target-version 1.0.1 --source-channel alpha --target-channel beta
#   ./manager.sh verify --version 1.0.1 --channel stable --artifacts mina-daemon,mina-archive
#
# For detailed help on any command, use: ./manager.sh [command] --help

# bash strict mode
set -T # inherit DEBUG and RETURN trap for functions
set -C # prevent file overwrite by > &> <>
set -E # inherit -e
set -e # exit immediately on errors
set -u # exit on not assigned variables
set -o pipefail # exit on pipe failure
set -x

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
DEFAULT_ARCHITECTURES="amd64"
DEFAULT_PROFILE=devnet

DEBIAN_CACHE_FOLDER=${DEBIAN_CACHE_FOLDER:-~/.release/debian/cache}
DEFAULT_DOCKER_REPO="gcr.io/o1labs-192920"
GCR_REPO=$DEFAULT_DOCKER_REPO
DOCKER_IO_REPO="minaprotocol"
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

function check_aws() {
    check_app "aws"
}

function check_debs3() {
    check_app "deb-s3"
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
# shellcheck disable=SC1090
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

# Extract bucket name from potentially full S3 URL
# Input: s3.us-west-2.amazonaws.com/bucket-name or just bucket-name
# Output: bucket-name
function extract_bucket_name() {
    local __repo=$1
    # Strip s3 prefix patterns like "s3.us-west-2.amazonaws.com/" or "s3.amazonaws.com/"
    echo "$__repo" | sed -E 's|^s3(\.[^/]+)?\.amazonaws\.com/||'
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
    echo " progress - show progress of promoting/publishing release artifacts";
    echo " fix - fix debian package repository";
    echo " verify - verify artifacts in target channel (registry)";
    echo " version - show version";
    echo ""
    echo ""
    echo "Defaults: "
    echo " artifacts: $DEFAULT_ARTIFACTS"
    echo " networks: $DEFAULT_NETWORKS"
    echo " codenames: $DEFAULT_CODENAMES"
    echo " architectures: $DEFAULT_ARCHITECTURES"
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
    local __profile="${3:-""}"


    case $__profile in
        lightnet)
            __profile_part="-lightnet"
        ;;
        instrumented)
            __profile_part="-instrumented"
        ;;
        *)
            __profile_part=""
        ;;
    esac

    case $__artifact in
        mina-daemon)
            echo "-$__network$__profile_part"
        ;;
        mina-rosetta)
            echo "-$__network"
        ;;
        mina-archive)
            echo "-$__network"
        ;;
        *)
            echo ""
        ;;
    esac
}

function get_arch_suffix() {
    local __arch=$1

    case $__arch in
        amd64)
            echo ""
        ;;
        arm64)
            echo "-arm64"
        ;;
        *)
            echo ""
        ;;
    esac
}

function get_artifact_with_suffix() {
    local __artifact=$1
    local __network="${2:-""}"
    local __profile="${3:-""}"

    case $__artifact in
        mina-daemon)
            case $__profile in
                lightnet|instrumented)
                    echo "mina-$__network-$__profile"
                ;;
                *)
                    echo "mina-$__network"
                ;;
            esac
        ;;
        mina-rosetta)
            echo "mina-rosetta-$__network"
        ;;
        mina-archive)
            echo "mina-archive-$__network"
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
    local __arch=$5

    local __network_suffix
    __network_suffix=$(get_suffix $__artifact $__network)
    echo "$__artifact:$__target_version-$__codename$__network_suffix-$__arch"
}

function extract_version_from_deb() {
    local __deb_file=$1
    # Extract the version from a Debian package filename
    # Expected format: {package_name}_{version}_{arch}.deb
    # Uses split with between underscores and outputs only the version string
    basename "$__deb_file" .deb | cut -d'_' -f2
}



function calculate_docker_tag() {
    local __docker_repo=$1
    local __artifact=$2
    local __target_version=$3
    local __codename=$4
    local __network=$5
    local __profile=$6

    local __network_suffix
    __network_suffix=$(get_suffix $__artifact $__network "$__profile")

    local __arch_suffix
    __arch_suffix=$(get_arch_suffix $__arch)

    echo "$__docker_repo/$__artifact:$__target_version-$__codename$__network_suffix$__arch_suffix"
}

function storage_list() {
    local backend=$1
    local path=$2

    case $backend in
        local)
            ls $path
            ;;
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
        local)
            md5sum $path | awk '{print $1}'
            ;;
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
        local)
            cp $remote_path $local_path
            ;;
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

function storage_upload() {
    local backend=$1
    local local_path=$2
    local remote_path=$3

    case $backend in
        local)
            # Check if remote_path is a directory or a file by extension
            if [[ -d "$remote_path" || "${remote_path: -1}" == "/" || ! "$remote_path" =~ \.[^/]+$ ]]; then
                # remote_path is a directory (ends with / or is a dir or has no extension)
                mkdir -p "$remote_path"
            else
                # remote_path is a file (has an extension)
                mkdir -p "$(dirname "$remote_path")"
            fi
            cp $local_path "$remote_path"
            ;;
        gs)
            gsutil cp $local_path "$remote_path"
            ;;
        hetzner)
           rsync -avz -e "ssh -p 23 -i $HETZNER_KEY" $local_path "$HETZNER_USER@$HETZNER_HOST:$remote_path"
            ;;
        *)
            echo "❌ Unsupported backend: $backend"
            exit 1
            ;;
    esac
}

function storage_root() {
    local backend=$1

    case $backend in
        local)
            echo "/var/storagebox"
            ;;
        gs)
            echo "gs://buildkite_k8s/coda/shared"
            ;;
        hetzner)
            echo "/home/o1labs-generic/pvc-4d294645-6466-4260-b933-1b909ff9c3a1"
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
    local arch=$5
    local profile=$6

    local artifact_full_name
    artifact_full_name=$(get_artifact_with_suffix "$artifact" "$network" "$profile")
    local remote_path
    remote_path="$(storage_root "$backend")/$BUILDKITE_BUILD_ID/debians/$codename/${artifact_full_name}_*_${arch}.deb"

    local check
    check=$(storage_list "$backend" "$remote_path")

    if [[ -z "$check" ]]; then
        echo -e "❌ ${RED} !! No debian package found using $artifact_full_name. Are you sure ($BUILDKITE_BUILD_ID) buildkite build is correct? Exiting.${CLEAR}\n"
        exit 1
    fi

    local target_hash
    target_hash=$(storage_md5 "$backend" "$remote_path")

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
    local __profile=$7
    local __verify=$8
    local __dry_run=$9
    local __backend=${10}
    local __debian_repo=${11}
    local __arch=${12}
    local __force_upload_debians=${13:-0}
    local __debian_sign_key=${14}
    local __new_artifact_name=${15:-""}
    local __skip_cache_invalidation=${SKIP_CACHE_INVALIDATION:-0}

    get_cached_debian_or_download $__backend $__artifact $__codename "$__network" "$__arch" "$__profile"
    local __artifact_full_name
    __artifact_full_name=$(get_artifact_with_suffix $__artifact $__network $__profile)
    local __deb=$DEBIAN_CACHE_FOLDER/$__codename/"${__artifact_full_name}"

    if [[ $__debian_sign_key != "" ]]; then
        local __sign_arg=("--sign" "$__debian_sign_key")
        local __signed_arg="--signed"
    else
        local __sign_arg=()
        local __signed_arg=""
    fi

    if [[ -z ${__new_artifact_name+x} || -z ${__new_artifact_name} || ${__new_artifact_name} == "" ]]; then
        __new_artifact_name=$__artifact_full_name
    fi


    if [[ $__source_version != "$__target_version" ]]; then
        echo " 🗃️  Rebuilding $__artifact debian from $__source_version to $__target_version"
        prefix_cmd "$SUBCOMMAND_TAB" reversion --deb ${__deb} \
                --package ${__artifact_full_name} \
                --source-version ${__source_version} \
                --new-version ${__target_version} \
                --suite "unstable" \
                --new-suite ${__channel} \
                --new-name ${__new_artifact_name} \
                --arch ${__arch}
    fi

    echo " 🍥  Publishing $__artifact debian to $__channel channel with $__target_version version"
    echo "     📦  Target debian version: $(calculate_debian_version $__artifact $__target_version $__codename "$__network" "$__arch")"
    if [[ $__dry_run == 0 ]]; then
        # shellcheck disable=SC2068,SC2046
        prefix_cmd "$SUBCOMMAND_TAB" source $SCRIPTPATH/../../../scripts/debian/publish.sh \
            --names "$DEBIAN_CACHE_FOLDER/$__codename/${__new_artifact_name}_${__target_version}_${__arch}.deb" \
            --version $__target_version \
            --bucket $__debian_repo \
            $(if [[ $__force_upload_debians == 1 ]]; then echo "--force"; fi) \
            -c $__codename \
            $(if [[ $__skip_cache_invalidation == 1 ]]; then echo "--skip-cache-invalidation"; fi) \
            -r $__channel \
            --arch $__arch \
            ${__sign_arg[@]}

        if [[ $__verify == 1 ]]; then

            echo "     📋 Verifying: $__new_artifact_name debian to $__channel channel with $__target_version version"

            prefix_cmd "$SUBCOMMAND_TAB" source $SCRIPTPATH/../../../scripts/debian/verify.sh \
                -p $__new_artifact_name \
                --version $__target_version \
                -m $__codename \
                -r $__debian_repo \
                -a $__arch \
                -c $__channel ${__signed_arg}
        fi
    fi
}


function promote_and_verify_docker() {
    local __artifact=$1
    local __source_version=$2
    local __target_version=$3
    local __codename=$4
    local __network=$5
    local __profile=$6
    local __source_docker_repo=$7
    local __target_docker_repo=$8
    local __verify=$9
    local __arch=${10}
    local __dry_run=${11}

    local __suffix
    __suffix=$(get_suffix $__artifact $__network $__profile)

    local __artifact_full_source_version=$__source_version-$__codename${__suffix}
    local __artifact_full_target_version=$__target_version-$__codename${__suffix}

    echo " 🐋 Publishing $__artifact docker for '$__network' network and '$__codename' codename with '$__target_version' version and '$__arch' "
    echo "    📦 Target version: $(calculate_docker_tag $__target_docker_repo $__artifact $__target_version $__codename "$__network" "$__profile")"
    echo ""
    if [[ $__dry_run == 0 ]]; then
        prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/docker/promote.sh \
            -q \
            -n "$__artifact" \
            -v $__artifact_full_source_version \
            -t $__artifact_full_target_version \
            -a $__arch \
            --pull-registry $__source_docker_repo \
            --push-registry $__target_docker_repo

            echo ""

        if [[ $__verify == 1 ]]; then

            echo "    📋 Verifying: $__artifact docker for '$__network' network and '$__codename' codename with '$__target_version' version"
            echo ""

            prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/docker/verify.sh \
                -p "$__artifact" \
                -v "$__target_version" \
                -c "$__codename" \
                -s "$__suffix" \
                -r "$__target_docker_repo" \
                -a "$__arch"

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
    local __debian_repo=${10}
    local __arch=${11}
    local __debian_sign_key=${12}
    local __skip_cache_invalidation=${SKIP_CACHE_INVALIDATION:-0}

    if [[ $__debian_sign_key != "" ]]; then
        local __sign_arg=("--sign" "$__debian_sign_key")
        local __signed_arg="--signed"
    else
        local __sign_arg=()
        local __signed_arg=""
    fi

    echo " 🍥 Promoting $__artifact debian from $__source_channel to $__target_channel, from $__source_version to $__target_version for $__arch architecture"
    echo "    📦 Target debian version: $(calculate_debian_version $__artifact $__target_version $__codename "$__network" $__arch)"

    local __artifact_full_name
    __artifact_full_name=$(get_artifact_with_suffix $__artifact $__network)

    local __new_artifact_name=$__artifact_full_name

    local __deb=$DEBIAN_CACHE_FOLDER/$__codename/"${__artifact_full_name}"

    if [[ $__dry_run == 0 ]]; then
        echo "    🗃️  Promoting $__artifact debian from $__codename/$__source_version to $__codename/$__target_version"
        local __debian_bucket
        __debian_bucket=$(extract_bucket_name "$__debian_repo")



        # shellcheck disable=SC2068,SC2046
        prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/debian/reversion.sh \
                --deb ${__artifact_full_name} \
                --version ${__source_version} \
                --new-version ${__target_version} \
                --suite ${__source_channel} \
                --repo ${__debian_bucket} \
                --arch ${__arch} \
                --codename ${__codename} \
                --new-suite ${__target_channel} \
                --new-name ${__new_artifact_name} \
                $(if [[ $__skip_cache_invalidation == 1 ]]; then echo "--skip-cache-invalidation"; fi) \
                --codename ${__codename}


        if [[ $__verify == 1 ]]; then
            echo "     📋 Verifying: $__artifact debian to $__target_channel channel with $__target_version version"

            prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/debian/verify.sh \
                -p $__new_artifact_name \
                --version $__target_version \
                -m $__codename \
                -r $__debian_repo \
                -c $__target_channel ${__signed_arg}
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
    printf "  %-25s %s\n" "--archs" "[list string] target architectures list. Default: $DEFAULT_ARCHITECTURES";
    printf "  %-25s %s\n" "--artifacts" "[comma separated list] list of artifacts to publish. e.g mina-logproc,mina-archive,mina-rosetta";
    printf "  %-25s %s\n" "--networks" "[comma separated list] list of networks to publish. e.g devnet,mainnet";
    printf "  %-25s %s\n" "--buildkite-build-id" "[string] buildkite build id of release build to publish";
    printf "  %-25s %s\n" "--source-version" "[path] source version of build to publish";
    printf "  %-25s %s\n" "--target-version" "[path] target version of build to publish";
    printf "  %-25s %s\n" "--codenames" "[comma separated list] list of debian codenames to publish. e.g bullseye,focal";
    printf "  %-25s %s\n" "--channel" "[string] target debian channel";
    printf "  %-25s %s\n" "--source-docker-repo" "[string] source docker repo. Default: $DEFAULT_DOCKER_REPO";
    printf "  %-25s %s\n" "--target-docker-repo" "[string] target docker repo. Default: $DEFAULT_DOCKER_REPO";
    printf "  %-25s %s\n" "--only-dockers" "[bool] publish only docker images";
    printf "  %-25s %s\n" "--only-debians" "[bool] publish only debian packages";
    printf "  %-25s %s\n" "--verify" "[bool] verify packages are published correctly. WARINING: it requires docker engine to be installed";
    printf "  %-25s %s\n" "--dry-run" "[bool] doesn't publish anything. Just print what would be published";
    printf "  %-25s %s\n" "--backend" "[string] backend to use for storage. e.g gs,hetzner. default: gs";
    printf "  %-25s %s\n" "--debian-repo" "[string] debian repository to publish to. default: $DEBIAN_REPO";
    printf "  %-25s %s\n" "--debian-sign-key" "[string] debian signing key to use. default: lack of presence = no signing";
    printf "  %-25s %s\n" "--strip-network-from-archive" "[bool] strip network from archive name. E.g mina-archive-devnet -> mina-archive";
    printf "  %-25s %s\n" "--force-upload-debians" "[bool] force upload debian packages even if they exist already in the repository";
    printf "  %-25s %s\n" "--profile" "[string] build profile to publish. e.g lightnet, mainnet. default: $DEFAULT_PROFILE";
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
    local __source_docker_repo=$DEFAULT_DOCKER_REPO
    local __target_docker_repo=$DEFAULT_DOCKER_REPO
    local __only_dockers=0
    local __only_debians=0
    local __verify=0
    local __dry_run=0
    local __backend="gs"
    local __debian_repo=$DEBIAN_REPO
    local __debian_sign_key=""
    local __strip_network_from_archive=0
    local __archs=${DEFAULT_ARCHITECTURES}
    local __force_upload_debians=0
    local __profile=$DEFAULT_PROFILE

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
            --source-docker-repo )
                __source_docker_repo=${2:?$error_message}
                shift 2;
            ;;
            --target-docker-repo )
                __target_docker_repo=${2:?$error_message}
                shift 2;
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
            --debian-repo )
                __debian_repo=${2:?$error_message}
                shift 2;
            ;;
            --debian-sign-key )
                __debian_sign_key=${2:?$error_message}
                shift 2;
            ;;
            --strip-network-from-archive )
                __strip_network_from_archive=1
                shift 1;
            ;;
            --archs )
                __archs=${2:?$error_message}
                shift 2;
            ;;
            --force-upload-debians )
                __force_upload_debians=1
                shift 1;
            ;;
            --profile )
                __profile=${2:?$error_message}
                shift 2;
            ;;
            --skip-cache-invalidation )
                export SKIP_CACHE_INVALIDATION=1
                shift 1;
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
    echo " - Docker repository: $__source_docker_repo -> $__target_docker_repo"
    echo " - Only dockers: $__only_dockers"
    echo " - Only debians: $__only_debians"
    echo " - Verify: $__verify"
    echo " - Dry run: $__dry_run"
    echo " - Backend: $__backend"
    echo " - Debian repo: $__debian_repo"
    echo " - Debian sign key: $__debian_sign_key"
    echo " - Strip network from archive: $__strip_network_from_archive"
    echo " - Architectures: $__archs"
    echo " - Profile: $__profile"
    echo " - Force upload debians: $__force_upload_debians"
    echo " - Skip cache invalidation: ${SKIP_CACHE_INVALIDATION:-0}"
    echo ""

    if [[ $__backend != "gs" && $__backend != "hetzner" && $__backend != "local" ]]; then
        echo -e "❌ ${RED} !! Backend (--backend) can be only gs, hetzner or local ${CLEAR}\n";
        publish_help; exit 1;
    fi

    if [[ $__backend == "gs" ]]; then
        #check environment setup
        check_gsutil
    elif [[ $__backend == "local" ]]; then
        #check root folder is writable
        if [[ ! -r $(storage_root "$__backend") ]]; then
            echo -e "❌ ${RED} !! Local backend root folder $(storage_root "$__backend") is not readable. Please check it exists and is accessible ${CLEAR}\n";
            exit 1
        fi
    fi

    # Only require aws and deb-s3 if we are dealing with debians
    if [[ $__only_dockers == 0 ]]; then
        check_aws
        check_debs3
    fi

    if [[ $__verify == 1 ]]; then
        check_docker
    fi

    export BUILDKITE_BUILD_ID=$__buildkite_build_id

    IFS=', '
    read -r -a __artifacts_arr <<< "$__artifacts"
    read -r -a __networks_arr <<< "$__networks"
    read -r -a __codenames_arr <<< "$__codenames"
    read -r -a __archs_arr <<< "$__archs"

    for __arch in "${__archs_arr[@]}"; do
        echo " 🖥️  Publishing for architecture: $__arch"
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
                                            "" \
                                            $__verify \
                                            $__dry_run \
                                            $__backend \
                                            $__debian_repo \
                                            "$__arch" \
                                            "$__force_upload_debians" \
                                            "$__debian_sign_key"

                                fi

                                if [[ $__only_debians == 0 ]]; then
                                    echo "ℹ️  There is no $artifact docker image to publish. skipping"
                                fi

                            ;;
                            mina-archive)
                                for network in "${__networks_arr[@]}"; do

                                    if [[ $__strip_network_from_archive == 1 ]]; then
                                        new_name="mina-archive"
                                    else
                                        new_name=""
                                    fi

                                    if [[ $__only_dockers == 0 ]]; then
                                            publish_debian $artifact \
                                                $__codename \
                                                $__source_version \
                                                $__target_version \
                                                $__channel \
                                                $network \
                                                $__profile  \
                                                $__verify \
                                                $__dry_run \
                                                $__backend \
                                                $__debian_repo \
                                                "$__arch" \
                                                "$__force_upload_debians" \
                                                "$__debian_sign_key" \
                                                "$new_name"
                                    fi

                                    if [[ $__only_debians == 0 ]]; then
                                        promote_and_verify_docker $artifact $__source_version $__target_version $__codename $network $__profile $__source_docker_repo $__target_docker_repo $__verify $__arch $__dry_run
                                    fi
                                done
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
                                                $__profile \
                                                $__verify \
                                                $__dry_run \
                                                $__backend \
                                                $__debian_repo \
                                                "$__arch" \
                                                "$__force_upload_debians" \
                                                "$__debian_sign_key"
                                    fi

                                    if [[ $__only_debians == 0 ]]; then
                                        promote_and_verify_docker $artifact $__source_version $__target_version $__codename $network $__profile $__source_docker_repo $__target_docker_repo $__verify $__arch $__dry_run
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
                                                $__profile \
                                                $__verify \
                                                $__dry_run \
                                                $__backend \
                                                $__debian_repo \
                                                "$__arch" \
                                                "$__force_upload_debians" \
                                                "$__debian_sign_key"
                                    fi

                                    if [[ $__only_debians == 0 ]]; then
                                        promote_and_verify_docker $artifact $__source_version $__target_version $__codename $network $__profile $__source_docker_repo $__target_docker_repo $__verify $__arch $__dry_run
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
    printf "  %-25s %s\n" "--arch" "[string] target architecture. Default: $DEFAULT_ARCHITECTURES";
    printf "  %-25s %s\n" "--profile" "[string] build profile to publish. e.g lightnet, mainnet. default: $DEFAULT_PROFILE";
    printf "  %-25s %s\n" "--artifacts" "[comma separated list] list of artifacts to publish. e.g mina-logproc,mina-archive,mina-rosetta";
    printf "  %-25s %s\n" "--networks" "[comma separated list] list of networks to publish. e.g devnet,mainnet";
    printf "  %-25s %s\n" "--source-version" "[path] source version of build to publish";
    printf "  %-25s %s\n" "--target-version" "[path] target version of build to publish";
    printf "  %-25s %s\n" "--codenames" "[comma separated list] list of debian codenames to publish. e.g bullseye,focal";
    printf "  %-25s %s\n" "--source-channel" "[string] source debian channel";
    printf "  %-25s %s\n" "--target-channel" "[string] target debian channel";
    printf "  %-25s %s\n" "--source-docker-repo" "[string] source docker repo. Default: $DEFAULT_DOCKER_REPO";
    printf "  %-25s %s\n" "--target-docker-repo" "[string] target docker repo. Default: $DEFAULT_DOCKER_REPO";
    printf "  %-25s %s\n" "--only-dockers" "[bool] publish only docker images";
    printf "  %-25s %s\n" "--only-debians" "[bool] publish only debian packages";
    printf "  %-25s %s\n" "--verify" "[bool] verify packages are published correctly. WARINING: it requires docker engine to be installed";
    printf "  %-25s %s\n" "--dry-run" "[bool] doesn't publish anything. Just print what would be published";
    printf "  %-25s %s\n" "--debian-repo" "[string] debian repository to publish to. default: $DEBIAN_REPO";
    printf "  %-25s %s\n" "--debian-sign-key" "[string] debian signing key to use. default: lack of presence = no signing";
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
    local __backend="local"
    local __networks="$DEFAULT_NETWORKS"
    local __source_version
    local __target_version
    local __codenames="$DEFAULT_CODENAMES"
    local __strip_network_from_archive=0
    local __source_channel
    local __target_channel
    local __source_docker_repo="$DEFAULT_DOCKER_REPO"
    local __target_docker_repo="$DEFAULT_DOCKER_REPO"
    local __only_dockers=0
    local __only_debians=0
    local __verify=0
    local __dry_run=0
    local __debian_repo=$DEBIAN_REPO
    local __debian_sign_key=""
    local __arch="$DEFAULT_ARCHITECTURES"
    local __profile="$DEFAULT_PROFILE"
    local __force_upload_debians=0

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
            --backend )
                __backend=${2:?$error_message}
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
            --source-docker-repo )
                __source_docker_repo=${2:?$error_message}
                shift 2;
            ;;
            --target-docker-repo )
                __target_docker_repo=${2:?$error_message}
                shift 2;
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
            --strip-network-from-archive )
                __strip_network_from_archive=1
                shift 1;
            ;;
            --dry-run )
                __dry_run=1
                shift 1;
            ;;
            --debian-repo )
                __debian_repo=${2:?$error_message}
                shift 2;
            ;;
            --debian-sign-key )
                __debian_sign_key=${2:?$error_message}
                shift 2;
            ;;
            --arch )
                __arch=${2:?$error_message}
                shift 2;
            ;;
            --force-upload-debians )
                __force_upload_debians=1
                shift 1;
            ;;
            --profile )
                __profile=${2:?$error_message}
                shift 2;
            ;;
            --skip-cache-invalidation )
                export SKIP_CACHE_INVALIDATION=1
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
    echo " - Source Docker repo: $__source_docker_repo"
    echo " - Target Docker repo: $__target_docker_repo"
    echo " - Only dockers: $__only_dockers"
    echo " - Only debians: $__only_debians"
    echo " - Verify: $__verify"
    echo " - Dry run: $__dry_run"
    echo " - Backend: $__backend"
    echo " - Debian repo: $__debian_repo"
    echo " - Debian sign key: $__debian_sign_key"
    echo " - Strip network from archive: $__strip_network_from_archive"
    echo " - Architectures: $__arch"
    echo " - Profile: $__profile"
    echo " - Force upload debians: $__force_upload_debians"
    echo " - Skip cache invalidation: ${SKIP_CACHE_INVALIDATION:-0}"
    echo ""



    if [[ $__backend != "gs" && $__backend != "hetzner" && $__backend != "local" ]]; then
        echo -e "❌ ${RED} !! Backend (--backend) can be only gs, hetzner or local ${CLEAR}\n";
        promote_help; exit 1;
    fi

    if [[ $__backend == "gs" ]]; then
        #check environment setup
        check_gsutil
    elif [[ $__backend == "local" ]]; then
        #check root folder is writable
        if [[ ! -r $(storage_root "$__backend") ]]; then
            echo -e "❌ ${RED} !! Local backend root folder $(storage_root "$__backend") is not readable. Please check it exists and is accessible ${CLEAR}\n";
            exit 1
        fi
    fi

    # Only require deb-s3 and aws if we are dealing with debians
    if [[ $__only_dockers == 0 ]]; then
        check_aws
        check_debs3
    fi

    if [[ $__verify == 1 ]]; then
        check_docker
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
                                    $__dry_run \
                                    $__debian_repo \
                                    "$__arch" \
                                    $__debian_sign_key
                            fi

                            if [[ $__only_debians == 0 ]]; then
                                echo "   ℹ️  There is no mina-logproc docker image to promote. skipping"
                            fi


                        ;;
                        mina-archive)
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
                                        $__dry_run \
                                        $__debian_repo \
                                        "$__arch" \
                                        $__debian_sign_key
                                fi

                                if [[ $__only_debians == 0 ]]; then
                                    promote_and_verify_docker $artifact $__source_version $__target_version $__codename $network $__profile $__source_docker_repo $__target_docker_repo $__verify $__arch $__dry_run
                                fi
                            done
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
                                            $__dry_run \
                                            $__debian_repo \
                                            "$__arch" \
                                            $__debian_sign_key
                                fi

                                if [[ $__only_debians == 0 ]]; then
                                        promote_and_verify_docker $artifact $__source_version $__target_version $__codename $network $__profile $__source_docker_repo $__target_docker_repo $__verify $__arch $__dry_run
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
                                            $__dry_run \
                                            $__debian_repo \
                                            "$__arch" \
                                            "$__debian_sign_key"
                                fi

                                if [[ $__only_debians == 0 ]]; then
                                    promote_and_verify_docker $artifact $__source_version $__target_version $__codename $network $__profile $__source_docker_repo $__target_docker_repo $__verify $__arch $__dry_run
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
    printf "  %-25s %s\n" "--arch" "[string] target architecture. Default: $DEFAULT_ARCHITECTURES";
    printf "  %-25s %s\n" "--artifacts" "[comma separated list] list of artifacts to publish. e.g mina-logproc,mina-archive,mina-rosetta";
    printf "  %-25s %s\n" "--networks" "[comma separated list] list of networks to publish. e.g devnet,mainnet";
    printf "  %-25s %s\n" "--version" "[path] target version of build to publish";
    printf "  %-25s %s\n" "--codenames" "[comma separated list] list of debian codenames to publish. e.g bullseye,focal";
    printf "  %-25s %s\n" "--channel" "[string] target debian channel";
    printf "  %-25s %s\n" "--debian-repo" "[string] debian repository. default: $DEBIAN_REPO";
    printf "  %-25s %s\n" "--docker-repo" "[string] docker repo. Default: $DEFAULT_DOCKER_REPO";
    printf "  %-25s %s\n" "--only-dockers" "[bool] publish only docker images";
    printf "  %-25s %s\n" "--only-debians" "[bool] publish only debian packages";
    printf "  %-25s %s\n" "--arch" "[string] architecture (amd64 or arm64)";
    printf "  %-25s %s\n" "--profile" "[string] build profile to publish. e.g lightnet, mainnet. default: $DEFAULT_PROFILE";
    printf "  %-25s %s\n" "--build-flag" "[string] build flag which was used while building mina. e.g instrumented";
    echo ""
    echo "Example:"
    echo ""
    echo "  " $CLI_NAME verify --artifacts mina-logproc,mina-archive,mina-rosetta --networks devnet,mainnet  --version 2.0.0-rc1-48efea5 --codenames bullseye,focal --channel nightly --docker-io --only-debian
    echo ""
    echo " Above command will promote mina-logproc,mina-archive,mina-rosetta artifacts to debian repository"
    echo ""
    echo ""
}

function combine_docker_suffixes() {
    local network=$1
    local __profile=$2
    local __build_flag=$3

    if [[ "$__profile" == "lightnet" ]]; then
        local __docker_suffix=$__profile
    else
        local __docker_suffix=""
    fi

    if [[ -n "$__build_flag" ]]; then
        if [[ -n "$__docker_suffix" ]]; then
            echo "-${network}-${__docker_suffix}-${__build_flag}"
        else
            echo "-${network}-${__build_flag}"
        fi
    else
        if [[ -n "$__docker_suffix" ]]; then
            echo "-${network}-${__docker_suffix}"
        else
            echo "-${network}"
        fi
    fi
}

function verify(){
    if [[ ${#} == 0 ]]; then
        verify_help; exit 0;
    fi

    local __artifacts="$DEFAULT_ARTIFACTS"
    local __networks="$DEFAULT_NETWORKS"
    local __version
    local __codenames="$DEFAULT_CODENAMES"
    local __channel="unstable"
    local __only_dockers=0
    local __only_debians=0
    local __debian_repo=$DEBIAN_REPO
    local __debian_repo_signed=0
    local __archs="$DEFAULT_ARCHITECTURES"
    local __profile=$DEFAULT_PROFILE
    local __docker_repo="$DEFAULT_DOCKER_REPO"
    local __build_flag=""

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
            --debian-repo )
                __debian_repo=${2:?$error_message}
                shift 2;
            ;;
            --signed-debian-repo )
                __signed_debian_repo=1
                shift 1;
            ;;
            --docker-repo )
                __docker_repo=${2:?$error_message}
                shift 2;
            ;;
            --only-dockers )
                __only_dockers=1
                shift 1;
            ;;
            --only-debians )
                __only_debians=1
                shift 1;
            ;;
            --archs )
                __archs=${2:?$error_message}
                shift 2;
            ;;
            --profile )
                __profile=${2:?$error_message}
                shift 2;
            ;;
            --build-flag )
                __build_flag=${2:?$error_message}
                shift 2;
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
    echo " - Docker repo: $__docker_repo"
    echo " - Debian repo: $__debian_repo"
    echo " - Debian repos is signed: $__debian_repo_signed"
    echo " - Channel: $__channel"
    echo " - Only debians: $__only_debians"
    echo " - Only dockers: $__only_dockers"
    echo " - Architectures: $__archs"
    echo " - Profile: $__profile"
    echo " - Build flag: $__build_flag"
    echo ""

    # Only require deb-s3 and aws if we are dealing with debians
    if [[ $__only_dockers == 0 ]]; then
        check_aws
        check_debs3
    fi

    #check environment setup
    if [[ $__only_debians == 0 ]]; then
        check_docker
    fi

    IFS=', '
    read -r -a __artifacts_arr <<< "$__artifacts"
    read -r -a __networks_arr <<< "$__networks"
    read -r -a __codenames_arr <<< "$__codenames"
    read -r -a __archs_arr <<< "$__archs"

    for __arch in "${__archs_arr[@]}"; do
        echo " 🖥️  Verifying for architecture: $__arch"
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
                                            -r $__debian_repo \
                                            -c $__channel \
                                            -a $__arch \
                                            ${__signed_debian_repo:+--signed}
                                fi

                                if [[ $__only_debians == 0 ]]; then
                                    echo "    ℹ️  There is no mina-logproc docker image. skipping"
                                fi

                            ;;
                            mina-archive)
                                for network in "${__networks_arr[@]}"; do
                                local __artifact_full_name
                                        __artifact_full_name=$(get_artifact_with_suffix $artifact $network)

                                local __docker_suffix_combined
                                __docker_suffix_combined=$(combine_docker_suffixes "$network" "$__profile" "$__build_flag")

                                if [[ $__only_dockers == 0 ]]; then

                                        echo "     📋  Verifying: $__artifact_full_name debian on $__channel channel with $__version version for $__codename codename"
                                        echo ""

                                        prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/debian/verify.sh \
                                            -p $__artifact_full_name \
                                            --version $__version \
                                            -m $__codename \
                                            -r $__debian_repo \
                                            -c $__channel \
                                            -a "$__arch" \
                                            ${__signed_debian_repo:+--signed}

                                        echo ""
                                    fi

                                    if [[ $__only_debians == 0 ]]; then

                                        echo "      📋  Verifying: $artifact docker on $(calculate_docker_tag "$__docker_repo" $artifact $__version $__codename "$network" "$__arch")"
                                        echo ""

                                        prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/docker/verify.sh \
                                            -p "$artifact" \
                                            -v $__version \
                                            -c "$__codename" \
                                            -s "$__docker_suffix_combined" \
                                            -r "$__docker_repo"  \
                                            -a "$__arch"

                                        echo ""
                                    fi
                                done
                            ;;
                            mina-rosetta)
                                for network in "${__networks_arr[@]}"; do
                                local __artifact_full_name
                                __artifact_full_name=$(get_artifact_with_suffix $artifact $network)

                                local __docker_suffix_combined
                                __docker_suffix_combined=$(combine_docker_suffixes "$network" "$__profile" "$__build_flag")

                                if [[ $__only_dockers == 0 ]]; then

                                        echo "     📋  Verifying: $__artifact_full_name debian on $__channel channel with $__version version for $__codename codename"
                                        echo ""

                                        prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/debian/verify.sh \
                                            -p $__artifact_full_name \
                                            --version $__version \
                                            -m $__codename \
                                            -r $__debian_repo \
                                            -c $__channel \
                                            -a "$__arch" \
                                            ${__signed_debian_repo:+--signed}

                                        echo ""
                                    fi

                                    if [[ $__only_debians == 0 ]]; then

                                        echo "      📋  Verifying: $artifact docker on $(calculate_docker_tag "$__docker_repo" $__artifact_full_name $__version $__codename $network "$__arch" )"
                                        echo ""

                                        prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/docker/verify.sh \
                                            -p "$artifact" \
                                            -v $__version \
                                            -c "$__codename" \
                                            -s "$__docker_suffix_combined" \
                                            -r "$__docker_repo" \
                                            -a "$__arch"

                                        echo ""
                                    fi
                                done
                            ;;

                            mina-daemon)
                                for network in "${__networks_arr[@]}"; do
                                    local __artifact_full_name
                                    __artifact_full_name=$(get_artifact_with_suffix $artifact $network $__profile)

                                    local __docker_suffix_combined
                                    __docker_suffix_combined=$(combine_docker_suffixes "$network" "$__profile" "$__build_flag")


                                if [[ $__only_dockers == 0 ]]; then
                                    echo "     📋  Verifying: $__artifact_full_name debian on $__channel channel with $__version version for $__codename codename"
                                    echo ""
                                        prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/debian/verify.sh \
                                            -p $__artifact_full_name \
                                            --version $__version \
                                            -m $__codename \
                                            -r $__debian_repo \
                                            -c $__channel \
                                            -a "$__arch" \
                                            ${__signed_debian_repo:+--signed}
                                        echo ""
                                    fi

                                    if [[ $__only_debians == 0 ]]; then
                                        echo "      📋  Verifying: $artifact docker on $(calculate_docker_tag "$__docker_repo" $__artifact_full_name $__version $__codename "$network" "$__arch" )"
                                    echo ""
                                        prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/docker/verify.sh \
                                            -p "$artifact" \
                                            -v $__version \
                                            -c "$__codename" \
                                            -s "$__docker_suffix_combined" \
                                            -r "$__docker_repo" \
                                            -a "$__arch"

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

#==============
# persist
#==============
function persist_help(){
    echo Persist artifact from cache.
    echo ""
    echo "     $CLI_NAME persist [-options]"
    echo ""
    echo "Parameters:"
    echo ""
    printf "  %-25s %s\n" "-h  | --help" "show help";
    printf "  %-25s %s\n" "--arch" "[string] target architecture. Default: $DEFAULT_ARCHITECTURES";
    printf "  %-25s %s\n" "--backend" "[string] backend to persist artifacts. e.g gs,hetzner";
    printf "  %-25s %s\n" "--artifacts" "[comma separated list] list of artifacts to persist. e.g mina-logproc,mina-archive,mina-rosetta";
    printf "  %-25s %s\n" "--buildkite-build-id" "[string] buildkite build id to persist artifacts";
    printf "  %-25s %s\n" "--target" "[string] target location to persist artifacts";
    echo ""
    echo "Example:"
    echo ""
    echo "  " $CLI_NAME persist --backend gs --artifacts mina-logproc,mina-archive,mina-rosetta --buildkite-build-id 123 --target /debians_legacy
    echo ""
    echo " Above command will persist mina-logproc,mina-archive,mina-rosetta artifacts to {backend root}/debians_legacy"
    echo ""
    echo ""
}

function persist(){
    if [[ ${#} == 0 ]]; then
        persist_help; exit 0;
    fi

    local __backend="hetzner"
    local __artifacts="$DEFAULT_ARTIFACTS"
    local __buildkite_build_id
    local __target
    local __codename
    local __new_version
    local __suite="unstable"
    local __arch="$DEFAULT_ARCHITECTURES"

    while [ ${#} -gt 0 ]; do
        error_message="Error: a value is needed for '$1'";
        case $1 in
            -h | --help )
                persist_help; exit 0;
            ;;
            --backend )
                __backend=${2:?$error_message}
                shift 2;
            ;;
            --artifacts )
                __artifacts=${2:?$error_message}
                shift 2;
            ;;
            --codename )
                __codename=${2:?$error_message}
                shift 2;
            ;;
            --buildkite-build-id )
                __buildkite_build_id=${2:?$error_message}
                shift 2;
            ;;
            --new-version )
                __new_version=${2:?$error_message}
                shift 2;
            ;;
            --target )
                __target=${2:?$error_message}
                shift 2;
            ;;
            --suite )
                __suite=${2:?$error_message}
                shift 2;
            ;;
            --arch )
                __arch=${2:?$error_message}
                shift 2;
            ;;
            * )
                echo -e "${RED} !! Unknown option: $1${CLEAR}\n";
                echo "";
                persist_help; exit 1;
            ;;
        esac
    done

    if [[ -z ${__buildkite_build_id+x} ]]; then
        echo -e "❌ ${RED} !! Buildkite build id (--buildkite-build-id) is required${CLEAR}\n";
        persist_help; exit 1;
    fi

    if [[ -z ${__target+x} ]]; then
        echo -e "❌ ${RED} !! Target (--target) is required${CLEAR}\n";
        persist_help; exit 1;
    fi

    if [[ -z ${__codename+x} ]]; then
        echo -e "❌ ${RED} !! Codename (--codename) is required${CLEAR}\n";
        persist_help; exit 1;
    fi

    if [[ -z ${__artifacts+x} ]]; then
        echo -e "❌ ${RED} !! Artifacts (--artifacts) is required${CLEAR}\n";
        persist_help; exit 1;
    fi

    echo ""
    echo " ℹ️  Persisting mina artifacts with following parameters:"
    echo " - Backend: $__backend"
    echo " - Artifacts: $__artifacts"
    echo " - Buildkite build id: $__buildkite_build_id"
    echo " - Codename: $__codename"
    echo " - Suite: $__suite"
    echo " - Architecture: $__arch"
    echo " - Target: $__target"
    if [[ -n ${__new_version+x} ]]; then
        echo " - New version: $__new_version"
    fi

    IFS=', '
    read -r -a __artifacts_arr <<< "$__artifacts"

    tmp_dir=$(mktemp -d)
    echo " - Using temporary directory: $tmp_dir"
    echo ""

    for __artifact in "${__artifacts_arr[@]}"; do
        storage_download "$__backend" "$(storage_root "$__backend")/$__buildkite_build_id/debians/$__codename/${__artifact}_*_${__arch}.deb" "$tmp_dir"

        if [[ -n ${__new_version+x} ]]; then
            local __source_version
            echo " - Extracting source version from $tmp_dir/${__artifact}_*_${__arch}.deb"
            __source_version=$(extract_version_from_deb "$(ls $tmp_dir/${__artifact}_*_${__arch}.deb | head -1)")

            local __deb
            __deb=$(ls $tmp_dir/${__artifact}_*_${__arch}.deb | head -1)

            local __artifact_full_name
            __artifact_full_name=$(get_artifact_with_suffix $__artifact)

            echo " 🗃️  Rebuilding $__artifact debian from $__source_version to $__new_version"
            prefix_cmd "$SUBCOMMAND_TAB" reversion --deb "$tmp_dir/${__artifact_full_name}" \
                --package ${__artifact_full_name} \
                --source-version ${__source_version} \
                --new-version ${__new_version} \
                --suite "unstable" \
                --new-suite ${__suite} \
                --new-name ${__artifact_full_name} \
                --arch ${__arch}
        fi

      
        storage_upload "$__backend" "$tmp_dir/${__artifact}_*" "$(storage_root "$__backend")/$__target/debians/$__codename/"
    done

    echo " ✅  Done."
    echo ""
}


#==============
# pull
# 
# PUlls artifacts from cache.
#==============
function pull_help(){
    echo Pulls artifact from cache.
    echo ""
    echo "     $CLI_NAME pull [-options]"
    echo ""
    echo "Parameters:"
    echo ""
    printf "  %-25s %s\n" "-h  | --help" "show help";
    printf "  %-25s %s\n" "--backend" "[string] backend to persist artifacts. e.g gs,hetzner";
    printf "  %-25s %s\n" "--artifacts" "[comma separated list] list of artifacts to persist. e.g mina-logproc,mina-archive,mina-rosetta";
    printf "  %-25s %s\n" "--build_id" "[string] buildkite build id to persist artifacts";
    printf "  %-25s %s\n" "--target" "[string] target local location to persist artifacts";
    printf "  %-25s %s\n" "--codenames" "[string list] target location to persist artifacts";
    printf "  %-25s %s\n" "--networks" "[stringlist ] target location to persist artifacts";
    echo ""
    echo "Example:"
    echo ""
    echo "  " $CLI_NAME pull --backend gs --artifacts mina-logproc,mina-archive,mina-rosetta --build_id 123 --target /debians_legacy
    echo ""
    echo " Above command will pull mina-logproc,mina-archive,mina-rosetta artifacts to {backend root}/debians_legacy"
    echo ""
    echo ""
}

function pull(){
    if [[ ${#} == 0 ]]; then
        pull_help; exit 0;
    fi

    local __backend="hetzner"
    local __artifacts="$DEFAULT_ARTIFACTS"
    local __buildkite_build_id
    local __target="."
    local __codenames="$DEFAULT_CODENAMES"
    local __networks="$DEFAULT_NETWORKS"
    local __from_special_folder

    while [ ${#} -gt 0 ]; do
        error_message="Error: a value is needed for '$1'";
        case $1 in
            -h | --help )
                pull_help; exit 0;
            ;;
            --backend )
                __backend=${2:?$error_message}
                shift 2;
            ;;
            --artifacts )
                __artifacts=${2:?$error_message}
                shift 2;
            ;;
            --codenames )
                __codenames=${2:?$error_message}
                shift 2;
            ;;
            --buildkite-build-id )
                __buildkite_build_id=${2:?$error_message}
                shift 2;
            ;;
            --from-special-folder )
                __from_special_folder=${2:?$error_message}
                shift 2;
            ;;
            --target )
                __target=${2:?$error_message}
                shift 2;
            ;;
            --networks )
                __networks=${2:?$error_message}
                shift 2;
            ;;
            --archs )
                __archs=${2:?$error_message}
                shift 2;
            ;;
            * )
                echo -e "${RED} !! Unknown option: $1${CLEAR}\n";
                echo "";
                persist_help; exit 1;
            ;;
        esac
    done

    if [[ -z ${__buildkite_build_id+x} && -z ${__from_special_folder+x} ]]; then
        echo -e "❌ ${RED} !! Buildkite build id (--buildkite-build-id) is required${CLEAR}\n";
        pull_help; exit 1;
    fi


    echo ""
    echo " ℹ️  Pulling mina artifacts with following parameters:"
    echo " - Backend: $__backend"
    echo " - Artifacts: $__artifacts"
    echo " - Target: $__target"
    echo " - Codenames: $__codenames"
    echo " - Networks: $__networks"
    echo " - Architectures: $__archs"

    if [[ -n ${__from_special_folder+x} ]]; then
        echo " - From special folder: $__from_special_folder"
    fi
    if [[ -n ${__buildkite_build_id+x} ]]; then
        echo " - Buildkite build id: $__buildkite_build_id"
    fi

    IFS=', '
    read -r -a __artifacts_arr <<< "$__artifacts"
    read -r -a __codenames_arr <<< "$__codenames"
    read -r -a __networks_arr <<< "$__networks"
    read -r -a __archs_arr <<< "$__archs"

    for __arch in "${__archs_arr[@]}"; do
        for __artifact in "${__artifacts_arr[@]}"; do
            for __codename in "${__codenames_arr[@]}"; do
                for network in "${__networks_arr[@]}"; do
                    echo "  📥  Pulling $__artifact for $__codename codename and $network network"
                    local __artifact_full_name
                    local __source_path
                    __artifact_full_name=$(get_artifact_with_suffix $__artifact $network)

                    if [[ -n ${__from_special_folder+x} ]]; then
                        __source_path="$(storage_root "$__backend")/$__from_special_folder/${__artifact_full_name}_*_${__arch}.deb"
                    else
                        __source_path="$(storage_root "$__backend")/$__buildkite_build_id/debians/$__codename/${__artifact_full_name}_*_${__arch}.deb"
                    fi

                    storage_download "$__backend" "$__source_path" "$__target"
                done
            done
        done
    done
    echo " ✅  Done."
    echo ""
}

#==============
# progress
#==============
function progress_help(){
    echo Show progress of promoting/publishing release artifacts.
    echo ""
    echo "     $CLI_NAME progress [-options]"
    echo ""
    echo "Parameters:"
    echo ""
    printf "  %-25s %s\n" "-h  | --help" "show help";
    printf "  %-25s %s\n" "--version" "[string] target version to check (required)";
    printf "  %-25s %s\n" "--release" "[string] target release (alpha, beta, stable) (required)";
    printf "  %-25s %s\n" "--artifacts" "[comma separated list] list of artifacts to check. Default: $DEFAULT_ARTIFACTS";
    printf "  %-25s %s\n" "--codenames" "[comma separated list] list of debian codenames to check. Default: bullseye,focal,jammy,noble,bookworm";
    printf "  %-25s %s\n" "--only-debians" "[bool] check only debian packages";
    printf "  %-25s %s\n" "--only-dockers" "[bool] check only docker images";
    printf "  %-25s %s\n" "--skip-mina-public" "[bool] skip checking packages.minaprotocol.com repositories";
    echo ""
    echo "Example:"
    echo ""
    echo "  $CLI_NAME progress --version 3.0.0-beta1 --release beta"
    echo ""
    echo " Above command will show progress of publishing 3.0.0-beta1 to beta release"
    echo ""
    echo ""
}

function get_network_for_channel() {
    local __channel=$1
    case $__channel in
        alpha)
            echo "devnet"
            ;;
        beta|stable)
            echo "mainnet"
            ;;
        *)
            echo "mainnet"
            ;;
    esac
}

function get_debian_buckets_for_channel() {
    local __channel=$1
    case $__channel in
        alpha|beta)
            echo "unstable.apt.packages.minaprotocol.com packages.o1test.net"
            ;;
        stable)
            echo "stable.apt.packages.minaprotocol.com packages.o1test.net"
            ;;
        *)
            echo "packages.o1test.net"
            ;;
    esac
}

function check_debian_package() {
    local __bucket=$1
    local __component=$2
    local __codename=$3
    local __package_name=$4
    local __version=$5
    local __arch=$6

    # Use deb-s3 list to check if package exists
    local output
    output=$(deb-s3 list --bucket="$__bucket" --s3-region=us-west-2 --component "$__component" --codename "$__codename" --arch "$__arch" 2>/dev/null || echo "")

    # Check if the package with the version exists
    if echo "$output" | grep -q "${__package_name}_${__version}_${__arch}.deb"; then
        return 0
    else
        return 1
    fi
}

function check_docker_image() {
    local __repo=$1
    local __artifact=$2
    local __tag=$3

    # Try to pull the manifest without downloading the image
    if docker manifest inspect "$__repo/$__artifact:$__tag" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

function progress(){
    if [[ ${#} == 0 ]]; then
        progress_help; exit 0;
    fi

    local __version
    local __release
    local __artifacts="$DEFAULT_ARTIFACTS"
    local __codenames="bullseye,focal,jammy,noble,bookworm"
    local __only_debians=0
    local __only_dockers=0
    local __skip_mina_public=0

    while [ ${#} -gt 0 ]; do
        error_message="❌ Error: a value is needed for '$1'";
        case $1 in
            -h | --help )
                progress_help; exit 0;
            ;;
            --version )
                __version=${2:?$error_message}
                shift 2;
            ;;
            --release )
                __release=${2:?$error_message}
                shift 2;
            ;;
            --artifacts )
                __artifacts=${2:?$error_message}
                shift 2;
            ;;
            --codenames )
                __codenames=${2:?$error_message}
                shift 2;
            ;;
            --only-debians )
                __only_debians=1
                shift 1;
            ;;
            --only-dockers )
                __only_dockers=1
                shift 1;
            ;;
            --skip-mina-public )
                __skip_mina_public=1
                shift 1;
            ;;
            * )
                echo -e "❌ ${RED} !! Unknown option: $1${CLEAR}\n";
                echo "";
                progress_help; exit 1;
            ;;
        esac
    done

    if [[ -z ${__version+x} ]]; then
        echo -e "❌ ${RED} !! Version (--version) is required${CLEAR}\n";
        progress_help; exit 1;
    fi

    if [[ -z ${__release+x} ]]; then
        echo -e "❌ ${RED} !! Release (--release) is required${CLEAR}\n";
        progress_help; exit 1;
    fi

    local __network
    __network=$(get_network_for_channel "$__release")

    local __debian_buckets
    __debian_buckets=$(get_debian_buckets_for_channel "$__release")

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎯  Release Progress Report"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " 📦  Version: $__version"
    echo " 🏷️   Release: $__release"
    echo " 🌐  Network: $__network"
    echo " 📚  Artifacts: $__artifacts"
    echo " 🖥️   Codenames: $__codenames"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    IFS=', '
    read -r -a __artifacts_arr <<< "$__artifacts"
    read -r -a __codenames_arr <<< "$__codenames"
    read -r -a __debian_buckets_arr <<< "$__debian_buckets"

    local total_debian_checks=0
    local passed_debian_checks=0
    local total_docker_checks=0
    local passed_docker_checks=0

    # Debian Packages Check
    if [[ $__only_dockers == 0 ]]; then
        echo "📦 DEBIAN PACKAGES"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        for bucket in "${__debian_buckets_arr[@]}"; do
            # Skip mina public repos if requested
            if [[ $__skip_mina_public == 1 ]] && [[ "$bucket" == *"packages.minaprotocol.com"* ]]; then
                continue
            fi

            echo "  🗄️  Repository: $bucket"
            echo "  ─────────────────────────────────────────────────────────────"
            echo ""

            for codename in "${__codenames_arr[@]}"; do
                # Determine architectures based on codename
                local architectures="amd64"
                if [[ "$codename" == "bookworm" || "$codename" == "noble" ]]; then
                    architectures="amd64 arm64"
                fi

                for arch in $architectures; do
                    echo "    📋  Checking $codename/$arch..."
                    
                    # Fetch all packages for this codename/release/arch combination once
                    local available_packages
                    available_packages=$(deb-s3 list --bucket="$bucket" --s3-region=us-west-2 --component "$__release" --codename "$codename" --arch "$arch" 2>/dev/null || echo "")

                    for artifact in "${__artifacts_arr[@]}"; do
                        # Handle artifacts that need network suffix
                        case $artifact in
                            mina-logproc)
                                local package_name="$artifact"
                                ((total_debian_checks=total_debian_checks+1))

                                if echo "$available_packages" | awk '{print $1, $2, $3}' | grep -q "^${package_name} ${__version} ${arch}$"; then
                                    echo "      ✅  $package_name"
                                    ((passed_debian_checks=passed_debian_checks+1))
                                else
                                    echo "      ❌  $package_name - MISSING"
                                fi
                                ;;
                            mina-archive)
                                # For mina-archive, check both with and without network suffix
                                local package_with_suffix
                                package_with_suffix=$(get_artifact_with_suffix "$artifact" "$__network")
                                local package_without_suffix="$artifact"

                                # Check with network suffix
                                ((total_debian_checks=total_debian_checks+1))
                                if echo "$available_packages" | awk '{print $1, $2, $3}' | grep -q "^${package_with_suffix} ${__version} ${arch}$"; then
                                    echo "      ✅  $package_with_suffix"
                                    ((passed_debian_checks=passed_debian_checks+1))
                                else
                                    echo "      ❌  $package_with_suffix - MISSING"
                                fi

                                # Check without network suffix (only for non-devnet)
                                if [[ "$__network" != "devnet" ]]; then
                                    ((total_debian_checks=total_debian_checks+1))
                                    if echo "$available_packages" | awk '{print $1, $2, $3}' | grep -q "^${package_without_suffix} ${__version} ${arch}$"; then
                                        echo "      ✅  $package_without_suffix"
                                        ((passed_debian_checks=passed_debian_checks+1))
                                    else
                                        echo "      ❌  $package_without_suffix - MISSING"
                                    fi
                                fi
                                ;;
                            mina-daemon|mina-rosetta)
                                local package_with_suffix
                                package_with_suffix=$(get_artifact_with_suffix "$artifact" "$__network")

                                ((total_debian_checks=total_debian_checks+1))
                                if echo "$available_packages" | awk '{print $1, $2, $3}' | grep -q "^${package_with_suffix} ${__version} ${arch}$"; then
                                    echo "      ✅  $package_with_suffix"
                                    ((passed_debian_checks=passed_debian_checks+1))
                                else
                                    echo "      ❌  $package_with_suffix - MISSING"
                                fi
                                ;;
                        esac
                    done
                done
            done
            echo ""
        done
    fi

    # Docker Images Check
    if [[ $__only_debians == 0 ]]; then
        echo "🐋 DOCKER IMAGES"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        # Select registry based on release
        local docker_repo
        if [[ "$__release" == "stable" ]]; then
            docker_repo="$DOCKER_IO_REPO"
        else
            docker_repo="$GCR_REPO"
        fi

        echo "  🐳  Registry: $docker_repo"
        echo "  ─────────────────────────────────────────────────────────────"
        echo ""

        for artifact in "${__artifacts_arr[@]}"; do
            # Skip mina-logproc as it has no docker image
            if [[ "$artifact" == "mina-logproc" ]]; then
                continue
            fi

            for codename in "${__codenames_arr[@]}"; do
                # Determine architectures based on codename
                local architectures="amd64"
                if [[ "$codename" == "bookworm" || "$codename" == "noble" ]]; then
                    architectures="amd64 arm64"
                fi

                for arch in $architectures; do
                    local network_suffix
                    network_suffix=$(get_suffix "$artifact" "$__network")

                    local arch_suffix
                    arch_suffix=$(get_arch_suffix "$arch")

                    local tag="$__version-$codename$network_suffix$arch_suffix"

                    ((total_docker_checks=total_docker_checks+1))
                    if check_docker_image "$docker_repo" "$artifact" "$tag"; then
                        echo "    ✅  $artifact:$tag"
                        ((passed_docker_checks=passed_docker_checks+1))
                    else
                        echo "    ❌  $artifact:$tag - MISSING"
                    fi
                done
            done
        done
        echo ""
    fi

    # Summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 SUMMARY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [[ $__only_dockers == 0 ]]; then
        local debian_progress=$((passed_debian_checks * 100 / (total_debian_checks > 0 ? total_debian_checks : 1)))
        echo "  📦  Debian Packages: $passed_debian_checks / $total_debian_checks ($debian_progress%)"

        # Progress bar for debian
        local bar_length=50
        local filled=$((passed_debian_checks * bar_length / (total_debian_checks > 0 ? total_debian_checks : 1)))
        printf "      ["
        for ((i=0; i<bar_length; i++)); do
            if ((i < filled)); then
                printf "█"
            else
                printf "░"
            fi
        done
        printf "]\n"
        echo ""
    fi

    if [[ $__only_debians == 0 ]]; then
        local docker_progress=$((passed_docker_checks * 100 / (total_docker_checks > 0 ? total_docker_checks : 1)))
        echo "  🐋  Docker Images: $passed_docker_checks / $total_docker_checks ($docker_progress%)"

        # Progress bar for docker
        local bar_length=50
        local filled=$((passed_docker_checks * bar_length / (total_docker_checks > 0 ? total_docker_checks : 1)))
        printf "      ["
        for ((i=0; i<bar_length; i++)); do
            if ((i < filled)); then
                printf "█"
            else
                printf "░"
            fi
        done
        printf "]\n"
        echo ""
    fi

    local total_checks=$((total_debian_checks + total_docker_checks))
    local passed_checks=$((passed_debian_checks + passed_docker_checks))

    if [[ $total_checks -gt 0 ]]; then
        local overall_progress=$((passed_checks * 100 / total_checks))
        echo "  🎯  Overall Progress: $passed_checks / $total_checks ($overall_progress%)"

        # Overall progress bar
        local bar_length=50
        local filled=$((passed_checks * bar_length / total_checks))
        printf "      ["
        for ((i=0; i<bar_length; i++)); do
            if ((i < filled)); then
                printf "█"
            else
                printf "░"
            fi
        done
        printf "]\n"
        echo ""
    fi

    if [[ $passed_checks -eq $total_checks ]]; then
        echo "  🎉  Congratulations! All artifacts are published!"
    else
        echo "  ⚠️   There are missing artifacts. Please review the list above."
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
        publish | promote | verify | fix | persist | pull | progress)
            $1 "${@:2}";
        ;;
        * )
            echo -e "${RED} !! Unknown command: $1${CLEAR}\n";
            main_help 1;
        ;;
    esac
}

main "$@";
