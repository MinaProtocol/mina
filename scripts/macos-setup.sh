#!/bin/bash
set -x #echo on
set -eu

USAGE="$0 <download|compile|all>"

if [[ $# -eq 0 ]]; then
  echo $USAGE
  exit 1
fi

case $1 in
  "download")
    DOWNLOAD_THINGS=YES
    COMPILE_THINGS=NO ;;
  "compile")
    DOWNLOAD_THINGS=NO
    COMPILE_THINGS=YES ;;
  "all")
    DOWNLOAD_THINGS=YES
    COMPILE_THINGS=YES ;;
  *)
    echo $USAGE
    exit 1
esac

if [[ $DOWNLOAD_THINGS == "YES" ]]; then
  PACKAGES="gpatch opam cmake gmp pkg-config openssl libffi libsodium boost zlib"

  # removing already installed packages from the list
  for p in $(env HOMEBREW_NO_AUTO_UPDATE=1 brew list); do
    PACKAGES=${PACKAGES//$p/}
  done;

  # only run if there's work to do
  if [[ $PACKAGES = *[![:space:]]* ]];
   then
    yes | env HOMEBREW_NO_AUTO_UPDATE=1 brew install $PACKAGES
  else
    echo 'All brew packages have already been installed.'
  fi

  # ocaml downloading
  yes | opam init
  eval $(opam config env)
else
  echo 'Not running download step'
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
else
  echo 'Not running compile step.'
fi


