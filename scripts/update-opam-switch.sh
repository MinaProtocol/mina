#!/usr/bin/env bash

set -eo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR/.."

# Don't do anything if we're in a nix shell
[[ "$IN_NIX_SHELL$CI$BUILDKITE" == "" ]] || exit 0

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
opam_repository_commit=08d8c16c16dc6b23a5278b06dff0ac6c7a217356

if [[ -d _opam ]]; then
    read -rp "Directory '_opam' exists and will be removed. Continue? [y/N] " \
         confirm
    if [[ "${confirm}" =~ ^[Yy]$ ]]; then
        rm -Rf _opam
    else
        echo "Aborted."
        exit 1
    fi
fi

if [[ ! -d "${switch_dir}" ]]; then
    opam switch create ./ ${ocaml_version} --no-install --yes
    eval "$(opam env)"
    # We add o1-labs opam repository and make it default
    # (if it's repeated, it's a no-op)
    opam repository add --yes --set-default o1-labs \
         https://github.com/o1-labs/opam-repository.git
    # The default opam repository is set to a specific commit as some of our
    # dependencies have been archived.
    # See https://github.com/MinaProtocol/mina/pull/17450
    opam repository \
         set-url \
         default \
         "git+https://github.com/ocaml/opam-repository.git#${opam_repository_commit}"
    opam update
    opam switch import -y --switch . opam.export
    mkdir -p opam_switches
    mv _opam "${switch_dir}"
fi

ln -s "${switch_dir}" _opam
