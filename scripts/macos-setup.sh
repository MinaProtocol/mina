#!/bin/bash
set -x #echo on
set -eu

USAGE="$0 <download|opam|compile|all>"

if [[ $# -eq 0 ]]; then
  echo $USAGE
  exit 1
fi

if [[ $1 == "download" ]]; then
  DOWNLOAD_THINGS=YES
  OPAM_INIT=NO
  COMPILE_THINGS=NO
elif [[ $1 == "compile" ]]; then
  DOWNLOAD_THINGS=NO
  OPAM_INIT=NO
  COMPILE_THINGS=YES
elif [[ $1 == "opam" ]]; then
  DOWNLOAD_THINGS=NO
  OPAM_INIT=YES
  COMPILE_THINGS=NO
elif [[ $1 == "all" ]]; then
  DOWNLOAD_THINGS=YES
  OPAM_INIT=YES
  COMPILE_THINGS=YES
else
  echo $USAGE
  exit 1
fi

if [[ $DOWNLOAD_THINGS == "YES" ]]; then
  PACKAGES="gpatch opam cmake gmp pkg-config openssl libffi libsodium boost zlib"

  # removing already installed packages from the list
  for p in $(env HOMEBREW_NO_AUTO_UPDATE=1 brew list); do
    PACKAGES=${PACKAGES//$p/}
  done;

  yes | env HOMEBREW_NO_AUTO_UPDATE=1 brew install $PACKAGES

  # ocaml downloading
  yes | opam init
  eval $(opam config env)
fi


# Compile things
if [[ $COMPILE_THINGS == "YES" ]]; then
  # All our ocaml packages
  env TERM=xterm opam switch -y import src/opam.export
  eval $(opam config env)

  # Our pins
  env TERM=xterm opam pin -y add src/external/ocaml-sodium
  env TERM=xterm opam pin -y add src/external/rpc_parallel
  eval $(opam config env)

  # Kademlia
  curl https://nixos.org/nix/install | sh
  touch ~/.profile
  set +u
  . ~/.nix-profile/etc/profile.d/nix.sh
  set -u
  make kademlia
fi

