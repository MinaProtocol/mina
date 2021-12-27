inputs: pkgs:
let
  opam-nix = inputs.opam-nix.lib.${pkgs.system};

  repos = [
    (opam-nix.makeOpamRepo ../src/external) # Pin external packages
    ./fake-opam-repo # Remove opam version restriction imposed by a depext dependency
    inputs.opam-repository
  ];

  export =
    opam-nix.opamListToQuery (opam-nix.fromOPAM ../src/opam.export).installed;
  external-packages = {
    "sodium" = "dev";
    "capnp" = "local";
    "rpc_parallel" = "v0.13.0";
    "ocaml-extlib" = "local";
    "async_kernel" = "v0.13.0";
    "base58" = "0.1.0";
    "graphql_ppx" = "0.0.4";
    "ppx_deriving_yojson" = "local";
  };

  implicit-deps = export // external-packages;

  query = {
    ocaml = "4.11.2";
    opam-depext = "1.2.0";
  };

  scope = opam-nix.applyOverlays [ opam-nix.defaultOverlay ]
    (opam-nix.defsToScope pkgs
      (opam-nix.queryToDefs repos (export // external-packages // query)));

  installedPackageNames =
    map (x: (opam-nix.splitNameVer x).name) (builtins.attrNames implicit-deps);

  sourceInfo = inputs.self.sourceInfo or { };

  overlay = self: super:
    {
      sodium = super.sodium.overrideAttrs (_: {
        NIX_CFLAGS_COMPILE = "-I${pkgs.sodium-static.dev}/include";
        propagatedBuildInputs = [ pkgs.sodium-static ];
        preBuild = ''
          export LD_LIBRARY_PATH="${super.ctypes}/lib/ocaml/${super.ocaml.version}/site-lib/ctypes";
        '';
      });

      mina = pkgs.stdenv.mkDerivation {
        pname = "mina";
        version = "dev";
        # Prevent unnecessary rebuilds on non-source changes
        src = builtins.filterSource (name: type:
          name == (toString (../. + "/dune"))
          || pkgs.lib.hasPrefix (toString (../. + "/src")) name) ../.;
        # todo: slimmed rocksdb
        buildInputs =
          (builtins.attrValues (pkgs.lib.getAttrs installedPackageNames self))
          ++ [ pkgs.zlib pkgs.bzip2 pkgs.snappy pkgs.lz4 pkgs.zstd ];
        nativeBuildInputs = [ self.dune self.ocamlfind pkgs.capnproto ];
        NIX_LDFLAGS = "-lsnappy -llz4 -lzstd";
        # TODO, get this from somewhere
        MARLIN_REPO_SHA = "bacef43ea34122286745578258066c29091dc36a";

        MINA_COMMIT_DATE = sourceInfo.lastModifiedDate or "<unknown>";
        MINA_COMMIT_SHA1 = sourceInfo.rev or "DIRTY";
        MINA_BRANCH = "<unknown>";

        buildPhase = ''
          export MINA_ROOT="$NIX_BUILD_TOP/$sourceRoot"
          sed 's,/usr/local/lib/librocksdb_coda.a,${pkgs.buildPackages.buildPackages.rocksdb}/lib/librocksdb.a,' -i src/external/ocaml-rocksdb/dune
          sed 's,make ,make GO_CAPNP_STD=${pkgs.buildPackages.buildPackages.go-capnproto2.src}/std ,' -i src/libp2p_ipc/dune
          sed 's,cargo build --release,mkdir target,' -i src/lib/marlin_plonk_bindings/stubs/dune
          sed 's,target/release,${pkgs.buildPackages.buildPackages.marlin_plonk_bindings_stubs}/lib,' -i src/lib/marlin_plonk_bindings/stubs/dune
          patchShebangs .
          dune build src/app/logproc/logproc.exe src/app/cli/src/mina.exe -j$NIX_BUILD_CORES
        '';
        installPhase = ''
          mkdir -p $out/bin
          mv _build/default/src/app/{logproc/logproc.exe,cli/src/mina.exe} $out/bin
        '';
      };
    } // pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.isStatic)
    (import ./static-ocaml-overlay.nix self super);
in scope.overrideScope' overlay
