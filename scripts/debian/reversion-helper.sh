#!/bin/bash

set -eo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function reversion() {
    local __deb
    local __package
    local __source_version
    local __new_version
    local __suite
    local __new_suite
    local __new_name
    local __arch

    while [[ "$#" -gt 0 ]]; do
        case "${1}" in
            --deb)
                __deb=${2}
                shift
                ;;
            --package)
                __package=${2}
                shift
                ;;
            --source-version)
                __source_version=${2}
                shift
                ;;
            --new-version)
                __new_version=${2}
                shift
                ;;
            --suite)
                __suite=${2}
                shift
                ;;
            --new-suite)
                __new_suite=${2}
                shift
                ;;
            --new-name)
                __new_name=${2}
                shift
                ;;
            --arch)
                __arch=${2}
                shift
                ;;
            *)
                echo "$0 Unknown parameter in reversion() : ${1}" >&2
                exit 1
        esac

        if ! shift; then
            echo 'Missing parameter argument.' >&2
            exit 1
        fi
    done

    local __new_deb="${__new_name}_${__new_version}_${__arch}"
    local __parent_dir
    __parent_dir=$(dirname "${__deb}_${__source_version}_${__arch}.deb")

    local __session_dir="${__new_deb}_session"

    rm -rf "${__session_dir}"
    # shellcheck disable=SC2140
    rm -rf "${__parent_dir}"/"${__new_deb}.deb"

    if [[ ! -f "${__deb}_${__source_version}_${__arch}.deb" ]]; then
        echo "Error: File ${__deb}_${__source_version}_${__arch}.deb does not exist" >&2
        echo "Contents of ${__parent_dir}:" >&2
        ls -la "${__parent_dir}"
        exit 1
    fi

    # Open session using deb-session-open.sh
    "${SCRIPT_DIR}/session/deb-session-open.sh" \
        "${__deb}_${__source_version}_${__arch}.deb" \
        "${__session_dir}"

    # Update control file fields using deb-session-update-control.sh
    "${SCRIPT_DIR}/session/deb-session-update-control.sh" \
        "${__session_dir}" \
        "Version" \
        "${__new_version}"

    "${SCRIPT_DIR}/session/deb-session-update-control.sh" \
        "${__session_dir}" \
        "Package" \
        "${__new_name}"

    "${SCRIPT_DIR}/session/deb-session-update-control.sh" \
        "${__session_dir}" \
        "Suite" \
        "${__new_suite}"

    # Save the modified package using deb-session-save.sh
    "${SCRIPT_DIR}/session/deb-session-save.sh" \
        "${__session_dir}" \
        "${__parent_dir}/${__new_deb}.deb"

    # Clean up session directory
    rm -rf "${__session_dir}"
}