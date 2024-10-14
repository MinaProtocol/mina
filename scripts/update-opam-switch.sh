#!/usr/bin/env bash

set -eo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR/.."

# Don't do anything if we're in a nix shell
[[ "$IN_NIX_SHELL$CI$BUILDKITE" == "" ]] || exit 0

sum="$(cksum opam.export | grep -oE '^\S*')"
switch_dir=opam_switches/"$sum"
rm -Rf _opam
if [[ ! -d "$switch_dir" ]]; then
  # We add o1-labs opam repository and make it default (if it's repeated, it's a no-op)
  opam repository add --yes --all --set-default o1-labs https://github.com/o1-labs/opam-repository.git
  opam update
  opam switch import -y --switch . opam.export
  mkdir -p opam_switches
  mv _opam "$switch_dir"
fi
ln -s "$switch_dir" _opam
