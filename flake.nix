{
  description =
    "Mina, a cryptocurrency with a lightweight, constant-size blockchain";
  nixConfig = {
    allow-import-from-derivation = "true";
    extra-substituters = [ "https://storage.googleapis.com/mina-nix-cache" ];
    extra-trusted-public-keys = [
      "nix-cache.minaprotocol.org:fdcuDzmnM0Kbf7yU4yywBuUEJWClySc1WIF6t6Mm8h4="
      "nix-cache.minaprotocol.org:D3B1W+V7ND1Fmfii8EhbAbF1JXoe2Ct4N34OKChwk2c="
      "mina-nix-cache-1:djtioLfv2oxuK2lqPUgmZbf8bY8sK/BnYZCU2iU5Q10="
    ];
  };

  inputs.utils.url = "github:gytis-ivaskevicius/flake-utils-plus";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11-small";
  inputs.nixpkgs-old.url = "github:nixos/nixpkgs/nixos-23.05-small";
  inputs.nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

  inputs.nix-npm-buildPackage.url = "github:serokell/nix-npm-buildpackage";
  inputs.nix-npm-buildPackage.inputs.nixpkgs.follows = "nixpkgs";
  inputs.opam-nix.url = "github:tweag/opam-nix";
  inputs.opam-nix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.opam-nix.inputs.opam-repository.follows = "opam-repository";

  inputs.dune-nix.url = "github:o1-labs/dune-nix";
  inputs.dune-nix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.dune-nix.inputs.flake-utils.follows = "utils";

  inputs.describe-dune.url = "github:o1-labs/describe-dune";
  inputs.describe-dune.inputs.nixpkgs.follows = "nixpkgs";
  inputs.describe-dune.inputs.flake-utils.follows = "utils";

  inputs.o1-opam-repository.url =
    "github:o1-labs/opam-repository/dd90c5c72b7b7caeca3db3224b2503924deea08a";
  inputs.o1-opam-repository.flake = false;

  # The version must be the same as the version used in:
  # - dockerfiles/1-build-deps
  # - flake.nix (and flake.lock after running
  #   `nix flake update opam-repository`).
  # - scripts/update-opam-switch.sh
  inputs.opam-repository.url =
    "github:ocaml/opam-repository/08d8c16c16dc6b23a5278b06dff0ac6c7a217356";
  inputs.opam-repository.flake = false;

  inputs.nixpkgs-mozilla.url = "github:mozilla/nixpkgs-mozilla";
  inputs.nixpkgs-mozilla.flake = false;

  # For nix/compat.nix
  inputs.flake-compat.url = "github:edolstra/flake-compat";
  inputs.flake-compat.flake = false;
  inputs.gitignore-nix.url = "github:hercules-ci/gitignore.nix";
  inputs.gitignore-nix.inputs.nixpkgs.follows = "nixpkgs";

  inputs.nix-filter.url = "github:numtide/nix-filter";

  inputs.flake-buildkite-pipeline.url = "github:tweag/flake-buildkite-pipeline";

  inputs.nix-utils.url = "github:juliosueiras-nix/nix-utils";

  inputs.flockenzeit.url = "github:balsoft/Flockenzeit";

  outputs = inputs@{ self, nixpkgs, utils, nix-npm-buildPackage, opam-nix
    , opam-repository, nixpkgs-mozilla, flake-buildkite-pipeline, nix-utils
    , flockenzeit, nixpkgs-old, nixpkgs-unstable, ... }:
    let
      inherit (nixpkgs) lib;

      # All the submodules required by .gitmodules
      submodules = map builtins.head (builtins.filter lib.isList
        (map (builtins.match "	path = (.*)")
          (lib.splitString "\n" (builtins.readFile ./.gitmodules))));

      # Warn about missing submodules
      requireSubmodules = let
        ref = r: "[34;1m${r}[31;1m";
        command = c: "[37;1m${c}[31;1m";
      in lib.warnIf (!builtins.all (x: x)
        (map (x: builtins.pathExists ./${x} && builtins.readDir ./${x} != { })
          submodules)) ''
            Some submodules are missing, you may get errors. Consider one of the following:
            - run ${command "nix/pin.sh"} and use "${
              ref "mina"
            }" flake ref, e.g. ${command "nix develop mina"} or ${
              command "nix build mina"
            };
            - use "${ref "git+file://$PWD?submodules=1"}";
            - use "${
              ref "git+https://github.com/minaprotocol/mina?submodules=1"
            }";
            - use non-flake commands like ${command "nix-build"} and ${
              command "nix-shell"
            }.
          '';
    in {
      overlays = {
        misc = import ./nix/misc.nix;
        rust = import ./nix/rust.nix;
        go = import ./nix/go.nix;
        ocaml = pkgs: prev: {
          ocamlPackages_mina =
            requireSubmodules (import ./nix/ocaml.nix { inherit inputs pkgs; });
        };
        # Skip tests on nodejs dep due to known issue with nixpkgs 24.11 https://github.com/NixOS/nixpkgs/issues/402079
        # this can be removed after upgrading
        skipNodeTests = final: prev: {
          nodejs = prev.nodejs.overrideAttrs (old: { doCheck = false; });
        };
      };
      # Buildkite pipeline for the Nix CI
    } // utils.lib.eachDefaultSystem (system:
      let
        # Helper function to map dependencies to current nixpkgs equivalents
        mapDepsToCurrentPkgs = pkgs: deps:
          map (dep:
            if pkgs ? ${dep.pname or dep.name or ""} then
              pkgs.${dep.pname or dep.name or ""}
            else
              dep) deps;

        # Helper function to disable compression libraries in cmake flags
        disableCompressionLibs = flags:
          builtins.filter (flag: flag != [ ]) (map (flag:
            if builtins.isString flag
            && builtins.match ".*WITH_(BZ2|LZ4|SNAPPY|ZLIB|ZSTD)=1.*" flag
            != null then
              builtins.replaceStrings [ "=1" ] [ "=0" ] flag
            else
              flag) flags);

        rocksdbOverlay = pkgs: prev: {
          rocksdb-mina = let
            # Get the full derivation from unstable but build with current nixpkgs
            unstableRocksdb =
              (nixpkgs-unstable.legacyPackages.${system}.rocksdb.override {
                enableShared = false;
                enableLiburing = false;
                bzip2 = null;
                lz4 = null;
                snappy = null;
                zlib = null;
                zstd = null;
              });
          in pkgs.stdenv.mkDerivation (unstableRocksdb.drvAttrs // {
            cmakeFlags =
              disableCompressionLibs unstableRocksdb.drvAttrs.cmakeFlags;
            # Override the build environment to use current nixpkgs toolchain
            nativeBuildInputs = mapDepsToCurrentPkgs pkgs
              (unstableRocksdb.nativeBuildInputs or [ ]);
            buildInputs =
              mapDepsToCurrentPkgs pkgs (unstableRocksdb.buildInputs or [ ]);
          });
        };
        go119Overlay = (_: _: {
          inherit (nixpkgs-old.legacyPackages.${system})
            go_1_19 buildGo119Module;
        });

        # nixpkgs with all relevant overlays applied
        pkgs = nixpkgs.legacyPackages.${system}.extend
          (nixpkgs.lib.composeManyExtensions ([
            (import nixpkgs-mozilla)
            nix-npm-buildPackage.overlays.default
            (final: prev: {
              rpmDebUtils = final.callPackage "${nix-utils}/utils/rpm-deb" { };
              nix-npm-buildPackage =
                pkgs.callPackage inputs.nix-npm-buildPackage {
                  nodejs = pkgs.nodejs-16_x;
                };
            })
          ] ++ builtins.attrValues self.overlays
            ++ [ rocksdbOverlay go119Overlay ]));

        checks = import ./nix/checks.nix inputs pkgs;

        dockerImages = pkgs.callPackage ./nix/docker.nix {
          inherit flockenzeit;
          currentTime = self.sourceInfo.lastModified or 0;
        };

        ocamlPackages = pkgs.ocamlPackages_mina;

        # Nix-built `dpkg` archives with Mina in them
        debianPackages = pkgs.callPackage ./nix/debian.nix { };

        # Packages for the development environment that are not needed to build mina-dev.
        # For instance dependencies for tests.
        devShellPackages = with pkgs; [
          rosetta-cli
          wasm-pack
          nodejs
          binaryen
          zip
          libiconv
          cargo
          curl
          (pkgs.python3.withPackages
            (python-pkgs: [ python-pkgs.click python-pkgs.requests ]))
          jq
          rocksdb-mina.tools
        ];
      in {

        inherit ocamlPackages;

        # Main user-facing binaries.
        packages = (rec {
          inherit (ocamlPackages)
            mina devnet mainnet mina_tests mina-ocaml-format mina_client_sdk
            test_executive with-instrumentation;
          # Granular nix
          inherit (ocamlPackages)
            src exes all all-tested all-exes files tested info dune-description
            base-libs external-libs;
          # ^ TODO move elsewhere, external-libs isn't a package
          # TODO consider the following: inherit (ocamlPackages) default;
          granular = ocamlPackages.default;
          default = ocamlPackages.mina;
          inherit (pkgs)
            libp2p_helper kimchi_bindings_stubs snarky_js validation trace-tool
            zkapp-cli hardfork_test;
          inherit (dockerImages)
            mina-image-slim mina-image-full mina-archive-image-full;
          mina-deb = debianPackages.mina;
          impure-shell = (import ./nix/impure-shell.nix pkgs).inputDerivation;
        }) // {
          inherit (ocamlPackages) pkgs;
        };

        # Pure dev shell, from which you can build Mina yourself manually, or hack on it.
        devShell = ocamlPackages.mina-dev.overrideAttrs (oa: {
          buildInputs = oa.buildInputs ++ devShellPackages;
          shellHook = ''
            ${oa.shellHook}
            unset MINA_COMMIT_DATE MINA_COMMIT_SHA1 MINA_BRANCH
          '';
        });
        devShells.default = self.devShell.${system};

        # Shell with an LSP server available in it. You can start your editor from this shell, and tell it to look for LSP in PATH.
        devShells.with-lsp = ocamlPackages.mina-dev.overrideAttrs (oa: {
          name = "mina-with-lsp";
          buildInputs = oa.buildInputs ++ devShellPackages;
          nativeBuildInputs = oa.nativeBuildInputs
            ++ [ ocamlPackages.ocaml-lsp-server ];
          shellHook = ''
            ${oa.shellHook}
            unset MINA_COMMIT_DATE MINA_COMMIT_SHA1 MINA_BRANCH
            # TODO: dead code doesn't allow us to have nice things
          '';
        });

        # An "impure" shell, giving you the system deps of Mina, opam, cargo and go.
        devShells.impure = import ./nix/impure-shell.nix pkgs;

        # A shell from which it's possible to build Mina with Rust bits being built incrementally using cargo.
        # This is "impure" from the nix' perspective since running `cargo build` requires networking in general.
        # However, this is a useful balance between purity and convenience for Rust development.
        devShells.rust-impure = ocamlPackages.mina-dev.overrideAttrs (oa: {
          name = "mina-rust-shell";
          buildInputs = oa.buildInputs ++ devShellPackages;
          nativeBuildInputs = oa.nativeBuildInputs ++ [
            pkgs.rustup
            pkgs.libiconv # needed on macOS for one of the rust dep
          ];
        });

        # A shell from which we can compile snarky_js and use zkapp-cli to write and deploy zkapps
        devShells.zkapp-impure = ocamlPackages.mina-dev.overrideAttrs (oa: {
          name = "mina-zkapp-shell";
          buildInputs = oa.buildInputs ++ devShellPackages;
          nativeBuildInputs = oa.nativeBuildInputs ++ [
            pkgs.rustup
            pkgs.libiconv # needed on macOS for one of the rust dep
            pkgs.git
            pkgs.nodejs
            pkgs.zkapp-cli
            pkgs.binaryen # provides wasm-opt
          ];
        });

        inherit checks;

        formatter = pkgs.nixfmt-classic;
      });
}
