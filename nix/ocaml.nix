{ inputs, static ? false, ... }@args:
let
  opam-nix = inputs.opam-nix.lib.${pkgs.system};

  pkgs = if static then args.pkgs.pkgsMusl else args.pkgs;

  inherit (builtins) filterSource path;

  inherit (pkgs.lib) hasPrefix;

  external-repo =
    opam-nix.makeOpamRepoRec ../src/external; # Pin external packages
  repos = [ external-repo inputs.opam-repository ];

  export = opam-nix.importOpam ../src/opam.export;
  external-packages = pkgs.lib.getAttrs [
    "sodium"
    "capnp"
    "rpc_parallel"
    "async_kernel"
    "base58"
  ] (builtins.mapAttrs (_: pkgs.lib.last) (opam-nix.listRepo external-repo));

  difference = a: b:
    pkgs.lib.filterAttrs (name: _: !builtins.elem name (builtins.attrNames b))
    a;

  extra-packages = {
    ocaml-lsp-server = "1.4.1";
    ocaml-system = "4.11.2";
    ppx_yojson_conv_lib = "v0.15.0";
  };

  implicit-deps = (opam-nix.opamListToQuery export.installed)
    // external-packages;

  pins = builtins.mapAttrs (name: pkg: { inherit name; } // pkg) export.package;

  scope = opam-nix.applyOverlays opam-nix.__overlays (opam-nix.defsToScope pkgs
    ((opam-nix.queryToDefs repos (extra-packages // implicit-deps)) // pins));

  installedPackageNames =
    map (x: (opam-nix.splitNameVer x).name) (builtins.attrNames implicit-deps);

  sourceInfo = inputs.self.sourceInfo or { };
  dds = x: x.overrideAttrs (o: { dontDisableStatic = true; });

  external-libs = with pkgs;
    if static then
      map dds [
        (zlib.override { splitStaticOutput = false; })
        (bzip2.override { linkStatic = true; })
        (jemalloc)
        (gmp.override { withStatic = true; })
        (openssl.override { static = true; })
        libffi
      ]
    else [
      zlib
      bzip2
      jemalloc
      gmp
      openssl
      libffi
    ];

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
      ocaml-libs =
        builtins.attrValues (pkgs.lib.getAttrs installedPackageNames self);

      # This is needed because
      # - lld package is not wrapped to pick up the correct linker flags
      # - bintools package also includes as which is incompatible with gcc
      lld_wrapped = pkgs.writeShellScriptBin "ld.lld"
        ''${pkgs.llvmPackages.bintools}/bin/ld.lld "$@"'';

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
        #MINA_COMMIT_DATE =
        #  if sourceInfo ? rev then sourceInfo.lastModifiedDate else "<unknown>";
        #MINA_COMMIT_SHA1 = sourceInfo.rev or "DIRTY";
        MINA_COMMIT_DATE = "__commit_date_";
        MINA_COMMIT_SHA1 = "__commit_sha1___________________________";
        MINA_BRANCH = "<unknown>";

        buildInputs = ocaml-libs ++ external-libs;
        nativeBuildInputs = [
          self.dune
          self.ocamlfind
          lld_wrapped
          pkgs.capnproto
          pkgs.removeReferencesTo
        ] ++ ocaml-libs;

        # todo: slimmed rocksdb
        MINA_ROCKSDB = "${pkgs.rocksdb}/lib/librocksdb.a";
        GO_CAPNP_STD = "${pkgs.go-capnproto2.src}/std";

        MARLIN_PLONK_STUBS = "${pkgs.marlin_plonk_bindings_stubs}/lib";
        configurePhase = ''
          export MINA_ROOT="$PWD"
          patchShebangs .
        '';

        buildPhase = ''
          dune build --display=short \
            src/app/logproc/logproc.exe \
            src/app/cli/src/mina.exe \
            src/app/cli/src/mina_testnet_signatures.exe \
            src/app/cli/src/mina_mainnet_signatures.exe \
            src/app/rosetta/rosetta.exe \
            src/app/rosetta/rosetta_testnet_signatures.exe \
            src/app/rosetta/rosetta_mainnet_signatures.exe \
            src/app/generate_keypair/generate_keypair.exe \
            src/lib/mina_base/sample_keypairs.json \
            -j$NIX_BUILD_CORES
          dune exec src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe -- --genesis-dir _build/coda_cache_dir
        '';

        outputs =
          [ "out" "generate_keypair" "mainnet" "testnet" "genesis" "sample" ];

        installPhase = ''
          mkdir -p $out/bin $sample/share/mina $generate_keypair/bin $mainnet/bin $testnet/bin $genesis/bin $genesis/var/lib/coda
          mv _build/default/src/app/cli/src/mina.exe $out/bin/mina
          mv _build/default/src/app/logproc/logproc.exe $out/bin/logproc
          mv _build/default/src/app/rosetta/rosetta.exe $out/bin/rosetta
          mv _build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe $genesis/bin/runtime_genesis_ledger
          mv _build/default/src/app/cli/src/mina_mainnet_signatures.exe $mainnet/bin/mina_mainnet_signatures
          mv _build/default/src/app/rosetta/rosetta_mainnet_signatures.exe $mainnet/bin/rosetta_mainnet_signatures
          mv _build/default/src/app/cli/src/mina_testnet_signatures.exe $testnet/bin/mina_testnet_signatures
          mv _build/default/src/app/rosetta/rosetta_testnet_signatures.exe $testnet/bin/rosetta_testnet_signatures
          mv _build/coda_cache_dir/genesis* $genesis/var/lib/coda
          mv _build/default/src/lib/mina_base/sample_keypairs.json $sample/share/mina
          mv _build/default/src/app/generate_keypair/generate_keypair.exe $generate_keypair/bin/generate_keypair
          remove-references-to -t $(dirname $(dirname $(command -v ocaml))) {$out/bin/*,$mainnet/bin/*,$testnet/bin*,$genesis/bin/*,$generate_keypair/bin/*}
        '';
        shellHook = "export MINA_LIBP2P_HELPER_PATH=${pkgs.libp2p_helper}/bin/libp2p_helper";
      } // pkgs.lib.optionalAttrs static { OCAMLPARAM = "_,ccopt=-static"; }
        // pkgs.lib.optionalAttrs pkgs.stdenv.isDarwin {
          OCAMLPARAM = "_,cclib=-lc++";
        });

      mina = let
        commit_sha1 =
          inputs.self.sourceInfo.rev or "<unknown>                               ";
        commit_date =
          inputs.self.sourceInfo.lastModifiedDate or "<unknown>     ";
        inherit (pkgs.lib) makeBinPath;
      in pkgs.runCommand "mina-release" {
        buildInputs = [ pkgs.makeWrapper ];
        outputs = self.mina-dev.outputs;
      } (map (output: ''
        cp -R ${self.mina-dev.${output}} ${placeholder output}
        chmod 700 ${placeholder output} -R
        for i in $(find "${placeholder output}/bin" -type f); do
          sed 's/__commit_sha1___________________________/${commit_sha1}/' -i "$i"
          sed 's/__commit_date_/${commit_date}/' -i "$i"
          wrapProgram "$i" \
            --prefix PATH : ${makeBinPath [ pkgs.gnutar pkgs.gzip ]} \
            --set MINA_LIBP2P_HELPER_PATH ${pkgs.libp2p_helper}/bin/libp2p_helper
        done
      '') self.mina-dev.outputs);

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

      mina_ocaml_format = runMinaCheck { name = "ocaml-format"; } ''
        dune exec --profile=dev src/app/reformat/reformat.exe -- -path . -check
      '';

      mina_client_sdk = self.mina-dev.overrideAttrs (_: {
        pname = "mina_client_sdk";
        version = "dev";
        src = filtered-src;

        outputs = [ "out" ];

        checkInputs = [ pkgs.nodejs ];

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

      mina_integration_tests = self.mina-dev.overrideAttrs (oa: {
        pname = "mina_integration_tests";
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
    };
in scope.overrideScope' overlay
