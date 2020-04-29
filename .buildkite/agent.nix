# minimal nix shell config for running local agents for testing purposes

{ pkgs ? import <nixpkgs> {} }:
  pkgs.mkShell {
    buildInputs = [ pkgs.buildkite-agent pkgs.dhall pkgs.dhall-json ];
}

