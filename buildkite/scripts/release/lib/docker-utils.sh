#!/usr/bin/env bash

# Docker utilities

function promote_and_verify_docker() {
    local config_array=("$@")
    local artifact=${config_array[0]}
    local source_version=${config_array[1]}
    local target_version=${config_array[2]}
    local codename=${config_array[3]}
    local network=${config_array[4]}
    local publish_to_docker_io=${config_array[5]}
    local verify=${config_array[6]}
    local dry_run=${config_array[7]}

    local network_suffix=$(get_suffix $artifact $network)

    local artifact_full_source_version=$source_version-$codename${network_suffix}
    local artifact_full_target_version=$target_version-$codename${network_suffix}

    if [[ $publish_to_docker_io == 1 ]]; then
        local publish_arg="-p"
        local repo=$DOCKER_IO_REPO
    else
        local publish_arg=""
        local repo=$GCR_REPO
    fi

    echo " 🐋 Publishing $artifact docker for '$network' network and '$codename' codename with '$target_version' version"
    echo "    📦 Target version: $(calculate_docker_tag $publish_to_docker_io $artifact $target_version $codename "$network" )"
    echo ""

    if [[ $dry_run == 0 ]]; then
        prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/docker/promote.sh \
            -q \
            -n "$artifact" \
            -v $artifact_full_source_version \
            -t $artifact_full_target_version \
            $publish_arg

        echo ""

        if [[ $verify == 1 ]]; then
            echo "    📋 Verifying: $artifact docker for '$network' network and '$codename' codename with '$target_version' version"
            echo ""

            prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/docker/verify.sh \
                -p "$artifact" \
                -v "$target_version" \
                -c "$codename" \
                -s "$network_suffix" \
                -r "$repo"

            echo ""
        fi
    fi
}

function verify_docker_image() {
    local artifact=$1
    local network=$2
    local codename=$3
    local version=$4
    local docker_io=$5
    local docker_suffix=$6

    local artifact_full_name=$(get_artifact_with_suffix $artifact $network)
    local repo=$(get_repo $docker_io)

    local docker_suffix_combined=$(combine_docker_suffixes "$network" "$docker_suffix")
    local suffix_arg=""

    if [[ -n "$docker_suffix" ]]; then
        suffix_arg="-s $docker_suffix_combined"
    elif [[ -n "$network" ]]; then
        suffix_arg="-s $docker_suffix_combined"
    fi

    echo "      📋  Verifying: $artifact docker on $(calculate_docker_tag "$docker_io" $artifact_full_name $version $codename "$network")"
    echo ""

    prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/docker/verify.sh \
        -p "$artifact" \
        -v $version \
        -c "$codename" \
        ${suffix_arg} \
        -r "$repo"

    echo ""
}

function should_process_docker() {
    local artifact=$1
    local only_debians=$2

    if [[ $only_debians == 1 ]]; then
        return 1
    fi

    case $artifact in
        mina-logproc)
            echo "ℹ️  There is no $artifact docker image to publish. skipping"
            return 1
            ;;
        mina-archive|mina-rosetta|mina-daemon)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}