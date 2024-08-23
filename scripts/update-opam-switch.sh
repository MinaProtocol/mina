#!/usr/bin/env bash

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR/.."

# Don't do anything if we're in a nix shell
[[ "$IN_NIX_SHELL$CI$BUILDKITE" == "" ]] || exit 0

sum="$(cksum opam.export | grep -oE '^\S*')"
switch_dir=opam_switches/"$sum"
rm -Rf _opam
if [[ ! -d "$switch_dir" ]]; then
  opam switch import -y --switch . opam.export
  opam pin -y add src/external/ocaml-sodium
  opam pin -y add src/external/coda_base58
  mkdir -p opam_switches
  mv _opam "$switch_dir"
fi
ln -s "$switch_dir" _opam
