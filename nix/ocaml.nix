# A set defining OCaml parts&dependencies of Minaocamlnix
{ inputs, ... }@args:
let
  opam-nix = inputs.opam-nix.lib.${pkgs.system};

  inherit (args) pkgs;
  inherit (pkgs.lib)
    hasPrefix last getAttrs filterAttrs optionalAttrs makeBinPath optionalString
    escapeShellArg;

  repos = with inputs; [ o1-opam-repository opam-repository ];

  export = opam-nix.importOpam ../opam.export;

  # Dependencies required by every Mina package:
  # Packages which are `installed` in the export.
  # These are all the transitive ocaml dependencies of Mina.
  implicit-deps =
    builtins.removeAttrs (opam-nix.opamListToQuery export.installed)
    [ "check_opam_switch" ];

  # Extra packages which are not in opam.export but useful for development, such as an LSP server.
  extra-packages = with implicit-deps; {
    dune-rpc = "3.5.0";
    dyn = "3.5.0";
    fiber = "3.5.0";
    chrome-trace = "3.5.0";
    ocaml-lsp-server = "1.15.1-4.14";
    ocamlc-loc = "3.5.0";
    ocaml-system = ocaml;
    ocamlformat-rpc-lib = "0.22.4";
    omd = "1.3.2";
    ordering = "3.5.0";
    pp = "1.1.2";
    ppx_yojson_conv_lib = "v0.15.0";
    stdune = "3.5.0";
    xdg = dune;
  };

  implicit-deps-overlay = self: super:
    (if pkgs.stdenv.isDarwin then {
      async_ssl = super.async_ssl.overrideAttrs {
        NIX_CFLAGS_COMPILE =
          "-Wno-implicit-function-declaration -Wno-incompatible-function-pointer-types";
      };
    } else
      { }) // {
        # https://github.com/Drup/ocaml-lmdb/issues/41
        lmdb = super.lmdb.overrideAttrs
          (oa: { buildInputs = oa.buildInputs ++ [ self.conf-pkg-config ]; });

        # Doesn't have an explicit dependency on ctypes-foreign
        ctypes = super.ctypes.overrideAttrs
          (oa: { buildInputs = oa.buildInputs ++ [ self.ctypes-foreign ]; });

        # Can't find sodium-static and ctypes
        sodium = super.sodium.overrideAttrs {
          NIX_CFLAGS_COMPILE = "-I${pkgs.sodium-static.dev}/include";
          propagatedBuildInputs = [ pkgs.sodium-static ];
          preBuild = ''
            export LD_LIBRARY_PATH="${super.ctypes}/lib/ocaml/${super.ocaml.version}/site-lib/ctypes";
          '';
        };

        rocksdb_stubs = super.rocksdb_stubs.overrideAttrs {
          MINA_ROCKSDB = "${pkgs.rocksdb-mina}/lib/librocksdb.a";
        };

        # This is needed because
        # - lld package is not wrapped to pick up the correct linker flags
        # - bintools package also includes as which is incompatible with gcc
        lld_wrapped = pkgs.writeShellScriptBin "ld.lld"
          ''${pkgs.llvmPackages.bintools}/bin/ld.lld "$@"'';

        core =
          super.core.overrideAttrs { propagatedBuildInputs = [ pkgs.tzdata ]; };
      };

  scope =
    opam-nix.applyOverlays (opam-nix.__overlays ++ [ implicit-deps-overlay ])
    (opam-nix.defsToScope pkgs { }
      (opam-nix.queryToDefs repos (extra-packages // implicit-deps)));

  installedPackageNames =
    map (x: (opam-nix.splitNameVer x).name) (builtins.attrNames implicit-deps);

  sourceInfo = inputs.self.sourceInfo or { };

  # "System" dependencies required by all Mina packages
  external-libs = with pkgs;
    [ zlib bzip2 gmp openssl libffi ]
    ++ lib.optional (!(stdenv.isDarwin && stdenv.isAarch64)) jemalloc;

  dune-nix = inputs.dune-nix.lib.${pkgs.system};

  base-libs = dune-nix.squashOpamNixDeps scope.ocaml.version
    (pkgs.lib.attrVals (builtins.attrNames implicit-deps) scope);

  dune-description = pkgs.stdenv.mkDerivation {
    pname = "dune-description";
    version = "dev";
    src = pkgs.lib.sources.sourceFilesBySuffices ../src [
      "dune"
      "dune-project"
      ".inc"
      ".opam"
    ];
    phases = [ "unpackPhase" "buildPhase" ];
    buildPhase = ''
      files=$(ls)
      mkdir src
      mv $files src
      cp ${../dune} dune
      cp ${../dune-project} dune-project
      ${
        inputs.describe-dune.defaultPackage.${pkgs.system}
      }/bin/describe-dune > $out
    '';
  };

  duneDescLoaded = builtins.fromJSON (builtins.readFile dune-description);
  info = dune-nix.info duneDescLoaded;
  allDeps = dune-nix.allDeps info;
  commonOverrides = {
    DUNE_PROFILE = "dev";
    buildInputs = [ base-libs ] ++ external-libs;
    nativeBuildInputs = [ ];
  };
  packageHasSrcApp =
    dune-nix.packageHasUnit ({ src, ... }: pkgs.lib.hasPrefix "src/app/" src);
  sqlSchemaFiles = with inputs.nix-filter.lib;
    filter {
      root = ../src/app/archive;
      include = [ (matchExt "sql") ];
    };

  granularBase =
    dune-nix.outputs' commonOverrides ./.. allDeps info packageHasSrcApp;
  vmOverlays = let
    commit = inputs.self.sourceInfo.rev or "<dirty>";
    commitShort = builtins.substring 0 8 commit;
    cmdLineTest = ''
      mina --version
      mv _build/default/src/test/command_line_tests/command_line_tests.exe tests.exe
      chmod +x tests.exe
      export TMPDIR=tmp # to align with janestreet core library
      mkdir -p $TMPDIR
      export MINA_LIBP2P_PASS="naughty blue worm"
      export MINA_PRIVKEY_PASS="naughty blue worm"
      export MINA_KEYS_PATH=genesis_ledgers
      mkdir -p $MINA_KEYS_PATH
      echo '{"ledger":{"accounts":[]}}' > $MINA_KEYS_PATH/config_${commitShort}.json
      ./tests.exe --mina-path mina
    '';
  in [
    (dune-nix.testWithVm { } "mina_net2" [ pkgs.libp2p_helper ])
    (dune-nix.testWithVm { } "__src-lib-mina_net2-tests__"
      [ pkgs.libp2p_helper ])
    (self:
      dune-nix.testWithVm' cmdLineTest { } "__src-test-command_line_tests__" [
        self.pkgs.cli
        pkgs.libp2p_helper
      ] self)
    (dune-nix.testWithVm { } "__src-lib-staged_ledger-test__" [ ])
  ];
  granularCustom = _: super:
    let
      makefileTest = pkg:
        let src = info.pseudoPackages."${pkg}";
        in dune-nix.makefileTest ./.. pkg src;
      marlinPlonkStubs = {
        MARLIN_PLONK_STUBS = "${pkgs.kimchi_bindings_stubs}";
      };
      childProcessesTester = pkgs.writeShellScriptBin "mina-tester.sh"
        (builtins.readFile ../src/lib/child_processes/tester.sh);
      withLibp2pHelper = (s: {
        nativeBuildInputs = s.nativeBuildInputs ++ [ pkgs.libp2p_helper ];
      });
    in {
      pkgs.mina_version = super.pkgs.mina_version.overrideAttrs {
        MINA_COMMIT_SHA1 = inputs.self.sourceInfo.rev or "<dirty>";
      };
      pkgs.kimchi_bindings =
        super.pkgs.kimchi_bindings.overrideAttrs marlinPlonkStubs;
      pkgs.kimchi_types =
        super.pkgs.kimchi_types.overrideAttrs marlinPlonkStubs;
      pkgs.pasta_bindings =
        super.pkgs.pasta_bindings.overrideAttrs marlinPlonkStubs;
      pkgs.libp2p_ipc = super.pkgs.libp2p_ipc.overrideAttrs (s: {
        GO_CAPNP_STD = "${pkgs.go-capnproto2.src}/std";
        nativeBuildInputs = s.nativeBuildInputs ++ [ pkgs.capnproto ];
      });
      pkgs.bindings_js = super.pkgs.bindings_js.overrideAttrs {
        PLONK_WASM_NODEJS = "${pkgs.plonk_wasm}/nodejs";
        PLONK_WASM_WEB = "${pkgs.plonk_wasm}/web";
      };
      files.src-lib-crypto-kimchi_bindings-js-node_js =
        super.files.src-lib-crypto-kimchi_bindings-js-node_js.overrideAttrs {
          PLONK_WASM_NODEJS = "${pkgs.plonk_wasm}/nodejs";
        };
      files.src-lib-crypto-kimchi_bindings-js-web =
        super.files.src-lib-crypto-kimchi_bindings-js-web.overrideAttrs {
          PLONK_WASM_WEB = "${pkgs.plonk_wasm}/web";
        };
      pkgs.__src-lib-ppx_mina-tests__ =
        makefileTest "__src-lib-ppx_mina-tests__" super;
      pkgs.__src-lib-ppx_version-test__ =
        makefileTest "__src-lib-ppx_version-test__" super;
      tested.child_processes = super.tested.child_processes.overrideAttrs
        (s: { buildInputs = s.buildInputs ++ [ childProcessesTester ]; });
      tested.block_storage =
        super.tested.block_storage.overrideAttrs withLibp2pHelper;
      tested.mina_lib = super.tested.mina_lib.overrideAttrs withLibp2pHelper;
      tested.mina_lib_tests =
        super.tested.mina_lib_tests.overrideAttrs withLibp2pHelper;
      tested.archive_lib = super.tested.archive_lib.overrideAttrs (s: {
        buildInputs = s.buildInputs ++ [ pkgs.ephemeralpg ];
        preBuild = ''
          export MINA_TEST_POSTGRES="$(pg_tmp -w 1200)"
          ( cd ${sqlSchemaFiles} && psql "$MINA_TEST_POSTGRES" < create_schema.sql >/dev/null )
        '';
      });
    };

  # We merge overlays in a cutsom way because pkgs.lib.composeManyExtensions
  # uses `//` for update instead of recursiveUpdate
  granularOverlay = self: _:
    let
      base = granularBase self;
      overlays = [ granularCustom ] ++ vmOverlays;
    in builtins.foldl' (super: f: pkgs.lib.recursiveUpdate super (f self super))
    base overlays;

  overlay = self: super:
    let
      ocaml-libs = builtins.attrValues (getAttrs installedPackageNames self);

      # Make a script wrapper around a binary, setting all the necessary environment variables and adding necessary tools to PATH.
      # Also passes the version information to the executable.
      wrapMina = let commit_sha1 = inputs.self.sourceInfo.rev or "<dirty>";
      in package:
      { deps ? [ pkgs.gnutar pkgs.gzip ] }:
      pkgs.runCommand "${package.name}-release" {
        buildInputs = [ pkgs.makeBinaryWrapper pkgs.xorg.lndir ];
        outputs = package.outputs;
      } (map (output: ''
        mkdir -p ${placeholder output}
        lndir -silent ${package.${output}} ${placeholder output}
        for i in $(find -L "${placeholder output}/bin" -type f); do
          wrapProgram "$i" \
            --prefix PATH : ${makeBinPath deps} \
            --set MINA_LIBP2P_HELPER_PATH ${pkgs.libp2p_helper}/bin/mina-libp2p_helper \
            --set MINA_COMMIT_SHA1 ${escapeShellArg commit_sha1}
        done
      '') package.outputs);

      # Derivation which has all Mina's dependencies in it, and creates an empty output if the command succeds.
      # Useful for unit tests.
      runMinaCheck = { name ? "check", extraInputs ? [ ], extraArgs ? { }, }:
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
      # Some "core" Mina executables, without the version info.
      mina-dev = pkgs.stdenv.mkDerivation ({
        pname = "mina";
        version = "dev";
        # Only get the ocaml stuff, to reduce the amount of unnecessary rebuilds
        src = with inputs.nix-filter.lib;
          filter {
            root = ./..;
            include = [
              (inDirectory "src")
              "dune"
              "dune-project"
              "./graphql_schema.json"
              "opam.export"
            ];
          };

        withFakeOpam = false;

        # TODO, get this from somewhere
        MARLIN_REPO_SHA = "<unknown>";
        MINA_COMMIT_SHA1 = "<unknown>";
        MINA_COMMIT_DATE = "<unknown>";
        MINA_BRANCH = "<unknown>";

        DUNE_PROFILE = "dev";

        NIX_LDFLAGS =
          optionalString (pkgs.stdenv.isDarwin && pkgs.stdenv.isAarch64)
          "-F${pkgs.darwin.apple_sdk.frameworks.CoreFoundation}/Library/Frameworks -framework CoreFoundation";

        buildInputs = ocaml-libs ++ external-libs;

        nativeBuildInputs = [
          self.dune
          self.ocamlfind
          self.odoc
          self.lld_wrapped
          pkgs.capnproto
          pkgs.removeReferencesTo
          pkgs.fd
        ] ++ ocaml-libs;

        # todo: slimmed rocksdb
        MINA_ROCKSDB = "${pkgs.rocksdb-mina}/lib/librocksdb.a";
        GO_CAPNP_STD = "${pkgs.go-capnproto2.src}/std";

        # this is used to retrieve the path of the built static library
        # and copy it from within a dune rule
        # (see src/lib/crypto/kimchi_bindings/stubs/dune)
        MARLIN_PLONK_STUBS = "${pkgs.kimchi_bindings_stubs}";
        DISABLE_CHECK_OPAM_SWITCH = "true";

        MINA_VERSION_IMPLEMENTATION = "mina_version.runtime";

        PLONK_WASM_NODEJS = "${pkgs.plonk_wasm}/nodejs";
        PLONK_WASM_WEB = "${pkgs.plonk_wasm}/web";

        configurePhase = ''
          export MINA_ROOT="$PWD"
          export -f patchShebangs isScript
          fd . --type executable -x bash -c "patchShebangs {}"
          export -n patchShebangs isScript
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
            src/app/archive/archive.exe \
            src/app/archive_blocks/archive_blocks.exe \
            src/app/extract_blocks/extract_blocks.exe \
            src/app/missing_blocks_auditor/missing_blocks_auditor.exe \
            src/app/replayer/replayer.exe \
            src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe
          # TODO figure out purpose of the line below
          # dune exec src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe -- --genesis-dir _build/coda_cache_dir
          # Building documentation fails, because not everything in the source tree compiles. Ignore the errors.
          dune build @doc || true
        '';

        outputs = [
          "out"
          "archive"
          "generate_keypair"
          "mainnet"
          "testnet"
          "genesis"
          "sample"
          "batch_txn_tool"
        ];

        installPhase = ''
          mkdir -p $out/bin $archive/bin $sample/share/mina $out/share/doc $generate_keypair/bin $mainnet/bin $testnet/bin $genesis/bin $genesis/var/lib/coda $batch_txn_tool/bin
          # TODO uncomment when genesis is generated above
          # mv _build/coda_cache_dir/genesis* $genesis/var/lib/coda
          pushd _build/default
          cp src/app/cli/src/mina.exe $out/bin/mina
          cp src/app/logproc/logproc.exe $out/bin/logproc
          cp src/app/rosetta/rosetta.exe $out/bin/rosetta
          cp src/app/batch_txn_tool/batch_txn_tool.exe $batch_txn_tool/bin/batch_txn_tool
          cp src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe $genesis/bin/runtime_genesis_ledger
          cp src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe $out/bin/runtime_genesis_ledger
          cp src/app/cli/src/mina_mainnet_signatures.exe $mainnet/bin/mina_mainnet_signatures
          cp src/app/rosetta/rosetta_mainnet_signatures.exe $mainnet/bin/rosetta_mainnet_signatures
          cp src/app/cli/src/mina_testnet_signatures.exe $testnet/bin/mina_testnet_signatures
          cp src/app/rosetta/rosetta_testnet_signatures.exe $testnet/bin/rosetta_testnet_signatures
          cp src/app/generate_keypair/generate_keypair.exe $generate_keypair/bin/generate_keypair
          cp src/app/archive/archive.exe $archive/bin/mina-archive
          cp src/app/archive_blocks/archive_blocks.exe $archive/bin/mina-archive-blocks
          cp src/app/missing_blocks_auditor/missing_blocks_auditor.exe $archive/bin/mina-missing-blocks-auditor
          cp src/app/replayer/replayer.exe $archive/bin/mina-replayer
          cp -R _doc/_html $out/share/doc/html
          # cp src/lib/mina_base/sample_keypairs.json $sample/share/mina
          popd
          remove-references-to -t $(dirname $(dirname $(command -v ocaml))) {$out/bin/*,$mainnet/bin/*,$testnet/bin*,$genesis/bin/*,$generate_keypair/bin/*}
        '';
        shellHook =
          "export MINA_LIBP2P_HELPER_PATH=${pkgs.libp2p_helper}/bin/mina-libp2p_helper";
      } // optionalAttrs pkgs.stdenv.isDarwin {
        OCAMLPARAM = "_,cclib=-lc++";
      });

      # Same as above, but wrapped with version info.
      mina = wrapMina self.mina-dev { };

      # Mina with additional instrumentation info.
      with-instrumentation-dev = self.mina-dev.overrideAttrs (oa: {
        pname = "with-instrumentation";
        outputs = [ "out" ];

        buildPhase = ''
          dune build  --display=short --profile=testnet_postake_medium_curves --instrument-with bisect_ppx src/app/cli/src/mina.exe
        '';
        installPhase = ''
          mkdir -p $out/bin
          mv _build/default/src/app/cli/src/mina.exe $out/bin/mina
        '';
      });

      with-instrumentation = wrapMina self.with-instrumentation-dev { };

      mainnet-pkg = self.mina-dev.overrideAttrs (s: {
        version = "mainnet";
        DUNE_PROFILE = "mainnet";
        # For compatibility with Docker build
        MINA_ROCKSDB = "${pkgs.rocksdb-mina}/lib/librocksdb.a";
      });

      mainnet = wrapMina self.mainnet-pkg { };

      devnet-pkg = self.mina-dev.overrideAttrs (s: {
        version = "devnet";
        DUNE_PROFILE = "devnet";
        # For compatibility with Docker build
        MINA_ROCKSDB = "${pkgs.rocksdb-mina}/lib/librocksdb.a";
      });

      devnet = wrapMina self.devnet-pkg { };

      # Unit tests
      mina_tests = runMinaCheck {
        name = "tests";
        extraArgs = {
          MINA_LIBP2P_HELPER_PATH =
            "${pkgs.libp2p_helper}/bin/mina-libp2p_helper";
          MINA_LIBP2P_PASS = "naughty blue worm";
          MINA_PRIVKEY_PASS = "naughty blue worm";
          TZDIR = "${pkgs.tzdata}/share/zoneinfo";
        };
        extraInputs = [ pkgs.ephemeralpg ];
      } ''
        dune build graphql_schema.json --display=short
        export MINA_TEST_POSTGRES="$(pg_tmp -w 1200)"
        pushd src/app/archive
        psql "$MINA_TEST_POSTGRES" < create_schema.sql
        popd
        # TODO: investigate failing tests, ideally we should run all tests in src/
        dune runtest src/app/archive src/lib/command_line_tests --display=short
      '';

      # Check if the code is formatted properly
      mina-ocaml-format = runMinaCheck { name = "ocaml-format"; } ''
        dune exec --profile=dev src/app/reformat/reformat.exe -- -path . -check
      '';

      inherit dune-description base-libs external-libs;
    };
in scope.overrideScope'
(pkgs.lib.composeManyExtensions ([ overlay granularOverlay ]))
