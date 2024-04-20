# A set defining OCaml parts&dependencies of Mina
{ inputs, ... }@args:
let
  opam-nix = inputs.opam-nix.lib.${pkgs.system};

  inherit (args) pkgs;

  inherit (builtins) filterSource path;

  inherit (pkgs.lib)
    hasPrefix last getAttrs filterAttrs optionalAttrs makeBinPath
    optionalString escapeShellArg;

  external-repo =
    opam-nix.makeOpamRepoRec ../src/external; # Pin external packages
  repos = [ external-repo inputs.opam-repository ];

  export = opam-nix.importOpam ../opam.export;
  external-packages =
    getAttrs [ "sodium" "capnp" "rpc_parallel" "async_kernel" "base58" ]
    (builtins.mapAttrs (_: last) (opam-nix.listRepo external-repo));

  difference = a: b:
    filterAttrs (name: _: !builtins.elem name (builtins.attrNames b)) a;

  export-installed = opam-nix.opamListToQuery export.installed;

  extra-packages = with implicit-deps; {
    dune-rpc = dune;
    dyn = dune;
    fiber = dune;
    ocaml-lsp-server = "1.11.6";
    ocaml-system = ocaml;
    ocamlformat-rpc-lib = "0.22.4";
    omd = "1.3.1";
    ordering = dune;
    pp = "1.1.2";
    ppx_yojson_conv_lib = "v0.15.0";
    stdune = dune;
    xdg = dune;
  };

  implicit-deps = export-installed // external-packages;

  pins = builtins.mapAttrs (name: pkg: { inherit name; } // pkg) export.package;

  scope = opam-nix.applyOverlays opam-nix.__overlays (opam-nix.defsToScope pkgs
    ((opam-nix.queryToDefs repos (extra-packages // implicit-deps)) // pins));

  installedPackageNames =
    map (x: (opam-nix.splitNameVer x).name) (builtins.attrNames implicit-deps);

  sourceInfo = inputs.self.sourceInfo or { };

  external-libs = with pkgs;
    [ zlib bzip2 gmp openssl libffi ]
    ++ lib.optional (!(stdenv.isDarwin && stdenv.isAarch64)) jemalloc;

  filtered-src = with inputs.nix-filter.lib;
    filter {
      root = ../.;
      include =
        [ (inDirectory "src") "dune" "dune-project" "./graphql_schema.json" ];
    };

  dockerfiles-scripts = with inputs.nix-filter.lib;
    filter {
      root = ../.;
      include = [ (inDirectory "dockerfiles") ];
    };

  overlay = self: super:
    let
      ocaml-libs = builtins.attrValues (getAttrs installedPackageNames self);

      # This is needed because
      # - lld package is not wrapped to pick up the correct linker flags
      # - bintools package also includes as which is incompatible with gcc
      lld_wrapped = pkgs.writeShellScriptBin "ld.lld"
        ''${pkgs.llvmPackages.bintools}/bin/ld.lld "$@"'';

      wrapMina = let
        commit_sha1 = inputs.self.sourceInfo.rev or "<dirty>";
        commit_date = inputs.self.sourceInfo.lastModifiedDate or "<unknown>";
      in package:
      { deps ? [ pkgs.gnutar pkgs.gzip ], }:
      pkgs.runCommand "${package.name}-release" {
        buildInputs = [ pkgs.makeBinaryWrapper pkgs.xorg.lndir ];
        outputs = package.outputs;
      } (map (output: ''
        mkdir -p ${placeholder output}
        lndir -silent ${package.${output}} ${placeholder output}
        for i in $(find -L "${placeholder output}/bin" -type f); do
          wrapProgram "$i" \
            --prefix PATH : ${makeBinPath deps} \
            --set MINA_LIBP2P_HELPER_PATH ${pkgs.libp2p_helper}/bin/libp2p_helper \
            --set MINA_COMMIT_SHA1 ${escapeShellArg commit_sha1} \
            --set MINA_COMMIT_DATE ${escapeShellArg commit_date} \
            --set MINA_BRANCH "''${MINA_BRANCH-<unknown due to nix build>}"
        done
      '') package.outputs);

      runMinaCheck = { name ? "check", extraInputs ? [ ], extraArgs ? { } }:
        check:
        self.mina-dev.overrideAttrs (oa:
          {
            pname = "mina-${name}";
            buildInputs = oa.buildInputs ++ extraInputs;
            buildPhase = check;
            outputs = [ "out" ];
            installPhase = "touch $out";
          } // extraArgs);
    in {
      # https://github.com/Drup/ocaml-lmdb/issues/41
      lmdb = super.lmdb.overrideAttrs
        (oa: { buildInputs = oa.buildInputs ++ [ self.conf-pkg-config ]; });

      sodium = super.sodium.overrideAttrs (_: {
        NIX_CFLAGS_COMPILE = "-I${pkgs.sodium-static.dev}/include";
        propagatedBuildInputs = [ pkgs.sodium-static ];
        preBuild = ''
          export LD_LIBRARY_PATH="${super.ctypes}/lib/ocaml/${super.ocaml.version}/site-lib/ctypes";
        '';
      });

      rpc_parallel = super.rpc_parallel.overrideAttrs
        (oa: { buildInputs = oa.buildInputs ++ [ self.ctypes ]; });

      mina-dev = pkgs.stdenv.mkDerivation ({
        pname = "mina";
        version = "dev";
        # Prevent unnecessary rebuilds on non-source changes
        src = filtered-src;

        # TODO, get this from somewhere
        MARLIN_REPO_SHA = "<unknown>";
        MINA_COMMIT_SHA1 = "<unknown>";
        MINA_COMMIT_DATE = "<unknown>";
        MINA_BRANCH = "<unknown>";

        NIX_LDFLAGS =
          optionalString (pkgs.stdenv.isDarwin && pkgs.stdenv.isAarch64)
          "-F${pkgs.darwin.apple_sdk.frameworks.CoreFoundation}/Library/Frameworks -framework CoreFoundation";

        buildInputs = ocaml-libs ++ external-libs;
        nativeBuildInputs = [
          self.dune
          self.ocamlfind
          self.odoc
          lld_wrapped
          pkgs.capnproto
          pkgs.removeReferencesTo
          pkgs.fd
        ] ++ ocaml-libs;

        # todo: slimmed rocksdb
        MINA_ROCKSDB = "${pkgs.rocksdb}/lib/librocksdb.a";
        GO_CAPNP_STD = "${pkgs.go-capnproto2.src}/std";

        MARLIN_PLONK_STUBS = "${pkgs.marlin_plonk_bindings_stubs}/lib";
        DISABLE_CHECK_OPAM_SWITCH = "true";

        MINA_VERSION_IMPLEMENTATION = "mina_version.runtime";

        configurePhase = ''
          export MINA_ROOT="$PWD"
          export -f patchShebangs stopNest isScript
          fd . --type executable -x bash -c "patchShebangs {}"
          export -n patchShebangs stopNest isScript
          # Get the mina version at runtime, from the wrapper script. Used to prevent rebuilding everything every time commit info changes.
          sed -i "s/default_implementation [^)]*/default_implementation $MINA_VERSION_IMPLEMENTATION/" src/lib/mina_version/dune
        '';

        buildPhase = ''
          dune build --display=short \
            src/app/logproc/logproc.exe \
            src/app/cli/src/mina.exe \
            src/app/batch_txn_tool/batch_txn_tool.exe \
            src/app/cli/src/mina_testnet_signatures.exe \
            src/app/cli/src/mina_mainnet_signatures.exe \
            src/app/rosetta/rosetta.exe \
            src/app/rosetta/rosetta_testnet_signatures.exe \
            src/app/rosetta/rosetta_mainnet_signatures.exe \
            src/app/generate_keypair/generate_keypair.exe \
            src/lib/mina_base/sample_keypairs.json \
            -j$NIX_BUILD_CORES
          dune exec src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe -- --genesis-dir _build/coda_cache_dir
          dune build @doc || true
        '';

        outputs =
          [ "out" "generate_keypair" "mainnet" "testnet" "genesis" "sample" "batch_txn_tool"];

        installPhase = ''
          mkdir -p $out/bin $sample/share/mina $out/share/doc $generate_keypair/bin $mainnet/bin $testnet/bin $genesis/bin $genesis/var/lib/coda $batch_txn_tool/bin
          mv _build/coda_cache_dir/genesis* $genesis/var/lib/coda
          pushd _build/default
          cp src/app/cli/src/mina.exe $out/bin/mina
          cp src/app/logproc/logproc.exe $out/bin/logproc
          cp src/app/rosetta/rosetta.exe $out/bin/rosetta
          cp src/app/batch_txn_tool/batch_txn_tool.exe $batch_txn_tool/bin/batch_txn_tool
          cp src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe $genesis/bin/runtime_genesis_ledger
          cp src/app/cli/src/mina_mainnet_signatures.exe $mainnet/bin/mina_mainnet_signatures
          cp src/app/rosetta/rosetta_mainnet_signatures.exe $mainnet/bin/rosetta_mainnet_signatures
          cp src/app/cli/src/mina_testnet_signatures.exe $testnet/bin/mina_testnet_signatures
          cp src/app/rosetta/rosetta_testnet_signatures.exe $testnet/bin/rosetta_testnet_signatures
          cp src/app/generate_keypair/generate_keypair.exe $generate_keypair/bin/generate_keypair
          cp -R _doc/_html $out/share/doc/html
          # cp src/lib/mina_base/sample_keypairs.json $sample/share/mina
          popd
          remove-references-to -t $(dirname $(dirname $(command -v ocaml))) {$out/bin/*,$mainnet/bin/*,$testnet/bin*,$genesis/bin/*,$generate_keypair/bin/*}
        '';
        shellHook =
          "export MINA_LIBP2P_HELPER_PATH=${pkgs.libp2p_helper}/bin/libp2p_helper";
      } // optionalAttrs pkgs.stdenv.isDarwin {
        OCAMLPARAM = "_,cclib=-lc++";
      });

      mina = wrapMina self.mina-dev { };

      mainnet-pkg = self.mina-dev.overrideAttrs (s: {
        version = "mainnet";
        DUNE_PROFILE = "mainnet";
      });

      mainnet = wrapMina self.mainnet-pkg { };

      devnet-pkg = self.mina-dev.overrideAttrs (s: {
        version = "devnet";
        DUNE_PROFILE = "devnet";
      });

      devnet = wrapMina self.devnet-pkg { };

      mina_tests = runMinaCheck {
        name = "tests";
        extraArgs = {
          MINA_LIBP2P_HELPER_PATH = "${pkgs.libp2p_helper}/bin/libp2p_helper";
          TZDIR = "${pkgs.tzdata}/share/zoneinfo";
        };
        extraInputs = [ pkgs.ephemeralpg ];
      } ''
        dune build graphql_schema.json --display=short
        export MINA_TEST_POSTGRES="$(pg_tmp -w 1200)"
        psql "$MINA_TEST_POSTGRES" < src/app/archive/create_schema.sql
        # TODO: investigate failing tests, ideally we should run all tests in src/
        dune runtest src/app/archive src/lib/command_line_tests --display=short
      '';

      mina-ocaml-format = runMinaCheck { name = "ocaml-format"; } ''
        dune exec --profile=dev src/app/reformat/reformat.exe -- -path . -check
      '';

      mina_client_sdk = self.mina-dev.overrideAttrs (_: {
        pname = "mina_client_sdk";
        version = "dev";
        src = filtered-src;

        outputs = [ "out" ];

        checkInputs = [ pkgs.nodejs ];

        MINA_VERSION_IMPLEMENTATION = "mina_version.dummy";

        buildPhase = ''
          export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$opam__zarith__lib/zarith"
          dune build --display=short src/app/client_sdk/client_sdk.bc.js --profile=nonconsensus_mainnet
        '';

        doCheck = true;
        checkPhase = ''
          node src/app/client_sdk/tests/run_unit_tests.js

          dune build src/app/client_sdk/tests/test_signatures.exe
          ./_build/default/src/app/client_sdk/tests/test_signatures.exe > nat.consensus.json
          node src/app/client_sdk/tests/test_signatures.js > js.nonconsensus.json
          if ! diff -q nat.consensus.json js.nonconsensus.json; then
            echo "Consensus and JS code generate different signatures";
            exit 1
          fi
        '';

        installPhase = ''
          mkdir -p $out/share/client_sdk
          mv _build/default/src/app/client_sdk/client_sdk.bc.js $out/share/client_sdk
        '';
      });

      mina_build_config = pkgs.stdenv.mkDerivation {
        pname = "mina_build_config";
        version = "dev";
        src = filtered-src;
        nativeBuildInputs = [ pkgs.rsync ];

        installPhase = ''
          mkdir -p $out/etc/coda/build_config
          cp src/config/mainnet.mlh $out/etc/coda/build_config/BUILD.mlh
          rsync -Huav src/config/* $out/etc/coda/build_config/.
        '';
      };

      mina_daemon_scripts = pkgs.stdenv.mkDerivation {
        pname = "mina_daemon_scripts";
        version = "dev";
        src = dockerfiles-scripts;
        buildInputs = [ pkgs.bash pkgs.python3 ];
        installPhase = ''
          mkdir -p $out/healthcheck $out/entrypoint.d
          mv dockerfiles/scripts/healthcheck-utilities.sh $out/healthcheck/utilities.sh
          mv dockerfiles/scripts/cron_job_dump_ledger.sh $out/cron_job_dump_ledger.sh
          mv dockerfiles/scripts/daemon-entrypoint.sh $out/entrypoint.sh
          mv dockerfiles/puppeteer-context/* $out/
        '';
      };

      test_executive-dev = self.mina-dev.overrideAttrs (oa: {
        pname = "mina-test_executive";
        src = filtered-src;
        outputs = [ "out" ];

        buildPhase = ''
          dune build --profile=integration_tests src/app/test_executive/test_executive.exe src/app/logproc/logproc.exe -j$NIX_BUILD_CORES
        '';
        installPhase = ''
          mkdir -p $out/bin
          mv _build/default/src/app/test_executive/test_executive.exe $out/bin/test_executive
          mv _build/default/src/app/logproc/logproc.exe $out/bin/logproc
        '';
      });

      test_executive = wrapMina self.test_executive-dev { };
    };
in scope.overrideScope' overlay
