# Minimal nix config for describing agent deps
#
# To generate a local environment to test your scripts or to run an agent (for
# example):
#
#   nix-shell shell.nix # optionally add --pure to _only_ use these packages
#   buildkite-agent start --tags size=small --token <TOKEN> --build-path ~/buildkite
#
# Replace `tags` with anything relevant and token with the buildkite token for O(1) Labs
#
#
# To generate a docker image:
#
# Make sure you're in a linux environment with nix installed (not macOS), and pointing to the nixpkgs-unstable channel:
# For example:
#
#   docker run -v $PWD:/workdir -it nixos/nix
#   nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
#   nix-channel --update
#   cd /workdir
#
# Then build the docker image:
#
#   nix-build docker.nix
#
# Note: The first built has to download things, but subsequent builds will cache
# hit no matter the order of the packages in the below array.
#
# Finally, copy the built image to your host OS (if necessary) and load it:
#
#   export CONTAINER_ID=$(docker ps | grep nixos | awk '{ print $1 }')
#   docker cp ${CONTAINER_ID}:<PATH TO BUILT IMAGE> image.tar.gz
#   docker load < image.tar.gz
#
# You will now see:
#
#   docker images
#   # codaprotocol/ci-toolchain-base, latest, ...
#
# If you'd like you can push it up:
#
#   docker push codaprotocol/ci-toolchain-base:latest
#

{ pkgs ? import <nixpkgs> {} }:

# Stick deps in here
let
  deps = with pkgs; [
    # buildkite
    buildkite-agent

    # ssl
    cacert

    # dhall
    dhall
    dhall-json

    # shell stuff
    bash
    git
    coreutils
    gnused
    gnugrep
    findutils
    diffutils
    gnumake
  ];
in
  # little nix derivation that caches dhall
  # Note: `make check` runs in the buildPhase to make sure to fully
  #      populate the dhall cache
let
  dhallCache = pkgs.stdenv.mkDerivation {
    name = "dhall-ci-cache-0.0.1";
    src = ./.;
    buildInputs = [ pkgs.dhall ];
    buildPhase = ''
      mkdir -p $out/.cache
      export XDG_CACHE_HOME=$out/.cache
      make check
    '';
    installPhase = "echo 'skip'";
  };
in
{
  shell =
    pkgs.mkShell {
      buildInputs = deps;
      shellHook = ''
        mkdir -p ~/buildkite
        export GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt
        export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
      '';
    };
  docker =
    pkgs.dockerTools.buildLayeredImage {
      name = "codaprotocol/ci-toolchain-base";
      tag = "latest";
      contents = deps ++ [ dhallCache ];
    };
}
