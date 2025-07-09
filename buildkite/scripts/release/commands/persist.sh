#!/usr/bin/env bash

# Persist command implementation

function persist_help(){
    echo Persist artifact from cache.
    echo ""
    echo "     $CLI_NAME persist [-options]"
    echo ""
    echo "Parameters:"
    echo ""
    printf "  %-25s %s\n" "-h  | --help" "show help";
    printf "  %-25s %s\n" "--backend" "[string] backend to persist artifacts. e.g gs,hetzner";
    printf "  %-25s %s\n" "--artifacts" "[comma separated list] list of artifacts to persist. e.g mina-logproc,mina-archive,mina-rosetta";
    printf "  %-25s %s\n" "--build_id" "[string] buildkite build id to persist artifacts";
    printf "  %-25s %s\n" "--target" "[string] target location to persist artifacts";
    echo ""
    echo "Example:"
    echo ""
    echo "  " $CLI_NAME persist --backend gs --artifacts mina-logproc,mina-archive,mina-rosetta --build_id 123 --target /debians_legacy
    echo ""
    echo " Above command will persist mina-logproc,mina-archive,mina-rosetta artifacts to {backend root}/debians_legacy"
    echo ""
}

function persist(){
    if [[ ${#} == 0 ]]; then
        persist_help; exit 0;
    fi

    local backend="hetzner"
    local artifacts="$DEFAULT_ARTIFACTS"
    local buildkite_build_id
    local target
    local codename

    while [ ${#} -gt 0 ]; do
        error_message="Error: a value is needed for '$1'";
        case $1 in
            -h | --help )
                persist_help; exit 0;
            ;;
            --backend )
                backend=${2:?$error_message}
                shift 2;
            ;;
            --artifacts )
                artifacts=${2:?$error_message}
                shift 2;
            ;;
            --codename )
                codename=${2:?$error_message}
                shift 2;
            ;;
            --buildkite-build-id )
                buildkite_build_id=${2:?$error_message}
                shift 2;
            ;;
            --target )
                target=${2:?$error_message}
                shift 2;
            ;;
            * )
                echo -e "${RED} !! Unknown option: $1${CLEAR}\n";
                echo "";
                persist_help; exit 1;
            ;;
        esac
    done

    # Validate required parameters
    validate_required_param "Buildkite build id (--buildkite-build-id)" "$buildkite_build_id" "persist_help"
    validate_required_param "Target (--target)" "$target" "persist_help"
    validate_required_param "Codename (--codename)" "$codename" "persist_help"
    validate_required_param "Artifacts (--artifacts)" "$artifacts" "persist_help"

    # Validate parameter values
    validate_artifacts "$artifacts"
    validate_backend "$backend" || { persist_help; exit 1; }

    echo ""
    echo " ℹ️  Persisting mina artifacts with following parameters:"
    echo " - Backend: $backend"
    echo " - Artifacts: $artifacts"
    echo " - Buildkite build id: $buildkite_build_id"
    echo " - Target: $target"

    IFS=', '
    read -r -a artifacts_arr <<< "$artifacts"

    tmp_dir=$(mktemp -d)
    echo " - Using temporary directory: $tmp_dir"
    echo ""

    for artifact in "${artifacts_arr[@]}"; do
        storage_download "$backend" "$(storage_root "$backend")/$buildkite_build_id/debians/$codename/${artifact}_*" "$tmp_dir"
        storage_upload "$backend" "$tmp_dir/${artifact}_*" "$(storage_root "$backend")/$target/debians/$codename/"
    done

    echo " ✅  Done."
    echo ""
}