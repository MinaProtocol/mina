{
  description =
    "Mina, a cryptocurrency with a lightweight, constant-size blockchain";
  nixConfig = {
    allow-import-from-derivation = "true";
    extra-substituters = [ "https://storage.googleapis.com/mina-nix-cache" ];
    extra-trusted-public-keys = [
      "nix-cache.minaprotocol.org:fdcuDzmnM0Kbf7yU4yywBuUEJWClySc1WIF6t6Mm8h4="
      "nix-cache.minaprotocol.org:D3B1W+V7ND1Fmfii8EhbAbF1JXoe2Ct4N34OKChwk2c="
    ];
  };

  inputs.utils.url = "github:gytis-ivaskevicius/flake-utils-plus";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";

  inputs.mix-to-nix.url = "github:serokell/mix-to-nix";
  inputs.nix-npm-buildPackage.url = "github:serokell/nix-npm-buildpackage";
  inputs.nix-npm-buildPackage.inputs.nixpkgs.follows = "nixpkgs";
  inputs.opam-nix.url = "github:tweag/opam-nix";
  inputs.opam-nix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.opam-nix.inputs.opam-repository.follows = "opam-repository";

  inputs.opam-repository.url = "github:ocaml/opam-repository";
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

  outputs = inputs@{ self, nixpkgs, utils, mix-to-nix, nix-npm-buildPackage
    , opam-nix, opam-repository, nixpkgs-mozilla, flake-buildkite-pipeline
    , nix-utils, ... }:
    {
      overlays = {
        misc = import ./nix/misc.nix;
        rust = import ./nix/rust.nix;
        go = import ./nix/go.nix;
      };
      nixosModules.mina = import ./nix/modules/mina.nix inputs;
      nixosConfigurations.container = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = let
          PK = "B62qiZfzW27eavtPrnF6DeDSAKEjXuGFdkouC3T5STRa6rrYLiDUP2p";
          wallet = {
            box_primitive = "xsalsa20poly1305";
            ciphertext =
              "Dmq1Qd8uNbZRT1NT7zVbn3eubpn9Myx9Je9ZQGTKDxUv4BoPNmZAGox18qVfbbEUSuhT4ZGDt";
            nonce = "6pcvpWSLkMi393dT5VSLR6ft56AWKkCYRqJoYia";
            pw_primitive = "argon2i";
            pwdiff = [ 134217728 6 ];
            pwsalt = "ASoBkV3NsY7ZRuxztyPJdmJCiz3R";
          };
          wallet-file = builtins.toFile "mina-wallet" (builtins.toJSON wallet);
          wallet-file-pub = builtins.toFile "mina-wallet-pub" PK;
        in [
          self.nixosModules.mina
          {
            boot.isContainer = true;
            networking.useDHCP = false;
            networking.firewall.enable = false;

            services.mina = {
              enable = true;
              config = {
                "ledger" = {
                  "name" = "mina-demo";
                  "accounts" = [{
                    "pk" = PK;
                    "balance" = "66000";
                    "sk" = null;
                    "delegate" = null;
                  }];
                };
              };
              waitForRpc = false;
              external-ip = "0.0.0.0";
              generate-genesis-proof = true;
              seed = true;
              block-producer-key = "/var/lib/mina/wallets/store/${PK}";
              extraArgs = [
                "--demo-mode"
                "--proof-level"
                "none"
                "--run-snark-worker"
                "B62qjnkjj3zDxhEfxbn1qZhUawVeLsUr2GCzEz8m1MDztiBouNsiMUL"
                "-insecure-rest-server"
              ];
            };

            systemd.services.mina = {
              preStart = ''
                printf '{"genesis":{"genesis_state_timestamp":"%s"}}' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > /var/lib/mina/daemon.json
              '';
              environment = {
                MINA_TIME_OFFSET = "0";
                MINA_PRIVKEY_PASS = "";
              };
            };

            systemd.tmpfiles.rules = [
              "C /var/lib/mina/wallets/store/${PK}.pub 700 mina mina - ${wallet-file-pub}"
              "C /var/lib/mina/wallets/store/${PK}     700 mina mina - ${wallet-file}"
            ];
          }
        ];
      };
      pipeline = with flake-buildkite-pipeline.lib;
        let
          pushToRegistry = package: {
            command = runInEnv self.devShells.x86_64-linux.operations ''
              skopeo \
              copy \
              --insecure-policy \
              --dest-registry-token $(gcloud auth application-default print-access-token) \
              docker-archive:${self.packages.x86_64-linux.${package}} \
              docker://us-west2-docker.pkg.dev/o1labs-192920/nix-containers/${package}:$BUILDKITE_BRANCH
            '';
            label = "Upload ${package} to Google Artifact Registry";
            depends_on = [ "packages_x86_64-linux_${package}" ];
            plugins = [{ "thedyrt/skip-checkout#v0.1.1" = null; }];
            branches = [ "compatible" "develop" ];
          };
          publishDocs = {
            command = runInEnv self.devShells.x86_64-linux.operations ''
              gcloud auth activate-service-account --key-file "$GOOGLE_APPLICATION_CREDENTIALS"
              gsutil -m rsync -rd ${self.defaultPackage.x86_64-linux}/share/doc/html gs://mina-docs
            '';
            label = "Publish documentation to Google Storage";
            depends_on = [ "defaultPackage_x86_64-linux" ];
            branches = [ "develop" ];
            plugins = [{ "thedyrt/skip-checkout#v0.1.1" = null; }];
          };
        in {
          steps = flakeSteps {
            derivationCache = "https://storage.googleapis.com/mina-nix-cache";
            reproduceRepo = "mina";
            commonExtraStepConfig = {
              agents = [ "nix" ];
              plugins = [{ "thedyrt/skip-checkout#v0.1.1" = null; }];
            };
          } self ++ [
            (pushToRegistry "mina-docker")
            (pushToRegistry "mina-daemon-docker")
            publishDocs
          ];
        };
    } // utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system}.extend
          (nixpkgs.lib.composeManyExtensions ([
            (import nixpkgs-mozilla)
            (final: prev: {
              ocamlPackages_mina = requireSubmodules
                (import ./nix/ocaml.nix { inherit inputs pkgs; });

              rpmDebUtils = final.callPackage "${nix-utils}/utils/rpm-deb" { };
            })
          ] ++ builtins.attrValues self.overlays));
        inherit (pkgs) lib;
        mix-to-nix = pkgs.callPackage inputs.mix-to-nix { };
        nix-npm-buildPackage = pkgs.callPackage inputs.nix-npm-buildPackage {
          nodejs = pkgs.nodejs-16_x;
        };

        submodules = map builtins.head (builtins.filter lib.isList
          (map (builtins.match "	path = (.*)")
            (lib.splitString "\n" (builtins.readFile ./.gitmodules))));

        requireSubmodules = lib.warnIf (!builtins.all builtins.pathExists
          (map (x: ./. + "/${x}") submodules)) ''
            Some submodules are missing, you may get errors. Consider one of the following:
            - run nix/pin.sh and use "mina" flake ref;
            - use "git+file://$PWD?submodules=1";
            - use "git+https://github.com/minaprotocol/mina?submodules=1";
            - use non-flake commands like nix-build and nix-shell.
          '';

        checks = import ./nix/checks.nix inputs pkgs;

        ocamlPackages = pkgs.ocamlPackages_mina;

        debianPackages = pkgs.callPackage ./nix/debian.nix { };

        # Packages for the development environment that are not needed to build mina-dev.
        # For instance dependencies for tests.
        devShellPackages = [ pkgs.rosetta-cli ];
      in {

        # Jobs/Lint/Rust.dhall
        packages.trace-tool = pkgs.rustPlatform.buildRustPackage rec {
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
            goth = previous.goth.overrideAttrs
              (o: { preConfigure = "sed -i '/warnings_as_errors/d' mix.exs"; });
          });
        }).overrideAttrs (o: {
          # workaround for requiring --allow-import-from-derivation
          # during 'nix flake show'
          name = "coda_validation-0.1.0";
          version = "0.1.0";
        });

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

        # TODO: fix bs-platform build correctly
        packages.client_sdk = nix-npm-buildPackage.buildYarnPackage {
          name = "client_sdk";
          src = ./frontend/client_sdk;
          yarnPostLink = pkgs.writeScript "yarn-post-link" ''
            #!${pkgs.stdenv.shell}
            ls node_modules/bs-platform/lib/*.linux
            patchelf \
              --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
              --set-rpath "${pkgs.stdenv.cc.cc.lib}/lib" \
              ./node_modules/bs-platform/lib/*.linux ./node_modules/bs-platform/vendor/ninja/snapshot/*.linux ./node_modules/gentype/vendor-linux/gentype.exe
          '';
          yarnBuildMore = ''
            cp ${ocamlPackages.mina_client_sdk}/share/client_sdk/client_sdk.bc.js src
            yarn build
          '';
          installPhase = ''
            mkdir -p $out/share/client_sdk
            mv src/*.js $out/share/client_sdk
          '';
        };

        # snarkyjs
        packages.snarky_js = nix-npm-buildPackage.buildNpmPackage {
          src = ./src/lib/snarky_js_bindings/snarkyjs;
          preBuild = ''
            BINDINGS_PATH=./src/node_bindings
            mkdir -p "$BINDINGS_PATH"
            cp ${pkgs.plonk_wasm}/nodejs/plonk_wasm* "$BINDINGS_PATH"
            cp ${ocamlPackages.mina_client_sdk}/share/snarkyjs_bindings/snarky_js_node*.js "$BINDINGS_PATH"
            chmod -R 777 "$BINDINGS_PATH"

            # TODO: deduplicate from ./scripts/build-snarkyjs-node.sh
            # better error messages
            # TODO: find a less hacky way to make adjustments to jsoo compiler output
            # `s` is the jsoo representation of the error message string, and `s.c` is the actual JS string
            sed -i 's/function failwith(s){throw \[0,Failure,s\]/function failwith(s){throw joo_global_object.Error(s.c)/' "$BINDINGS_PATH"/snarky_js_node.bc.js
            sed -i 's/function invalid_arg(s){throw \[0,Invalid_argument,s\]/function invalid_arg(s){throw joo_global_object.Error(s.c)/' "$BINDINGS_PATH"/snarky_js_node.bc.js
            sed -i 's/return \[0,Exn,t\]/return joo_global_object.Error(t.c)/' "$BINDINGS_PATH"/snarky_js_node.bc.js
          '';
          npmBuild = "npm run build";
          # TODO: add snarky-run
          # TODO
          # checkPhase = "node ${./src/lib/snarky_js_bindings/tests/run-tests.mjs}"
        };

        packages.mina-signer = nix-npm-buildPackage.buildNpmPackage {
          src = ./frontend/mina-signer;
          preBuild = ''
            cp ${ocamlPackages.mina_client_sdk}/share/client_sdk/client_sdk.bc.js src
            chmod 0666 src/client_sdk.bc.js
            cp ${pkgs.plonk_wasm}/nodejs/plonk_wasm{.js,_bg.wasm} src
            chmod 0666 src/plonk_wasm{.js,_bg.wasm}
          '';
          npmBuild = "npm run build";
          doCheck = true;
          checkPhase = "npm test";
        };

        inherit ocamlPackages;

        packages = {
          inherit (ocamlPackages)
            mina mina_tests mina-ocaml-format mina_client_sdk test_executive;
          inherit (pkgs) libp2p_helper kimchi_bindings_stubs;
        };

        packages.mina-docker = pkgs.dockerTools.buildImage {
          name = "mina";
          copyToRoot = pkgs.buildEnv {
            name = "mina-image-root";
            paths = [ ocamlPackages.mina.out ];
            pathsToLink = [ "/bin" "/share" "/etc" ];
          };
        };
        packages.mina-daemon-docker = pkgs.dockerTools.buildImage {
          name = "mina-daemon";
          copyToRoot = pkgs.buildEnv {
            name = "mina-daemon-image-root";
            paths = [
              pkgs.dumb-init
              pkgs.coreutils
              pkgs.bashInteractive
              pkgs.python3
              pkgs.libp2p_helper
              ocamlPackages.mina.out
              ocamlPackages.mina.mainnet
              ocamlPackages.mina.genesis
              ocamlPackages.mina_build_config
              ocamlPackages.mina_daemon_scripts
            ];
            pathsToLink = [ "/bin" "/share" "/etc" ];
          };
          config = {
            env = [ "MINA_TIME_OFFSET=0" ];
            cmd = [ "/bin/dumb-init" "/entrypoint.sh" ];
          };
        };

        legacyPackages.musl = pkgs.pkgsMusl;
        legacyPackages.regular = pkgs;

        defaultPackage = ocamlPackages.mina;
        packages.default = ocamlPackages.mina;

        packages.mina-deb = debianPackages.mina;

        devShell = ocamlPackages.mina-dev.overrideAttrs (oa: {
          buildInputs = oa.buildInputs ++ devShellPackages;
          shellHook = ''
            ${oa.shellHook}
            unset MINA_COMMIT_DATE MINA_COMMIT_SHA1 MINA_BRANCH
          '';
        });
        devShells.default = self.devShell.${system};

        devShells.with-lsp = ocamlPackages.mina-dev.overrideAttrs (oa: {
          name = "mina-with-lsp";
          buildInputs = oa.buildInputs ++ [ pkgs.go_1_18 ] ++ devShellPackages;
          nativeBuildInputs = oa.nativeBuildInputs
            ++ [ ocamlPackages.ocaml-lsp-server ];
          shellHook = ''
            ${oa.shellHook}
            unset MINA_COMMIT_DATE MINA_COMMIT_SHA1 MINA_BRANCH
            # TODO: dead code doesn't allow us to have nice things
            pushd src/app/cli
            dune build @check
            popd
          '';
        });

        devShells.operations =
          pkgs.mkShell { packages = with pkgs; [ skopeo google-cloud-sdk ]; };

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
          MARLIN_PLONK_STUBS = "n";
          PLONK_WASM_WEB = "n";
          PLONK_WASM_NODEJS = "n";
        });

        inherit checks;
      });
}
