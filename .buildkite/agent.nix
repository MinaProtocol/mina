# minimal nix shell config for running local agents for testing purposes

{ pkgs ? import <nixpkgs> {} }:
  pkgs.mkShell {
    buildInputs = [ pkgs.buildkite-agent pkgs.dhall pkgs.dhall-json ];
    shellHook = ''
      export GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt
      export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    '';
}

