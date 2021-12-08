{
  description = "A very basic flake";
  inputs.utils.url = "github:gytis-ivaskevicius/flake-utils-plus";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";
  inputs.gitignore = {
    url = "github:hercules-ci/gitignore.nix";
    # Use the same nixpkgs
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, utils, gitignore }:
    utils.lib.mkFlake {
      inherit self inputs;
      supportedSystems = [ "x86_64-linux" ];
      channelsConfig.allowUnfree = true;
      outputsBuilder = channels: let
        pkgs = channels.nixpkgs;
        inherit (gitignore.lib) gitignoreSource;
      in {

        # todo: Fast
        # - codeowners + rfcs + snarky + preprocessor deps
        # - compare ci diff types
        # - binable

        # todo: helmchart
        # todo: merges cleanly into develop -- wait why

        # Jobs/Lint/Rust.dhall
        packages.trace-tool = channels.nixpkgs.rustPlatform.buildRustPackage rec {
          pname = "trace-tool";
          version = "0.1.0";
          src = gitignoreSource ./src/app/trace-tool;
          cargoLock.lockFile = ./src/app/trace-tool/Cargo.lock;
        };

        # Jobs/Lint/OCaml.dhall
        checks.lint-check-format = channels.nixpkgs.stdenv.mkDerivation {
          # todo: only depend on ./src
          name = "lint-check-format";
          # todo: from opam
          buildInputs = with pkgs.ocaml-ng.ocamlPackages_4_11; [ ocaml dune_2 ppx_jane findlib async pkgs.ocamlformat_0_15_0 ];
          src = gitignoreSource ./.;
          buildPhase = "make check-format";
          installPhase = "echo ok > $out";
        };
        checks.require-ppxs = channels.nixpkgs.stdenv.mkDerivation {
          name = "require-ppxs";
          # todo: only depend on dune files
          src = gitignoreSource ./.;
          buildInputs = [(pkgs.python3.withPackages (p: [p.sexpdata]))];
          buildPhase = "python ./scripts/require-ppxs.py";
          installPhase = "echo ok > $out";
        };

      };
    };
}
