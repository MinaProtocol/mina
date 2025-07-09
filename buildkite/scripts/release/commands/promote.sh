#!/usr/bin/env bash

# Promote command implementation

function promote_help(){
    echo Promote mina artifacts from channel/docker registry to new location.
    echo ""
    echo "     $CLI_NAME promote [-options]"
    echo ""
    echo "Parameters:"
    echo ""
    printf "  %-25s %s\n" "-h  | --help" "show help";
    printf "  %-25s %s\n" "--artifacts" \
           "[comma separated list] list of artifacts to publish. e.g " \
           "mina-logproc,mina-archive,mina-rosetta";
    printf "  %-25s %s\n" "--networks" \
           "[comma separated list] list of networks to publish. e.g " \
           "devnet,mainnet";
    printf "  %-25s %s\n" "--source-version" \
           "[path] source version of build to publish";
    printf "  %-25s %s\n" "--target-version" \
           "[path] target version of build to publish";
    printf "  %-25s %s\n" "--codenames" \
           "[comma separated list] list of debian codenames to publish. " \
           "e.g bullseye,focal";
    printf "  %-25s %s\n" "--source-channel" "[string] source debian channel";
    printf "  %-25s %s\n" "--target-channel" "[string] target debian channel";
    printf "  %-25s %s\n" "--publish-to-docker-io" \
           "[bool] publish to docker.io instead of gcr.io";
    printf "  %-25s %s\n" "--only-dockers" "[bool] publish only docker images";
    printf "  %-25s %s\n" "--only-debians" \
           "[bool] publish only debian packages";
    printf "  %-25s %s\n" "--verify" \
           "[bool] verify packages are published correctly. WARINING: " \
           "it requires docker engine to be installed";
    printf "  %-25s %s\n" "--dry-run" \
           "[bool] doesn't publish anything. Just print what would be " \
           "published";
    printf "  %-25s %s\n" "--debian-repo" \
           "[string] debian repository to publish to. default: $DEBIAN_REPO";
    printf "  %-25s %s\n" "--debian-sign-key" \
           "[string] debian signing key to use. default: lack of " \
           "presence = no signing";
    echo ""
    echo "Example:"
    echo ""
    echo "  $CLI_NAME promote --artifacts \\"
    echo "      mina-logproc,mina-archive,mina-rosetta \\"
    echo "      --networks devnet,mainnet \\"
    echo "      --source-version 2.0.0-rc1-48efea4 \\"
    echo "      --target-version 2.0.0-rc1-48efea5 \\"
    echo "      --codenames bullseye,focal \\"
    echo "      --source-channel unstable --target-channel nightly \\"
    echo "      --publish-to-docker-io --only-dockers --verify --dry-run"
    echo ""
    echo " Above command will promote mina-logproc,mina-archive,mina-rosetta"
    echo " artifacts to debian repository and docker registry"
    echo ""
}

function promote_artifact() {
    local artifact=$1
    local network=$2
    local codename=$3
    shift 3
    local additional_config=("$@")

    local source_version=${additional_config[0]}
    local target_version=${additional_config[1]}
    local source_channel=${additional_config[2]}
    local target_channel=${additional_config[3]}
    local verify=${additional_config[4]}
    local dry_run=${additional_config[5]}
    local debian_repo=${additional_config[6]}
    local debian_sign_key=${additional_config[7]}
    local publish_to_docker_io=${additional_config[8]}
    local only_dockers=${additional_config[9]}
    local only_debians=${additional_config[10]}

    # Promote debian package
    if [[ $only_dockers == 0 ]]; then
        promote_debian_package \
            "$artifact" \
            "$codename" \
            "$source_version" \
            "$target_version" \
            "$source_channel" \
            "$target_channel" \
            "$network" \
            "$verify" \
            "$dry_run" \
            "$debian_repo" \
            "$debian_sign_key"
    fi

    # Promote docker image
    if should_process_docker "$artifact" "$only_debians"; then
        promote_and_verify_docker \
            "$artifact" \
            "$source_version" \
            "$target_version" \
            "$codename" \
            "$network" \
            "$publish_to_docker_io" \
            "$verify" \
            "$dry_run"
    fi
}

