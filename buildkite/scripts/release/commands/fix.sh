#!/usr/bin/env bash

# Fix command implementation

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
}

function fix(){
    if [[ ${#} == 0 ]]; then
        fix_help; exit 0;
    fi

    local codenames="$DEFAULT_CODENAMES"
    local channel
    local bucket_arg="--bucket=packages.o1test.net"
    local s3_region_arg="--s3-region=us-west-2"

    while [ ${#} -gt 0 ]; do
        error_message="Error: a value is needed for '$1'";
        case $1 in
            -h | --help )
                fix_help; exit 0;
            ;;
            --codenames )
                codenames=${2:?$error_message}
                shift 2;
            ;;
            --channel )
                channel=${2:?$error_message}
                shift 2;
            ;;
            * )
                echo -e "${RED} !! Unknown option: $1${CLEAR}\n";
                echo "";
                fix_help; exit 1;
            ;;
        esac
    done

    # Validate parameter values
    validate_codenames "$codenames"
    [[ -n "$channel" ]] && validate_channel "$channel"

    echo ""
    echo " ℹ️  Fixing debian repository with following parameters:"
    echo " - Codenames: $codenames"
    echo " - Channel: $channel"
    echo ""

    IFS=', '
    read -r -a codenames_arr <<< "$codenames"

    for codename in "${codenames_arr[@]}"; do
        deb-s3 verify \
        --fix-manifests \
        $bucket_arg \
        $s3_region_arg \
        --codename=${codename} \
        --component=${channel}
    done

    echo " ✅  Done."
    echo ""
}