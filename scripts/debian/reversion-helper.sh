#!/bin/bash

set -eo pipefail

function reversion() {
    local __deb
    local __package
    local __source_version
    local __new_version
    local __suite
    local __new_suite
    local __new_name

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
            *)
                echo "$0 Unknown parameter in reversion() : ${1}" >&2
                exit 1
        esac

        if ! shift; then
            echo 'Missing parameter argument.' >&2
            exit 1
        fi
    done

    local __new_deb="${__new_name}_${__new_version}"
    local __parent_dir
    __parent_dir=$(dirname "${__deb}_${__source_version}.deb")

    rm -rf "${__new_deb}"
    # shellcheck disable=SC2140
    rm -rf "${__parent_dir}"/"${__new_deb}.deb"

    if [[ ! -f "${__deb}_${__source_version}.deb" ]]; then
        echo "Error: File ${__deb}_${__source_version}.deb does not exist" >&2
        echo "Contents of ${__parent_dir}:" >&2
        ls -la "${__parent_dir}"
        exit 1
    fi
    dpkg-deb -R "${__deb}_${__source_version}.deb" "${__new_deb}"
    # shellcheck disable=SC2140
    sed -i 's/Version: '"${__source_version}"'/Version: '"${__new_version}"'/g' "${__new_deb}/DEBIAN/control"
    # shellcheck disable=SC2140
    sed -i 's/Package: '"${__package}"'/Package: '"${__new_name}"'/g' "${__new_deb}/DEBIAN/control"
    # shellcheck disable=SC2140
    sed -i 's/Suite: '"${__suite}"'/Suite: '"${__new_suite}"'/g' "${__new_deb}/DEBIAN/control"
    # shellcheck disable=SC2140
    dpkg-deb --build "${__new_name}_${__new_version}" "${__parent_dir}"/"${__new_deb}.deb"

    rm -rf "${__new_deb}"
}
