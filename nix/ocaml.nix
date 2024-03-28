# A set defining OCaml parts&dependencies of Minaocamlnix
{ inputs, src, ... }@args:
let
  opam-nix = inputs.opam-nix.lib.${pkgs.system};

  inherit (args) pkgs;

  inherit (builtins) filterSource path;

  inherit (pkgs.lib)
    hasPrefix last getAttrs filterAttrs optionalAttrs makeBinPath optionalString
    escapeShellArg;

  external-repo =
    opam-nix.makeOpamRepoRec "${src}/src/external"; # Pin external packages
  repos = [ external-repo inputs.opam-repository ];

  export = opam-nix.importOpam "${src}/opam.export";
  external-packages = pkgs.lib.getAttrs [ "sodium" "base58"
    "h_list" "bitstring_lib" "snarky_signature" "snarky" "snarky_curve" "fold_lib" "group_map" "snarkette" "tuple_lib" "sponge" "snarky_bench" "interval_union" "ppx_snarky" "snarky_integer" "h_list.ppx" "ppx_optcomp" "prometheus" "rocks"
    ]
    (builtins.mapAttrs (_: pkgs.lib.last) (opam-nix.listRepo external-repo));

  # Packages which are `installed` in the export.
  # These are all the transitive ocaml dependencies of Mina.
  export-installed = opam-nix.opamListToQuery export.installed;

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

  # Dependencies required by every Mina package
  implicit-deps = export-installed // external-packages;

  # Pins from opam.export
  pins = builtins.mapAttrs (name: pkg: { inherit name; } // builtins.removeAttrs pkg ["name"]) export.package.section;

  minaEnv = {
    # TODO, get these from somewhere
    MARLIN_REPO_SHA = "<unknown>";
    MINA_COMMIT_SHA1 = "<unknown>";
    MINA_COMMIT_DATE = "<unknown>";
    MINA_BRANCH = "<unknown>";

    DUNE_PROFILE = "dev";
    DISABLE_CHECK_OPAM_SWITCH = "true";

    NIX_LDFLAGS =
      optionalString (pkgs.stdenv.isDarwin && pkgs.stdenv.isAarch64)
      "-F${pkgs.darwin.apple_sdk.frameworks.CoreFoundation}/Library/Frameworks -framework CoreFoundation";

    # todo: slimmed rocksdb
    MINA_ROCKSDB = "${pkgs.rocksdb}/lib/librocksdb.a";
    GO_CAPNP_STD = "${pkgs.go-capnproto2.src}/std";

    # this is used to retrieve the path of the built static library
    # and copy it from within a dune rule
    # (see src/lib/crypto/kimchi_bindings/stubs/dune)
    MARLIN_PLONK_STUBS = "${pkgs.kimchi_bindings_stubs}";

    MINA_VERSION_IMPLEMENTATION = "mina_version.runtime";

    PLONK_WASM_NODEJS = "${pkgs.plonk_wasm}/nodejs";
    PLONK_WASM_WEB = "${pkgs.plonk_wasm}/web";
  } // optionalAttrs pkgs.stdenv.isDarwin {
    OCAMLPARAM = "_,cclib=-lc++";
  };

  rocksdb511Stub =
    pkgs.stdenv.mkDerivation {
      src = "${pkgs.rocksdb511}/lib";
      name = "rocksdb-with-stub";
      version = pkgs.rocksdb511.version;
      phases = [ "unpackPhase" "installPhase" ];
      installPhase = ''
        mkdir -p $out/lib
        cp librocksdb.a $out/lib/
        cp librocksdb.a $out/lib/librocksdb_stubs.a
      '';
    };

  # "System" dependencies required by all Mina packages
  external-libs = with pkgs;
    [ zlib bzip2 gmp openssl libffi rocksdb511Stub ]
    ++ lib.optional (!(stdenv.isDarwin && stdenv.isAarch64)) jemalloc;

  # This is needed because
  # - lld package is not wrapped to pick up the correct linker flags
  # - bintools package also includes as which is incompatible with gcc
  lld_wrapped = pkgs.writeShellScriptBin "ld.lld"
    ''${pkgs.llvmPackages.bintools}/bin/ld.lld "$@"'';

  ocamlPkgOverlay = self: super:
    {
      # https://github.com/Drup/ocaml-lmdb/issues/41
      lmdb = super.lmdb.overrideAttrs
        (oa: { buildInputs = oa.buildInputs ++ [ self.conf-pkg-config ]; });

      # Can't find sodium-static and ctypes
      sodium = super.sodium.overrideAttrs (_: {
        NIX_CFLAGS_COMPILE = "-I${pkgs.sodium-static.dev}/include";
        propagatedBuildInputs = [ pkgs.sodium-static ];
        preBuild = ''
          export LD_LIBRARY_PATH="${super.ctypes}/lib/ocaml/${super.ocaml.version}/site-lib/ctypes";
        '';
      });

      # Doesn't have an explicit dependency on ctypes-foreign
      ctypes = super.ctypes.overrideAttrs
        (oa: { buildInputs = oa.buildInputs ++ [ self.ctypes-foreign ]; });

      # Doesn't have an explicit dependency on ctypes
      rpc_parallel = super.rpc_parallel.overrideAttrs
        (oa: { buildInputs = oa.buildInputs ++ [ self.ctypes ]; });

      check_opam_switch = super.check_opam_switch.overrideAttrs (oa: {
        # So that opam in impure shell doesn't get shadowed by the fake one
        propagateInputs = false;
      });

      rocks = super.rocks.overrideAttrs (s: {
        MINA_ROCKSDB = "${pkgs.rocksdb511}/lib/librocksdb.a";
        buildInputs = s.buildInputs ++ [ self.ctypes-foreign self.dune-configurator ];
        nativeBuildInputs = s.nativeBuildInputs ++ [
          self.dune self.ctypes self.dune-configurator 
        ];
        configurePhase = ''
          ${s.configurePhase}
          cp ${../src/dune.linker.inc} dune.linker.inc
          sed -i -r 's%\.\./\.\./dune\.linker\.inc%dune.linker.inc%g' dune
          '';
        buildPhase = ''
          ${s.buildPhase}
          '';
      });
    };

  ocamlOverlays = opam-nix.__overlays ++ [ ocamlPkgOverlay ];

  scope = opam-nix.applyOverlays ocamlOverlays
    (opam-nix.defsToScope pkgs { }
      ((opam-nix.queryToDefs repos (extra-packages // implicit-deps)) // pins));

  installedPackageNames =
    map (x: (opam-nix.splitNameVer x).name) (builtins.attrNames implicit-deps);

  sourceInfo = inputs.self.sourceInfo or { };

  # "System" dependencies required by all Mina packages
  external-libs = with pkgs;
    [ zlib bzip2 gmp openssl libffi ]
    ++ lib.optional (!(stdenv.isDarwin && stdenv.isAarch64)) jemalloc;

  overlay = self: super:
    let
      ocaml-libs = builtins.attrValues (getAttrs installedPackageNames self);

      # Make a script wrapper around a binary, setting all the necessary environment variables and adding necessary tools to PATH.
      # Also passes the version information to the executable.
      wrapMina = let
        commit_sha1 = inputs.self.sourceInfo.rev or "<dirty>";
        commit_date = inputs.flockenzeit.lib.RFC-5322 inputs.self.sourceInfo.lastModified or 0;
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

      # Derivation which has all Mina's dependencies in it, and creates an empty output if the command succeds.
      # Useful for unit tests.
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
      # Some "core" Mina executables, without the version info.
      mina-dev = pkgs.stdenv.mkDerivation (minaEnv // {
        pname = "mina";
        version = "dev";
        # Prevent unnecessary rebuilds on non-source changes
        inherit src;

        withFakeOpam = false;

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
            src/app/archive/archive.exe \
            src/app/archive_blocks/archive_blocks.exe \
            src/app/extract_blocks/extract_blocks.exe \
            src/app/missing_blocks_auditor/missing_blocks_auditor.exe \
            src/app/replayer/replayer.exe \
            src/app/swap_bad_balances/swap_bad_balances.exe \
            src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe \
            src/app/berkeley_migration/berkeley_migration.exe \
            src/app/berkeley_migration_verifier/berkeley_migration_verifier.exe
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
          "berkeley_migration"
        ];

        installPhase = ''
          mkdir -p $out/bin $archive/bin $sample/share/mina $out/share/doc $generate_keypair/bin $mainnet/bin $testnet/bin $genesis/bin $genesis/var/lib/coda $batch_txn_tool/bin $berkeley_migration/bin
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
          cp src/app/replayer/replayer.exe $berkeley_migration/bin/mina-migration-replayer
          cp src/app/berkeley_migration/berkeley_migration.exe $berkeley_migration/bin/mina-berkeley-migration
          cp src/app/berkeley_migration_verifier/berkeley_migration_verifier.exe $berkeley_migration/bin/mina-berkeley-migration-verifier
          cp ${../scripts/archive/migration/mina-berkeley-migration-script} $berkeley_migration/bin/mina-berkeley-migration-script
          cp src/app/swap_bad_balances/swap_bad_balances.exe $archive/bin/mina-swap-bad-balances
          cp -R _doc/_html $out/share/doc/html
          # cp src/lib/mina_base/sample_keypairs.json $sample/share/mina
          popd
          remove-references-to -t $(dirname $(dirname $(command -v ocaml))) {$out/bin/*,$mainnet/bin/*,$testnet/bin*,$genesis/bin/*,$generate_keypair/bin/*}
        '';
        shellHook =
          "export MINA_LIBP2P_HELPER_PATH=${pkgs.libp2p_helper}/bin/libp2p_helper";
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
        MINA_ROCKSDB = "${pkgs.rocksdb511}/lib/librocksdb.a";
      });

      mainnet = wrapMina self.mainnet-pkg { };

      experiment =
        # let deps = builtins.removeAttrs export-installed (builtins.attrNames pins.section ++ builtins.attrNames external-packages); in
        # let deps = builtins.removeAttrs export-installed ["check_opam_switch"] // { base58 = "0.1.3"; }; in
        let
        # deps = builtins.removeAttrs export-installed (builtins.attrNames pins) // { base58 = "0.1.3"; };
        deps = extra-packages // implicit-deps ;
        minaConfig =
          let src = with inputs.nix-filter.lib;
            filter {
              root = ../src;
              include =
                [ (inDirectory "config") ];
            }; in
          pkgs.stdenv.mkDerivation {
            DUNE_PROFILE = "devnet";
            inherit src;
            name = "mina-dune-project";
            nativeBuildInputs = with self; [ dune ocaml ];
            phases = [ "unpackPhase" "buildPhase" "installPhase" ];
            buildPhase = ''
              echo '(lang dune 3.3)' > dune-project
              dune build config/config.mlh
            '';
            installPhase = ''
              cp -R _build/default/config $out
              cd $out
              sed -i "s%/src/config/%$out/%g" $(find -name '*.mlh' -type f)
            '';
          };
        patchDuneGraphql = self: ''
          dune_files=$(find -name dune -type f)
          ( [[ "$dune_files" != "" ]] && grep -o graphql_schema.json $dune_files >/dev/null && \
            sed -i -r 's%(\.\./)*graphql_schema.json%${self.graphql-schema}/graphql_schema.json%g' $dune_files ) || true
          ( [[ "$dune_files" != "" ]] && grep -o graphql-ppx-config.inc $dune_files >/dev/null && \
            cp ${self.graphql-schema}/graphql-ppx-config.inc ./ && \
            sed -i -r 's%(\.\./)*graphql-ppx-config.inc%./graphql-ppx-config.inc%g' $dune_files ) || true
          '';
        patchDune = ''
          [ -f dune-project ] || echo '(lang dune 3.3)' > dune-project
          dune_files=$(find -name dune -type f)
          ( [[ "$dune_files" != "" ]] && grep -oE config.mlh $dune_files >/dev/null && \
            sed -i -r 's%(../)*config.mlh%${minaConfig}/config.mlh%g' $dune_files && \
            sed -i 's~\[%%import "/src/config.mlh"\]~\[%%import "${minaConfig}/config.mlh"\]~g' \
            $(find \( -name '*.ml' -or -name '*.mli' \) -type f) ) || true
          '';
        opam-files = 
          let src =
             with inputs.nix-filter.lib;
              filter {
                root = ../.;
                include =
                  [ "dune" "dune-project" "./nix/dump-dune-deps.sh" ];
                exclude = [ (inDirectory "src/external") ];
              }; in
          pkgs.stdenv.mkDerivation {
          name = "mina-opam-files";
          inherit src;
          nativeBuildInputs = with self; [ dune ocaml pkgs.jq ];
          phases = [ "unpackPhase" "buildPhase" "installPhase" ];
          buildPhase = ''
            tr "\n" " " <src/dune-project | grep -oE '\(\s*package\s*\(name\s\s*[^\)]*\)\)' \
              | sed -r 's/\((name|package)//g' \
              | sed -r 's/\s|\)//g' | sed -r 's%^.*$%src/\0.opam%g' | xargs dune build

            # Build library dependency mapping
            ${pkgs.bash}/bin/bash ./nix/dump-dune-deps.sh > deps.json
          '';
          installPhase = ''
            rm _build -rf
            <deps.json jq -r 'to_entries | .[] | "if [[ -f src/" + .key + ".opam ]]; then mv -f src/" + .key + ".opam " + .value.path + "; fi"' | ${pkgs.bash}/bin/bash
            cp -R . $out
          '';
        };
        src-with-opam-files = pkgs.stdenv.mkDerivation {
          name = "mina-dune-project";
          inherit src;
          nativeBuildInputs = with self; [ dune ocaml pkgs.jq ];
          phases = [ "unpackPhase" "buildPhase" "installPhase" ];
          buildPhase = ''
            tr "\n" " " <src/dune-project | grep -oE '\(\s*package\s*\(name\s\s*[^\)]*\)\)' \
              | sed -r 's/\((name|package)//g' \
              | sed -r 's/\s|\)//g' | sed -r 's%^.*$%src/\0.opam%g' | xargs dune build

            # Build library dependency mapping
            ${pkgs.bash}/bin/bash ./nix/dump-dune-deps.sh > deps.json

            dune_files=$(find src/app -name dune -type f)
            ( [[ "$dune_files" != "" ]] && grep -o dune.flags.inc $dune_files >/dev/null && \
              sed -i -r 's%(\.\./)*dune\.flags\.inc%./dune.flags.inc%g' $dune_files && \
              { for f in $dune_files; do cp src/dune*.inc $(dirname $f); done; } ) || true
          '';
          installPhase = ''
            rm _build -rf
            <deps.json jq -r 'to_entries | .[] | "if [[ -f src/" + .key + ".opam ]]; then mv -f src/" + .key + ".opam " + .value.path + "; fi"' | ${pkgs.bash}/bin/bash
            cp -R . $out
          '';
        };
        depsMap = builtins.fromJSON (builtins.readFile "${src-with-opam-files}/deps.json");
        getDeps = names: self: builtins.attrValues (pkgs.lib.filterAttrs (n: _: builtins.elem n names) self);
        graphqlDependents = ["init" "rosetta_app_lib" "batch_txn_tool" "integration_test_cloud_engine" "integration_test_lib" "generated_graphql_queries" "integration_test_local_engine"];
        myOverlay = self: super:
          let ppx_names = ["ppx_version" "ppx_mina" "ppx_register_event" "ppx_representatives" "ppx_to_enum" "ppx_annot"];
          ppxs = builtins.attrValues (pkgs.lib.getAttrs ppx_names self) ++ [self.ppx_base self.ppx_optcomp self.ppx_bitstring];
          customDeps = name:
          if name == "interpolator_lib" then [self.ppx_version self.ppx_deriving self.ppx_deriving_yojson]
          else if name == "structured_log_events" then [self.ppx_version self.ppx_deriving]
          else if name == "ppx_register_event" then [self.structured_log_events]
          else if name == "ppx_mina" then [self.structured_log_events]
          else if name == "ppx_annot" then [self.ppx_version]
          else [] ;
          custom =
            builtins.mapAttrs (name: old:
              old.overrideAttrs (s: minaEnv // {
              buildInputs = s.buildInputs ++ getDeps (builtins.getAttr name depsMap).deps self ++ external-libs ++ customDeps name;
              nativeBuildInputs = s.nativeBuildInputs ++ external-libs;
              configurePhase =
                ''
                  ${s.configurePhase}
                  ${patchDune}
                '';
            })) (pkgs.lib.getAttrs (ppx_names ++ ["interpolator_lib" "structured_log_events"]) super);
          in
          custom //
          (pkgs.lib.concatMapAttrs (name: old:
            if builtins.hasAttr name custom || ! builtins.hasAttr name depsMap then {}
            else
              {
                ${name} = old.overrideAttrs (s:
                minaEnv // {
                  buildInputs = ppxs ++ s.buildInputs ++ getDeps (builtins.getAttr name depsMap).deps self ++ external-libs ++
                    ( if builtins.elem name graphqlDependents then [self.graphql_ppx]
                    else []);
                  nativeBuildInputs = s.nativeBuildInputs ++ external-libs ++ [pkgs.capnproto self.capnp self.rocks];
                  configurePhase =
                    ''
                      ${s.configurePhase}
                      ${patchDune}
                    '' +
                    ( if builtins.elem name graphqlDependents then
                      ''
                        ${patchDuneGraphql self}
                      ''
                    else "") ;
                });
              }
              ) super) //
              { graphql-schema =
                  pkgs.stdenv.mkDerivation {
                    src =
                      with inputs.nix-filter.lib;
                      filter {
                        root = ../src;
                        include =
                          [ (matchExt "inc") ];
                      };
                    name = "graphql-schema";
                    phases = [ "installPhase" ];
                    installPhase = ''
                      cp -R . $out
                      ${self.graphql_schema_dump}/bin/graphql_schema_dump > $out/graphql_schema.json
                    '';
                  };
              }
          ;
       prj =
          (opam-nix.buildOpamProject' {
            inherit pkgs repos;
            recursive = true;
            defs = pins;
            useOpamList = false;
            overlays = ocamlOverlays ++ [ myOverlay ];
            resolveArgs = { env = {
              DUNE_PROFILE="dev";
                DISABLE_CHECK_OPAM_SWITCH = "true";
              }; };
          } src-with-opam-files deps );
        in prj.mina_cli_entrypoint;

      devnet-pkg = self.mina-dev.overrideAttrs (s: {
        version = "devnet";
        DUNE_PROFILE = "devnet";
        # For compatibility with Docker build
        MINA_ROCKSDB = "${pkgs.rocksdb511}/lib/librocksdb.a";
      });

      devnet = wrapMina self.devnet-pkg { };

      # Unit tests
      mina_tests = runMinaCheck {
        name = "tests";
        extraArgs = {
          MINA_LIBP2P_HELPER_PATH = "${pkgs.libp2p_helper}/bin/libp2p_helper";
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

      # Integration test executive
      test_executive-dev = self.mina-dev.overrideAttrs (oa: {
        pname = "mina-test_executive";
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
