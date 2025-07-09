#!/usr/bin/env bash

# Publish command implementation

function publish_help(){
    echo Publish mina build artifacts from google cloud cache to debian repository and docker registry.
    echo ""
    echo "     $CLI_NAME publish [-options]"
    echo ""
    echo "Parameters:"
    echo ""
    printf "  %-25s %s\n" "-h  | --help" "show help";
    printf "  %-25s %s\n" "--artifacts" \
           "[comma separated list] list of artifacts to publish. e.g mina-logproc,mina-archive,mina-rosetta";
    printf "  %-25s %s\n" "--networks" \
           "[comma separated list] list of networks to publish. e.g devnet,mainnet";
    printf "  %-25s %s\n" "--buildkite-build-id" \
           "[string] buildkite build id of release build to publish";
    printf "  %-25s %s\n" "--source-version" "[path] source version of build to publish";
    printf "  %-25s %s\n" "--target-version" "[path] target version of build to publish";
    printf "  %-25s %s\n" "--codenames" \
           "[comma separated list] list of debian codenames to publish. e.g bullseye,focal";
    printf "  %-25s %s\n" "--channel" "[string] target debian channel";
    printf "  %-25s %s\n" "--publish-to-docker-io" \
           "[bool] publish to docker.io instead of gcr.io";
    printf "  %-25s %s\n" "--only-dockers" "[bool] publish only docker images";
    printf "  %-25s %s\n" "--only-debians" "[bool] publish only debian packages";
    printf "  %-25s %s\n" "--verify" \
           "[bool] verify packages are published correctly. WARINING: it requires docker engine to be installed";
    printf "  %-25s %s\n" "--dry-run" \
           "[bool] doesn't publish anything. Just print what would be published";
    printf "  %-25s %s\n" "--backend" \
           "[string] backend to use for storage. e.g gs,hetzner. default: gs";
    printf "  %-25s %s\n" "--debian-repo" \
           "[string] debian repository to publish to. default: $DEBIAN_REPO";
    printf "  %-25s %s\n" "--debian-sign-key" \
           "[string] debian signing key to use. default: lack of presence = no signing";
    echo ""
    echo "Example:"
    echo ""
    echo "  $CLI_NAME publish --artifacts mina-logproc,mina-archive,mina-rosetta \\"
    echo "      --networks devnet,mainnet --buildkite-build-id 123 \\"
    echo "      --source-version 2.0.0-rc1-48efea4 \\"
    echo "      --target-version 2.0.0-rc1-48efea5 \\"
    echo "      --codenames bullseye,focal --channel alpha \\"
    echo "      --publish-to-docker-io --only-dockers --verify --dry-run"
    echo ""
    echo " Above command will publish mina-logproc,mina-archive,mina-rosetta"
    echo " artifacts to debian repository and docker registry"
    echo ""
}

function publish_artifact() {
    local artifact=$1
    local network=$2
    local codename=$3
    local config_array=("$@")
    shift 3
    local additional_config=("$@")

    local source_version=${additional_config[0]}
    local target_version=${additional_config[1]}
    local channel=${additional_config[2]}
    local verify=${additional_config[3]}
    local dry_run=${additional_config[4]}
    local backend=${additional_config[5]}
    local debian_repo=${additional_config[6]}
    local debian_sign_key=${additional_config[7]}
    local publish_to_docker_io=${additional_config[8]}
    local only_dockers=${additional_config[9]}
    local only_debians=${additional_config[10]}

    # Publish debian package
    if [[ $only_dockers == 0 ]]; then
        publish_debian_package \
            "$artifact" \
            "$codename" \
            "$source_version" \
            "$target_version" \
            "$channel" \
            "$network" \
            "$verify" \
            "$dry_run" \
            "$backend" \
            "$debian_repo" \
            "$debian_sign_key"
    fi

    # Publish docker image
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

function publish(){
    if [[ ${#} == 0 ]]; then
        publish_help; exit 0;
    fi

    local artifacts="$DEFAULT_ARTIFACTS"
    local networks="$DEFAULT_NETWORKS"
    local buildkite_build_id
    local source_version
    local target_version
    local codenames="$DEFAULT_CODENAMES"
    local channel
    local publish_to_docker_io=0
    local only_dockers=0
    local only_debians=0
    local verify=0
    local dry_run=0
    local backend="gs"
    local debian_repo=$DEBIAN_REPO
    local debian_sign_key=""

    while [ ${#} -gt 0 ]; do
        error_message="❌ Error: a value is needed for '$1'";
        case $1 in
            -h | --help )
                publish_help; exit 0;
            ;;
            --artifacts )
                artifacts=${2:?$error_message}
                shift 2;
            ;;
            --networks )
                networks=${2:?$error_message}
                shift 2;
            ;;
            --buildkite-build-id )
                buildkite_build_id=${2:?$error_message}
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
            --channel )
                channel=${2:?$error_message}
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
            --backend )
                backend=${2:?$error_message}
                shift 2;
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
                echo -e "❌ ${RED} !! Unknown option: $1${CLEAR}\n";
                echo "";
                publish_help; exit 1;
            ;;
        esac
    done

    # Validate required parameters
    validate_required_param "Target version (--target-version)" "$target_version" "publish_help"
    validate_required_param "Source version (--source-version)" "$source_version" "publish_help"
    validate_required_param "Buildkite build id (--buildkite-build-id)" "$buildkite_build_id" "publish_help"
    validate_required_param "Channel (--channel)" "$channel" "publish_help"

    # Validate parameter values
    validate_artifacts "$artifacts"
    validate_networks "$networks"
    validate_codenames "$codenames"
    validate_channel "$channel"
    validate_backend "$backend" || { publish_help; exit 1; }
    validate_environment "$backend" "$verify"

    echo ""
    echo " ℹ️  Publishing mina artifacts with following parameters:"
    echo " - Publishing artifacts: $artifacts"
    echo " - Publishing networks: $networks"
    echo " - Buildkite build id: $buildkite_build_id"
    echo " - Source version: $source_version"
    echo " - Target version: $target_version"
    echo " - Publishing codenames: $codenames"
    echo " - Target channel: $channel"
    echo " - Publish to docker.io: $publish_to_docker_io"
    echo " - Only dockers: $only_dockers"
    echo " - Only debians: $only_debians"
    echo " - Verify: $verify"
    echo " - Dry run: $dry_run"
    echo " - Backend: $backend"
    echo " - Debian repo: $debian_repo"
    echo " - Debian sign key: $debian_sign_key"
    echo ""

    export BUILDKITE_BUILD_ID=$buildkite_build_id

    for_each_artifact "publish_artifact" "$artifacts" "$networks" \
        "$codenames" "$source_version" "$target_version" "$channel" \
        "$verify" "$dry_run" "$backend" "$debian_repo" "$debian_sign_key" \
        "$publish_to_docker_io" "$only_dockers" "$only_debians"

    echo " ✅  Publishing done."
    echo ""
}
