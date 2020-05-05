# Minimal nix shell config for running local agents for testing purposes
#
# Usage:
#
# nix-shell agent.nix
# buildkite-agent start --tags size=small --token <TOKEN> --build-path ~/buildkite
#
# Replace `tags` with anything relevant and token with the buildkite token for O(1) Labs

{ pkgs ? import <nixpkgs> {} }:
  pkgs.mkShell {
    buildInputs = [ pkgs.buildkite-agent pkgs.dhall pkgs.dhall-json ];
    shellHook = ''
      mkdir -p ~/buildkite
      export GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt
      export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    '';
}

