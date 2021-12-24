{
  description = "A very basic flake";
  nixConfig.allow-import-from-derivation = "true";
  inputs.utils.url = "github:gytis-ivaskevicius/flake-utils-plus";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";
  # todo: upstream
  inputs.mix-to-nix.url = "github:serokell/mix-to-nix/yorickvp/deadlock";
  inputs.nix-npm-buildPackage.url = "github:lumiguide/nix-npm-buildpackage"; # todo: upstream
  inputs.opam-nix.url = "github:balsoft/opam-nix";
  inputs.opam-repository.url = "github:ocaml/opam-repository";
  inputs.opam-repository.flake = false;

  outputs = inputs@{ self, nixpkgs, utils, mix-to-nix, nix-npm-buildPackage, opam-nix, opam-repository }:
    utils.lib.mkFlake {
      inherit self inputs;
      supportedSystems = [ "x86_64-linux" ];
      channelsConfig.allowUnfree = true;
      #sharedOverlays = [ mix-to-nix.overlay ];
      outputsBuilder = channels: let
        pkgs = channels.nixpkgs;
        inherit (pkgs) lib;
        mix-to-nix = pkgs.callPackage inputs.mix-to-nix {};
        nix-npm-buildPackage = pkgs.callPackage inputs.nix-npm-buildPackage {};
        go-capnproto2 = pkgs.buildGoModule rec {
          pname = "capnpc-go";
          version = "v3.0.0-alpha.1";
          vendorSha256 = "sha256-jbX/nnlnQoItFXFL/MZZKe4zAjM/EA3q+URJG8I3hok=";
          src = pkgs.fetchFromGitHub {
            owner = "capnproto";
            repo = "go-capnproto2";
            rev = "v3.0.0-alpha.1";
            hash = "sha256-afdLw7of5AksR4ErCMqXqXCOnJ/nHK2Lo4xkC5McBfM";
          };
        };
        ocamlPackages = import ./mina.nix inputs pkgs;
      in {

        # todo: Fast
        checks.lint-codeowners = pkgs.stdenv.mkDerivation {
          # todo: filter source
          name = "lint-codeowners";
          src = ./.;
          # todo: submodules :(
          buildPhase = ''
            mkdir -p src/lib/snarky
            bash ./scripts/lint_codeowners.sh
          '';
          installPhase = "touch $out";
        };
        # todo: this check succeeds with 0 rfcs
        checks.lint-rfcs = pkgs.runCommand "lint-rfcs" {} ''
          ln -s ${./rfcs} ./rfcs
          bash ${./scripts/lint_rfcs.sh}
          touch $out
        '';
        # todo: ./scripts/check-snarky-submodule.sh # submodule issue
        checks.lint-preprocessor-deps = pkgs.runCommand "lint-preprocessor-deps" {} ''
          ln -s ${./src} ./src
          bash ${./scripts/lint_preprocessor_deps.sh}
          touch $out
        '';
        # - compare ci diff_types
        # - compare_ci_diff_binables

        # todo: helmchart
        # todo: merges cleanly into develop -- wait why
        # todo: TestnetAlerts

        # Jobs/Lint/Rust.dhall
        packages.trace-tool = channels.nixpkgs.rustPlatform.buildRustPackage rec {
          pname = "trace-tool";
          version = "0.1.0";
          src = ./src/app/trace-tool;
          cargoLock.lockFile = ./src/app/trace-tool/Cargo.lock;
        };

        # Jobs/Lint/ValidationService
        # Jobs/Test/ValidationService
        packages.validation = ((mix-to-nix.override {
          beamPackages = pkgs.beam.packagesWith pkgs.erlangR22; # todo: jose
        }).mixToNix {
          src = ./src/app/validation;
          # todo: think about fixhexdep overlay
          # todo: dialyze
          overlay = (final: previous: {
            goth = previous.goth.overrideAttrs (o: {
              preConfigure = "sed -i '/warnings_as_errors/d' mix.exs";
            });
          });
        }).overrideAttrs (o: {
          # workaround for requiring --allow-import-from-derivation
          # during 'nix flake show'
          name = "coda_validation-0.1.0";
          version = "0.1.0";
        });

        # Jobs/Test/Libp2pUnitTest
        packages.libp2p_ipc_go = pkgs.stdenv.mkDerivation {
          # todo: buildgomodule?
          name = "libp2p_ipc-go";
          buildInputs = [ pkgs.capnproto go-capnproto2 ];
          src = ./src/libp2p_ipc;
          buildPhase = ''
            capnp compile -ogo -I${go-capnproto2.src}/std libp2p_ipc.capnp
          '';
          installPhase = ''
            mkdir $out
            cp go.mod go.sum *.go $out/
          '';
        };
        packages.libp2p_helper = pkgs.buildGoModule {
          pname = "libp2p_helper";
          version = "0.1";
          src = ./src/app/libp2p_helper/src;
          runVend = true; # missing some schema files
          vendorSha256 = "sha256-g0DsuLMiXjUTsGbhCSeFKEFKMEMtg3UTUjmYwUka6iE=";
          postConfigure = ''
            chmod +w vendor
            cp -r --reflink=auto ${self.packages.${pkgs.system}.libp2p_ipc_go}/ vendor/libp2p_ipc
          '';
          NO_MDNS_TEST = 1; # no multicast support inside the nix sandbox
          overrideModAttrs = n: {
            # remove libp2p_ipc from go.mod, inject it back in postconfigure
            postConfigure = ''
              sed -i '/libp2p_ipc/d' go.mod
            '';
          };
        };
        # todo: libp2p_ipc

        # Jobs/Lint/OCaml.dhall
        checks.lint-check-format = channels.nixpkgs.stdenv.mkDerivation {
          # todo: only depend on ./src
          name = "lint-check-format";
          # todo: from opam
          buildInputs = with pkgs.ocaml-ng.ocamlPackages_4_11; [ ocaml dune_2 ppx_jane findlib async pkgs.ocamlformat_0_15_0 ];
          src = ./.;
          buildPhase = "make check-format";
          installPhase = "echo ok > $out";
        };
        checks.require-ppxs = channels.nixpkgs.stdenv.mkDerivation {
          name = "require-ppxs";
          # todo: only depend on dune files
          src = ./.;
          buildInputs = [(pkgs.python3.withPackages (p: [p.sexpdata]))];
          buildPhase = "python ./scripts/require-ppxs.py";
          installPhase = "echo ok > $out";
        };

        # Jobs/Release/LeaderboardArtifact
        packages.leaderboard = nix-npm-buildPackage.buildYarnPackage {
          src = ./frontend/leaderboard;
          yarnBuildMore = "yarn build";
          # fix reason
          yarnPostLink = pkgs.writeScript "yarn-post-link" ''
            #!${pkgs.stdenv.shell}
            ls node_modules/bs-platform/lib/*.linux
            patchelf \
              --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
              --set-rpath "${pkgs.stdenv.cc.cc.lib}/lib" \
              ./node_modules/bs-platform/lib/*.linux ./node_modules/bs-platform/vendor/ninja/snapshot/*.linux
           '';
          # todo: external stdlib @rescript/std
          preInstall = ''
            shopt -s extglob
            rm -rf node_modules/bs-platform/lib/!(js)
            rm -rf node_modules/bs-platform/!(lib)
            rm -rf yarn-cache
          '';
        };

        inherit ocamlPackages;
        packages.mina = ocamlPackages.mina;
      };
    };
}