function promote(){
    if [[ ${#} == 0 ]]; then
        promote_help; exit 0;
    fi

    local artifacts="$DEFAULT_ARTIFACTS"
    local networks="$DEFAULT_NETWORKS"
    local source_version
    local target_version
    local codenames="$DEFAULT_CODENAMES"
    local source_channel
    local target_channel
    local publish_to_docker_io=0
    local only_dockers=0
    local only_debians=0
    local verify=0
    local dry_run=0
    local debian_repo=$DEBIAN_REPO
    local debian_sign_key=""

    while [ ${#} -gt 0 ]; do
        error_message="❌ Error: a value is needed for '$1'";
        case $1 in
            -h | --help )
                promote_help; exit 0;
            ;;
            --artifacts )
                artifacts=${2:?$error_message}
                shift 2;
            ;;
            --networks )
                networks=${2:?$error_message}
                shift 2;
            ;;
            --source-version )
                source_version=${2:?$error_message}
                shift 2;
            ;;
            --target-version )
                target_version=${2:?$error_message}
                shift 2;
            ;;
            --codenames )
                codenames=${2:?$error_message}
                shift 2;
            ;;
            --source-channel )
                source_channel=${2:?$error_message}
                shift 2;
            ;;
            --target-channel )
                target_channel=${2:?$error_message}
                shift 2;
            ;;
            --publish-to-docker-io )
                publish_to_docker_io=1
                shift 1;
            ;;
            --only-dockers )
                only_dockers=1
                shift 1;
            ;;
            --only-debians )
                only_debians=1
                shift 1;
            ;;
            --verify )
                verify=1
                shift 1;
            ;;
            --dry-run )
                dry_run=1
                shift 1;
            ;;
            --debian-repo )
                debian_repo=${2:?$error_message}
                shift 2;
            ;;
            --debian-sign-key )
                debian_sign_key=${2:?$error_message}
                shift 2;
            ;;
            * )
                echo -e "${RED} !! Unknown option: $1${CLEAR}\n";
                echo "";
                promote_help; exit 1;
            ;;
        esac
    done

    # Validate required parameters
    validate_required_param "Target version (--target-version)" \
        "$target_version" "promote_help"
    validate_required_param "Source version (--source-version)" \
        "$source_version" "promote_help"

    if [[ $only_dockers == 0 ]]; then
        validate_required_param "Source channel (--source-channel)" \
            "$source_channel" "promote_help"
        validate_required_param "Target channel (--target-channel)" \
            "$target_channel" "promote_help"
    fi

    # Validate parameter values
    validate_artifacts "$artifacts"
    validate_networks "$networks"
    validate_codenames "$codenames"
    [[ -n "$source_channel" ]] && validate_channel "$source_channel"
    [[ -n "$target_channel" ]] && validate_channel "$target_channel"
    validate_environment "" "$verify"

    echo ""
    echo " ℹ️   Promotion mina artifacts with following parameters:"
    echo " - Promoting artifacts: $artifacts"
    echo " - Networks: $networks"
    echo " - Promoting codenames: $codenames"
    if [[ $only_dockers == 1 ]]; then
        if [[ -n ${source_channel+x} ]]; then
            echo " - Source channel: $source_channel"
        fi
        if [[ -n ${target_channel+x} ]]; then
            echo " - Target channel: $target_channel"
        fi
        if [[ -n ${source_version+x} ]]; then
            echo " - Source version: $source_version"
        fi
        if [[ -n ${target_version+x} ]]; then
            echo " - Target version: $target_version"
        fi
    fi
    echo " - Publish to docker.io: $publish_to_docker_io"
    echo " - Only dockers: $only_dockers"
    echo " - Only debians: $only_debians"
    echo " - Verify: $verify"
    echo " - Dry run: $dry_run"
    echo ""

    if [[ $source_version == "$target_version" ]]; then
        echo " ⚠️  Warning: Source version and target version are the same.
    Script will do promotion but it won't have an effect at the end unless
    you are publishing dockers from gcr.io to docker.io ..."
        echo ""
    fi

    for_each_artifact "promote_artifact" "$artifacts" "$networks" \
        "$codenames" "$source_version" "$target_version" "$source_channel" \
        "$target_channel" "$verify" "$dry_run" "$debian_repo" \
        "$debian_sign_key" "$publish_to_docker_io" "$only_dockers" \
        "$only_debians"

    echo " ✅  Promoting done."
    echo ""
}
