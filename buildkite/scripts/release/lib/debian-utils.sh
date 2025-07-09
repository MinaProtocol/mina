#!/usr/bin/env bash

# Debian package utilities

function get_cached_debian_or_download() {
    local backend=$1
    local artifact=$2
    local codename=$3
    local network=$4

    local artifact_full_name=$(get_artifact_with_suffix "$artifact" "$network")
    local remote_path="$(storage_root "$backend")/$BUILDKITE_BUILD_ID/debians/$codename/${artifact_full_name}_*"

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

function publish_debian_package() {
    local config_array=("$@")
    local artifact=${config_array[0]}
    local codename=${config_array[1]}
    local source_version=${config_array[2]}
    local target_version=${config_array[3]}
    local channel=${config_array[4]}
    local network=${config_array[5]}
    local verify=${config_array[6]}
    local dry_run=${config_array[7]}
    local backend=${config_array[8]}
    local debian_repo=${config_array[9]}
    local debian_sign_key=${config_array[10]}

    get_cached_debian_or_download $backend $artifact $codename "$network"
    local artifact_full_name=$(get_artifact_with_suffix $artifact $network)
    local deb=$DEBIAN_CACHE_FOLDER/$codename/"${artifact_full_name}"

    if [[ $debian_sign_key != "" ]]; then
        local sign_arg=("--sign" "$debian_sign_key")
        local signed_arg="--signed"
    else
        local sign_arg=()
        local signed_arg=""
    fi

    if [[ $source_version != "$target_version" ]]; then
        echo " 🗃️  Rebuilding $artifact debian from $source_version to $target_version"
        prefix_cmd "$SUBCOMMAND_TAB" reversion --deb ${deb} \
                --package ${artifact_full_name} \
                --source-version ${source_version} \
                --new-version ${target_version} \
                --suite "unstable" \
                --new-suite ${channel} \
                --new-name ${artifact_full_name} \
                --new-release ${channel} \
                --codename ${codename}
    fi

    echo " 🍥  Publishing $artifact debian to $channel channel with $target_version version"
    echo "     📦  Target debian version: $(calculate_debian_version $artifact $target_version $codename "$network" )"

    if [[ $dry_run == 0 ]]; then
        # shellcheck disable=SC2068
        prefix_cmd "$SUBCOMMAND_TAB" source $SCRIPTPATH/../../../scripts/debian/publish.sh \
            --names "$DEBIAN_CACHE_FOLDER/$codename/${artifact_full_name}_${target_version}.deb" \
            --version $target_version \
            --bucket $debian_repo \
            -c $codename \
            -r $channel \
            ${sign_arg[@]}

        if [[ $verify == 1 ]]; then
            echo "     📋 Verifying: $artifact debian to $channel channel with $target_version version"

            prefix_cmd "$SUBCOMMAND_TAB" source $SCRIPTPATH/../../../scripts/debian/verify.sh \
                -p $artifact_full_name \
                --version $target_version \
                -m $codename \
                -r $debian_repo \
                -c $channel ${signed_arg}
        fi
    fi
}

function promote_debian_package() {
    local config_array=("$@")
    local artifact=${config_array[0]}
    local codename=${config_array[1]}
    local source_version=${config_array[2]}
    local target_version=${config_array[3]}
    local source_channel=${config_array[4]}
    local target_channel=${config_array[5]}
    local network=${config_array[6]}
    local verify=${config_array[7]}
    local dry_run=${config_array[8]}
    local debian_repo=${config_array[9]}
    local debian_sign_key=${config_array[10]}

    if [[ $debian_sign_key != "" ]]; then
        local sign_arg=("--sign" "$debian_sign_key")
        local signed_arg="--signed"
    else
        local sign_arg=()
        local signed_arg=""
    fi

    echo " 🍥 Promoting $artifact debian from $source_channel to $target_channel, from $source_version to $target_version"
    echo "    📦 Target debian version: $(calculate_debian_version $artifact $target_version $codename "$network")"

    local artifact_full_name=$(get_artifact_with_suffix $artifact $network)

    if [[ $dry_run == 0 ]]; then
        echo "    🗃️  Promoting $artifact debian from $codename/$source_version to $codename/$target_version"
        prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/debian/reversion.sh \
                --deb ${artifact_full_name} \
                --version ${source_version} \
                --release ${source_channel} \
                --new-version ${target_version} \
                --suite ${source_channel} \
                --repo ${debian_repo} \
                --new-suite ${target_channel} \
                --new-name ${artifact_full_name} \
                --new-release ${target_channel} \
                --codename ${codename}

        if [[ $verify == 1 ]]; then
            echo "     📋 Verifying: $artifact debian to $target_channel channel with $target_version version"

            prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/debian/verify.sh \
                -p $artifact_full_name \
                --version $target_version \
                -m $codename \
                -r $debian_repo \
                -c $target_channel ${signed_arg}
        fi
    fi
}

function verify_debian_package() {
    local artifact=$1
    local network=$2
    local codename=$3
    local version=$4
    local channel=$5
    local debian_repo=$6
    local signed_debian_repo=$7
    local docker_suffix=$8

    local artifact_full_name=$(get_artifact_with_suffix $artifact $network)

    echo "     📋  Verifying: $artifact debian on $channel channel with $version version for $codename codename"

    prefix_cmd "$SUBCOMMAND_TAB" $SCRIPTPATH/../../../scripts/debian/verify.sh \
        -p $artifact_full_name \
        --version $version \
        -m $codename \
        -r $debian_repo \
        -c $channel \
        -s "$docker_suffix" \
        ${signed_debian_repo:+--signed}
}