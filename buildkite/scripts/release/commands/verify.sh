#!/usr/bin/env bash

# Verify command implementation

function verify_help(){
    echo Verify mina artifacts in target channel/docker registry to new
    echo location.
    echo ""
    echo "     $CLI_NAME verify [-options]"
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
    printf "  %-25s %s\n" "--version" \
           "[path] target version of build to publish";
    printf "  %-25s %s\n" "--codenames" \
           "[comma separated list] list of debian codenames to publish. " \
           "e.g bullseye,focal";
    printf "  %-25s %s\n" "--channel" "[string] target debian channel";
    printf "  %-25s %s\n" "--debian-repo" \
           "[string] debian repository. default: $DEBIAN_REPO";
    printf "  %-25s %s\n" "--docker-io" \
           "[bool] publish to docker.io instead of gcr.io";
    printf "  %-25s %s\n" "--only-dockers" "[bool] publish only docker images";
    printf "  %-25s %s\n" "--only-debians" \
           "[bool] publish only debian packages";
    echo ""
    echo "Example:"
    echo ""
    echo "   $CLI_NAME verify \\"
    echo "      --artifacts mina-logproc,mina-archive,mina-rosetta \\"
    echo "      --networks devnet,mainnet \\"
    echo "      --version 2.0.0-rc1-48efea5 \\"
    echo "      --codenames bullseye,focal \\"
    echo "      --channel nightly \\"
    echo "      --docker-io \\"
    echo "      --only-debian"
    echo ""
    echo " Above command will promote mina-logproc,mina-archive,mina-rosetta"
    echo " artifacts to debian repository"
    echo ""
}

function verify_artifact() {
    local artifact=$1
    local network=$2
    local codename=$3
    shift 3
    local additional_config=("$@")

    local version=${additional_config[0]}
    local channel=${additional_config[1]}
    local debian_repo=${additional_config[2]}
    local signed_debian_repo=${additional_config[3]}
    local docker_io=${additional_config[4]}
    local docker_suffix=${additional_config[5]}
    local only_dockers=${additional_config[6]}
    local only_debians=${additional_config[7]}

    # Verify debian package
    if [[ $only_dockers == 0 ]]; then
        verify_debian_package \
            "$artifact" \
            "$network" \
            "$codename" \
            "$version" \
            "$channel" \
            "$debian_repo" \
            "$signed_debian_repo" \
            "$docker_suffix"
    fi

    # Verify docker image
    if should_process_docker "$artifact" "$only_debians"; then
        verify_docker_image \
            "$artifact" \
            "$network" \
            "$codename" \
            "$version" \
            "$docker_io" \
            "$docker_suffix"
    fi
}

function verify(){
    if [[ ${#} == 0 ]]; then
        verify_help; exit 0;
    fi

    local artifacts="$DEFAULT_ARTIFACTS"
    local networks="$DEFAULT_NETWORKS"
    local version
    local codenames="$DEFAULT_CODENAMES"
    local channel="unstable"
    local docker_io=0
    local only_dockers=0
    local only_debians=0
    local debian_repo=$DEBIAN_REPO
    local signed_debian_repo=0
    local docker_suffix=""

    while [ ${#} -gt 0 ]; do
        error_message="Error: a value is needed for '$1'";
        case $1 in
            -h | --help )
                verify_help; exit 0;
            ;;
            --artifacts )
                artifacts=${2:?$error_message}
                shift 2;
            ;;
            --networks )
                networks=${2:?$error_message}
                shift 2;
            ;;
            --version )
                version=${2:?$error_message}
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
            --debian-repo )
                debian_repo=${2:?$error_message}
                shift 2;
            ;;
            --signed-debian-repo )
                signed_debian_repo=1
                shift 1;
            ;;
            --docker-io )
                docker_io=1
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
            --docker-suffix )
                docker_suffix=${2:?$error_message}
                shift 2;
            ;;
            * )
                echo -e "${RED} !! Unknown option: $1${CLEAR}\n";
                echo "";
                verify_help; exit 1;
            ;;
        esac
    done

    # Validate parameter values
    validate_artifacts "$artifacts"
    validate_networks "$networks"
    validate_codenames "$codenames"
    [[ -n "$channel" ]] && validate_channel "$channel"
    check_docker

    echo ""
    echo " ℹ️  Verifying mina artifacts with following parameters:"
    echo " - Verifying artifacts: $artifacts"
    echo " - Networks: $networks"
    echo " - Version: $version"
    echo " - Promoting codenames: $codenames"
    echo " - Published to docker.io: $docker_io"
    echo " - Debian repo: $debian_repo"
    echo " - Debian repos is signed: $signed_debian_repo"
    echo " - Channel: $channel"
    echo " - Only debians: $only_debians"
    echo " - Only dockers: $only_dockers"
    echo " - Docker suffix: $docker_suffix"
    echo ""

    for_each_artifact "verify_artifact" "$artifacts" "$networks" \
        "$codenames" "$version" "$channel" "$debian_repo" \
        "$signed_debian_repo" "$docker_io" "$docker_suffix" \
        "$only_dockers" "$only_debians"

    echo " ✅  Verification done."
    echo ""
}
