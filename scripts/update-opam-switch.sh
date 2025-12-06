#!/usr/bin/env bash

set -eo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR/.."

# Don't do anything if we're in a nix shell
[[ "$IN_NIX_SHELL$CI$BUILDKITE" == "" ]] || exit 0

# Some users do not have the setup with using local switches and multiple
# switches in the directory `opam_switch`. We want to support that, so we allow
# bypassing the switch update.
if [ -n "${BYPASS_OPAM_SWITCH_UPDATE+x}" ]; then
    echo "BYPASS_OPAM_SWITCH_UPDATE is set, skipping opam switch update."
    exit 0
fi

sum="$(cksum opam.export | grep -oE '^\S*')"
switch_dir=opam_switches/"$sum"
# The version must be the same as the version used in:
# - dockerfiles/1-build-deps
# - opam.export
# - scripts/update_opam_switch.sh
ocaml_version=4.14.2

# The version must be the same as the version used in:
# - dockerfiles/1-build-deps
# - flake.nix (and flake.lock after running
#   `nix flake update opam-repository`).
# - scripts/update_opam_switch.sh
OPAM_REPOSITORY_COMMIT=08d8c16c16dc6b23a5278b06dff0ac6c7a217356
O1LABS_OPAM_REPOSITORY_COMMIT=b4e598aaf1000efadda310efba4bde6ca6e7fdfa

if [[ -d _opam ]]; then
    read -rp "Directory '_opam' exists and will be removed. You can also bypass the check by setting the variable BYPASS_OPAM_SWITCH_UPDATE to any value. Continue? [y/N] " \
         confirm
    if [[ "${confirm}" =~ ^[Yy]$ ]]; then
        rm -Rf _opam
    else
        echo "Aborted."
        exit 1
    fi
fi

opam-repo-upsert() {
    local name="$1"
    local url="$2"

    if opam repository list --short | grep -qx "$name"; then
        opam repository set-url "$name" "$url"
    else
        opam repository add "$name" "$url"
    fi
}

if [[ ! -d "${switch_dir}" ]]; then
    opam switch create ./ ${ocaml_version} --no-install --yes
    eval "$(opam env)"

    opam-repo-upsert o1-labs "https://github.com/o1-labs/opam-repository.git#${O1LABS_OPAM_REPOSITORY_COMMIT}"

    # The default opam repository is set to a specific commit as some of our
    # dependencies have been archived.
    # See https://github.com/MinaProtocol/mina/pull/17450
    opam-repo-upsert default "git+https://github.com/ocaml/opam-repository.git#${OPAM_REPOSITORY_COMMIT}"

    opam update
    opam switch import -y --switch . opam.export
    mkdir -p opam_switches
    mv _opam "${switch_dir}"
fi

ln -s "${switch_dir}" _opam
