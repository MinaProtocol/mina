# A set defining OCaml parts&dependencies of Minaocamlnix
{ inputs, ... }@args:
let
  opam-nix = inputs.opam-nix.lib.${pkgs.system};

  inherit (args) pkgs;

  inherit (builtins) filterSource path;

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
  duneOutFiles = builtins.foldl' (acc0: el:
    let
      extendAcc = acc: file:
        acc // {
          "${file}" = if acc ? "${file}" then
            builtins.throw
            "File ${file} is defined as output of many dune files"
          else
            el.src;
        };
      extendAccExe = acc: unit:
        if unit.type == "exe" then
          extendAcc acc "${el.src}/${unit.name}.exe"
        else
          acc;
      acc1 = builtins.foldl' extendAcc acc0 el.file_outs;
    in builtins.foldl' extendAccExe acc1 el.units) { } duneDescLoaded;

  collectLibLocs = attrName:
    let
      extendAcc = src: acc: name:
        acc // {
          "${name}" = if acc ? "${name}" then
            builtins.throw
            "Library with ${attrName} ${name} is defined in multiple dune files"
          else
            src;
        };
      extendAccLib = src: acc: unit:
        if unit.type == "lib" && unit ? "${attrName}" then
          extendAcc src acc unit."${attrName}"
        else
          acc;
      foldF = acc0: el: builtins.foldl' (extendAccLib el.src) acc0 el.units;
    in builtins.foldl' foldF { };

  publicLibLocs = collectLibLocs "public_name" duneDescLoaded;

  libLocs = collectLibLocs "name" duneDescLoaded // publicLibLocs;

  mkPkgCfg =
    desc:
    let
      # Optimization, should work even without (but slower and with far more unnecessary rebuilds)
      src =
        if desc.src == "."
          then with pkgs.lib.fileset; (toSource {root=./..; fileset=union ../graphql_schema.json ../dune;})
        else if desc.src == "src"
          then with pkgs.lib.fileset; (toSource {root=../src; fileset=union ../src/dune-project ../src/dune;})
        else if desc.src == "src/lib/snarky"
          then with pkgs.lib.fileset; (toSource {root=../src/lib/snarky; fileset=union ../src/lib/snarky/dune-project ../src/lib/snarky/dune;})
        else ../. + "/${desc.src}";
      subdirs = if builtins.elem desc.src ["." "src" "src/lib/snarky"] then [] else desc.subdirs;

      internalLibs = builtins.concatMap (unit: if unit.type != "lib" then [] else if unit ? "public_name" then [unit.public_name unit.name] else [unit.name]) desc.units;
      deps' = builtins.filter (d: ! builtins.elem d internalLibs) desc.deps;
      defImplLibs = builtins.concatMap (unit: if unit ? "default_implementation" then [unit.default_implementation] else []) desc.units;
      implement = builtins.concatMap (unit: if unit ? "implements" then [unit.implements] else []) desc.units;
      def_impls = builtins.attrValues (pkgs.lib.getAttrs defImplLibs libLocs);
      out_file_deps = builtins.concatMap
        (fd: if duneOutFiles ? "${fd}" then [ duneOutFiles."${fd}" ] else [ ])
        desc.file_deps ++ (if desc.src == "src/lib/signature_kind" then ["src"] else if desc.src == "src/lib/logger" then ["src/lib/bounded_types" "src/lib/mina_compile_config" "src/lib/itn_logger"] else []);
      lib_deps = builtins.attrValues
        (pkgs.lib.getAttrs (builtins.filter (e: libLocs ? "${e}") (deps' ++ implement) )
          libLocs);
    in {
      deps = pkgs.lib.unique (lib_deps ++ out_file_deps ++ def_impls);
      inherit (desc) file_deps;
      inherit subdirs out_file_deps src def_impls;
      targets = (if desc.units == [ ] then [ ] else [ desc.src ])
        ++ desc.file_outs;
    };

  pkgCfgMap = builtins.listToAttrs
    (builtins.map (desc: pkgs.lib.nameValuePair desc.src (mkPkgCfg desc))
      duneDescLoaded);

  # TODO Rewrite recursive dep calculation: compute map for every dependency
  recursiveDeps =
    let
      deps = loc: pkgCfgMap."${loc}".deps;
      impl = acc: loc:
        if acc ? "${loc}" then
          acc
        else
          builtins.foldl' impl (acc // { "${loc}" = ""; })
          (deps loc);
    in
    initLoc:
    builtins.foldl' impl { } (deps initLoc);

  base-libs =
    let deps = pkgs.lib.getAttrs (builtins.attrNames implicit-deps) scope;
    in pkgs.stdenv.mkDerivation {
      name = "mina-base-libs";
      phases = [ "installPhase" ];
      buildInputs = builtins.attrValues deps;
      installPhase = ''
        mkdir -p $out/lib/ocaml/${scope.ocaml.version}/site-lib/stublibs $out/nix-support $out/bin
        {
          echo -n 'export OCAMLPATH=$'
          echo -n '{OCAMLPATH-}$'
          echo '{OCAMLPATH:+:}'"$out/lib/ocaml/${scope.ocaml.version}/site-lib"
          echo -n 'export CAML_LD_LIBRARY_PATH=$'
          echo -n '{CAML_LD_LIBRARY_PATH-}$'
          echo '{CAML_LD_LIBRARY_PATH:+:}'"$out/lib/ocaml/${scope.ocaml.version}/site-lib/stublibs"
        } > $out/nix-support/setup-hook
        for input in $buildInputs; do
          [ ! -d "$input/lib/ocaml/${scope.ocaml.version}/site-lib" ] || {
            find "$input/lib/ocaml/${scope.ocaml.version}/site-lib" -maxdepth 1 -mindepth 1 -not -name stublibs | while read d; do
              cp -R "$d" "$out/lib/ocaml/${scope.ocaml.version}/site-lib/"
            done
          }
          [ ! -d "$input/lib/ocaml/${scope.ocaml.version}/site-lib/stublibs" ] || cp -R "$input/lib/ocaml/${scope.ocaml.version}/site-lib/stublibs"/* "$out/lib/ocaml/${scope.ocaml.version}/site-lib/stublibs/"
          [ ! -d "$input/bin" ] || cp -R $input/bin/* $out/bin
        done
      '';
    };

  quote = builtins.replaceStrings [ "." "/" ] [ "__" "-" ];

  buildDunePkg = let
    copyDirs' = prefix: path: drv:
      ''"${builtins.dirOf "${prefix}/${path}"}" "${builtins.baseNameOf "${prefix}/${path}"}" "${drv}"'' ;
    copyFileDep' = f:
      if builtins.pathExists ../${f} then
        [(copyDirs' "." f ../${f})] else [];
    copyBuildDirs' = copyDirs' "_build/default";
    copySrcDirs' = path: cfg: copyDirs' "." path cfg.src;
    copyAllBuildDirs' = def_impls: devDeps: pkgs.lib.mapAttrsToList copyBuildDirs' (builtins.removeAttrs devDeps def_impls);
    copyAllSrcDirs'   = cfgSubMap: pkgs.lib.mapAttrsToList copySrcDirs' cfgSubMap;
    subdirsToDelete' = topPath: deps: path: cfg: builtins.concatMap (f: let r = "${path}/${f}"; in if pkgs.lib.any (d: d == r || pkgs.lib.hasPrefix "${r}/" d) ([topPath]++deps) then [] else [r]) cfg.subdirs;
  in path: {file_deps, targets, src, def_impls, ... }@cfg: devDeps:
  let
    quotedPath = quote path;
    file_deps' = pkgs.lib.unique (file_deps ++ builtins.concatLists (pkgs.lib.mapAttrsToList (p: _: pkgCfgMap."${p}".file_deps) devDeps)); 
    cfgSubMap = builtins.intersectAttrs devDeps pkgCfgMap;
    depNames = builtins.attrNames cfgSubMap;
    allDirs' = copyAllBuildDirs' def_impls devDeps ++ copyAllSrcDirs' cfgSubMap ++ [(copySrcDirs' path cfg)] ++
    builtins.concatMap copyFileDep' file_deps';
    allDirs = builtins.sort (s: t: s < t) allDirs';
    subdirsToDelete = pkgs.lib.unique (subdirsToDelete' path depNames path cfg ++ builtins.concatLists (pkgs.lib.mapAttrsToList (subdirsToDelete' path depNames) cfgSubMap));
    # If path being copied contains dune-inhabitated subdirs,
    # it isn't enough to just link dependencies from other derivations
    # because in some cases we may want to create a subdir in the directory corresponding
    # to that dependency.
    #
    # Hence what we do is the following: we create a directory for the path and recursively 
    # link all regular files with symlinks, while recreating the dependency tree
    initFS = ''
      set -euo pipefail
      chmod +w .
      inputs=( ${builtins.concatStringsSep " " allDirs} )
      for i in {0..${toString (builtins.length allDirs - 1)}}; do
        j=$((i*3))
        dir="''${inputs[$j]}"
        file="$dir/''${inputs[$((j+1))]}"
        drv="''${inputs[$((j+2))]}"
        mkdir -p "$dir"
        cp -RLTu "$drv" "$file"
        [ ! -d "$file" ] || chmod -R +w "$file"
      done
    '' + (if subdirsToDelete == [] then "" else ''
      toDelete=( ${pkgs.lib.concatMapStringsSep " " (f: ''"${f}"'') subdirsToDelete} )
      rm -Rf "''${toDelete[@]}"
      [ ! -d _build/default ] || ( cd _build/default && rm -Rf "''${toDelete[@]}" )
      '');
   initFSDrv = pkgs.writeShellScriptBin "init-fs-${quotedPath}" initFS;
  in
  # TODO check logs. Seems like we're not copying all of the _build dirs correctly (in case of sources it might simply not be a factor to worry about)
  # (^ unlikely though, sorting should alleviate the concern most of the time)
  [ { name = "init-fs-${quotedPath}"; value = initFSDrv; }
    { name = quotedPath; value =
    pkgs.stdenv.mkDerivation {
    pname = quotedPath;
    version = "dev";
    GO_CAPNP_STD = "${pkgs.go-capnproto2.src}/std";
    MARLIN_PLONK_STUBS = "${pkgs.kimchi_bindings_stubs}";
    PLONK_WASM_NODEJS = "${pkgs.plonk_wasm}/nodejs";
    PLONK_WASM_WEB = "${pkgs.plonk_wasm}/web";
    DUNE_PROFILE = "dev";
    MINA_COMMIT_SHA1 = inputs.self.sourceInfo.rev or "<dirty>";
    buildInputs = [ base-libs ] ++ external-libs;
    nativeBuildInputs = [ base-libs initFSDrv pkgs.capnproto ];
    dontUnpack = true;
    patchPhase = '' init-fs-${quotedPath} '';
    buildPhase = ''
      dune build ${builtins.concatStringsSep " " targets}
    '';
    installPhase = ''
      find _build/default \( -type l -o \( -type d -empty \) \) -delete
      cp -R _build/default/${path} $out
    '';
  }; }];

  minaPkgs = self:
    builtins.listToAttrs (builtins.concatLists (
    pkgs.lib.attrsets.mapAttrsToList (path: cfg:
      let
        deps = builtins.attrNames (recursiveDeps path);
        depMap = builtins.listToAttrs (builtins.map (d: {
          name = d;
          value = self."${quote d}";
        }) (builtins.filter (p: path != p) deps));
      in buildDunePkg path cfg depMap) pkgCfgMap));

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
          sed -i "s/mina_version_compiled/mina_version.runtime/g" src/app/cli/src/dune src/app/rosetta/dune src/app/archive/dune
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
          cp ${
            ../scripts/archive/migration/mina-berkeley-migration-script
          } $berkeley_migration/bin/mina-berkeley-migration-script
          cp src/app/swap_bad_balances/swap_bad_balances.exe $archive/bin/mina-swap-bad-balances
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
          MINA_LIBP2P_HELPER_PATH = "${pkgs.libp2p_helper}/bin/mina-libp2p_helper";
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

      experiment = minaPkgs self.experiment // { inherit dune-description; };
    };
in scope.overrideScope' overlay
