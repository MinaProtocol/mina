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

  inputs.flockenzeit.url = "github:balsoft/Flockenzeit";

  outputs = inputs@{ self, nixpkgs, utils, mix-to-nix, nix-npm-buildPackage
    , opam-nix, opam-repository, nixpkgs-mozilla, flake-buildkite-pipeline
    , nix-utils, flockenzeit, ... }:
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
        (map (x: builtins.pathExists ./${x} && builtins.readDir ./${x} != { }) submodules)) ''
          Some submodules are missing, you may get errors. Consider one of the following:
          - run ${command "nix/pin.sh"} and use "${ref "mina"}" flake ref, e.g. ${command "nix develop mina"} or ${command "nix build mina"};
          - use "${ref "git+file://$PWD?submodules=1"}";
          - use "${ref "git+https://github.com/minaprotocol/mina?submodules=1"}";
          - use non-flake commands like ${command "nix-build"} and ${command "nix-shell"}.
        '';
    in {
      overlays = {
        misc = import ./nix/misc.nix;
        rust = import ./nix/rust.nix;
        go = import ./nix/go.nix;
        javascript = import ./nix/javascript.nix;
        ocaml = final: prev: {
          ocamlPackages_mina = requireSubmodules (import ./nix/ocaml.nix {
            inherit inputs;
            pkgs = final;
          });
        };
      };

      nixosModules.mina = import ./nix/modules/mina.nix inputs;
      # Mina Demo container
      # Use `nixos-container create --flake mina`
      # Taken from docs/demo.md
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
      # Buildkite pipeline for the Nix CI
      pipeline = with flake-buildkite-pipeline.lib;
        let
          inherit (nixpkgs) lib;
          dockerUrl = package: tag:
            "us-west2-docker.pkg.dev/o1labs-192920/nix-containers/${package}:${tag}";

          pushToRegistry = package: {
            command = runInEnv self.devShells.x86_64-linux.operations ''
              ${self.packages.x86_64-linux.${package}} | gzip --fast | \
                skopeo \
                  copy \
                  --insecure-policy \
                  --dest-registry-token $(gcloud auth application-default print-access-token) \
                  docker-archive:/dev/stdin \
                  docker://${dockerUrl package "$BUILDKITE_COMMIT"}
              if [[ develop == "$BUILDKITE_BRANCH" ]]; then
                skopeo \
                  copy \
                  --insecure-policy \
                  --dest-registry-token $(gcloud auth application-default print-access-token) \
                  docker://${dockerUrl package "$BUILDKITE_COMMIT"} \
                  docker://${dockerUrl package "$BUILDKITE_BRANCH"}
              fi
            '';
            label =
              "Assemble and upload ${package} to Google Artifact Registry";
            depends_on = [ "packages_x86_64-linux_${package}" ];
            plugins = [{ "thedyrt/skip-checkout#v0.1.1" = null; }];
            key = "push_${package}";
          };
          # Publish the documentation generated by ocamldoc to s3
          publishDocs = {
            command = runInEnv self.devShells.x86_64-linux.operations ''
              gcloud auth activate-service-account --key-file "$GOOGLE_APPLICATION_CREDENTIALS"
              gsutil -m rsync -rd ${self.packages.x86_64-linux.default}/share/doc/html gs://mina-docs
            '';
            label = "Publish documentation to Google Storage";
            depends_on = [ "packages_x86_64-linux_default" ];
            branches = [ "develop" ];
            plugins = [{ "thedyrt/skip-checkout#v0.1.1" = null; }];
          };
          runIntegrationTest = test:
            { with-archive ? false }: {
              command =
                runInEnv self.devShells.x86_64-linux.integration-tests ''
                  export GOOGLE_CLOUD_KEYFILE_JSON=$AUTOMATED_VALIDATION_SERVICE_ACCOUNT
                  export GCLOUD_API_KEY=$(cat $INTEGRATION_TEST_LOGS_GCLOUD_API_KEY_PATH)
                  source $INTEGRATION_TEST_CREDENTIALS
                  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
                  export KUBE_CONFIG_PATH=$$HOME/.kube/config
                  gcloud auth activate-service-account --key-file=$AUTOMATED_VALIDATION_SERVICE_ACCOUNT automated-validation@o1labs-192920.iam.gserviceaccount.com --project o1labs-192920
                  gcloud container clusters get-credentials --region us-west1 mina-integration-west1
                  kubectl config use-context gke_o1labs-192920_us-west1_mina-integration-west1
                  test_executive cloud ${test} \
                  --mina-image=${
                    dockerUrl "mina-image-full" "$BUILDKITE_COMMIT"
                  } \
                  ${lib.optionalString with-archive "--archive-image=${
                    dockerUrl "mina-archive-image-full" "$BUILDKITE_COMMIT"
                  }"}
                '';
              label = "Run ${test} integration test";
              depends_on = [ "push_mina-image-full" ]
                ++ lib.optional with-archive "push_mina-archive-image-full";
              "if" = ''build.pull_request.labels includes "nix-integration-tests"'';
              retry = {
                automatic = [
                  {
                    exit_status = "*";
                    limit = 3;
                  }
                ];
              };
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
            (pushToRegistry "mina-image-slim")
            (pushToRegistry "mina-image-full")
            (pushToRegistry "mina-archive-image-full")
            publishDocs
            (runIntegrationTest "peers-reliability" { })
            (runIntegrationTest "chain-reliability" { })
            (runIntegrationTest "payment" { with-archive = true; })
            (runIntegrationTest "delegation" { with-archive = true; })
            (runIntegrationTest "gossip-consis" { })
            # FIXME: opt-block-prod test fails.
            # This has been disabled in the "old" CI for a while.
            # (runIntegrationTest "opt-block-prod" { })
            (runIntegrationTest "medium-bootstrap" { })
            (runIntegrationTest "zkapps" { with-archive = true; })
            (runIntegrationTest "zkapps-timing" { with-archive = true; })
          ];
        };
    } // utils.lib.eachDefaultSystem (system:
      let
        # nixpkgs with all relevant overlays applied
        pkgs = nixpkgs.legacyPackages.${system}.extend
          (nixpkgs.lib.composeManyExtensions ([
            (import nixpkgs-mozilla)
            nix-npm-buildPackage.overlays.default
            (final: prev: {
              rpmDebUtils = final.callPackage "${nix-utils}/utils/rpm-deb" { };
              mix-to-nix = pkgs.callPackage inputs.mix-to-nix { };
              nix-npm-buildPackage =
                pkgs.callPackage inputs.nix-npm-buildPackage {
                  nodejs = pkgs.nodejs-16_x;
                };
            })
          ] ++ builtins.attrValues self.overlays));

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
        devShellPackages = with pkgs; [ rosetta-cli wasm-pack nodejs binaryen ];
      in {
        inherit ocamlPackages;

        # Main user-facing binaries.
        packages = rec {
          inherit (ocamlPackages)
            mina mina_tests mina-ocaml-format test_executive;
          inherit (pkgs)
            libp2p_helper kimchi_bindings_stubs snarky_js leaderboard
            validation trace-tool zkapp-cli;
          inherit (dockerImages)
            mina-image-slim mina-image-full mina-archive-image-full;
          mina-deb = debianPackages.mina;
          default = mina;
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

        devShells.operations = pkgs.mkShell {
          name = "mina-operations";
          packages = with pkgs; [ skopeo gzip google-cloud-sdk ];
        };

        # TODO: think about rust toolchain in the dev shell
        devShells.integration-tests = pkgs.mkShell {
          name = "mina-integration-tests";
          shellHook = ''
            export MINA_BRANCH=$()
          '';
          buildInputs = [
            self.packages.${system}.test_executive
            pkgs.kubectl
            pkgs.google-cloud-sdk
            pkgs.terraform
            pkgs.curl
          ];
        };
        packages.impure-shell =
          (import ./nix/impure-shell.nix pkgs).inputDerivation;

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
      });
}
