inputs: pkgs':
let
  opam-nix = inputs.opam-nix.lib.${pkgs.system};

  pkgs = pkgs'.buildPackages;

  external-repo = opam-nix.makeOpamRepo ../src/external; # Pin external packages
  repos = [
    external-repo
    ./fake-opam-repo # Remove opam version restriction imposed by a depext dependency
    inputs.opam-repository
  ];

  export =
    opam-nix.opamListToQuery (opam-nix.importOpam ../src/opam.export).installed;
  external-packages = pkgs.lib.getAttrs [
    "sodium"
    "capnp"
    "rpc_parallel"
    "ocaml-extlib"
    "async_kernel"
    "base58"
    "graphql_ppx"
    "ppx_deriving_yojson"
  ] (builtins.mapAttrs (_: pkgs.lib.last) (opam-nix.listRepo external-repo));

  implicit-deps = export // external-packages;

  scope = opam-nix.applyOverlays opam-nix.__overlays
    (opam-nix.defsToScope pkgs (opam-nix.queryToDefs repos implicit-deps));

  installedPackageNames =
    map (x: (opam-nix.splitNameVer x).name) (builtins.attrNames implicit-deps);

  sourceInfo = inputs.self.sourceInfo or { };
  dds = x: x.overrideAttrs (o: { dontDisableStatic = true; });

  external-libs = with pkgs';
    if stdenv.hostPlatform.isMusl then
      map dds [
        (zlib.override { splitStaticOutput = false; })
        (bzip2.override { linkStatic = true; })
        (snappy.override { static = true; })
        (lz4.override {
          enableStatic = true;
          enableShared = false;
        })
        (zstd.override { static = true; })
        (jemalloc.overrideAttrs (oa: {
          configureFlags = oa.configureFlags ++ [
            "--with-jemalloc-prefix=je_"
          ];
        }))
        (gmp.override { withStatic = true; })
        (openssl.override { static = true; })
        libffi
      ]
    else [
      zlib
      bzip2
      snappy
      lz4
      zstd
      jemalloc
      gmp
      openssl
      libffi
    ];

  overlay = self: super:
    {
      sodium = super.sodium.overrideAttrs (_: {
        NIX_CFLAGS_COMPILE = "-I${pkgs.sodium-static.dev}/include";
        propagatedBuildInputs = [ pkgs.sodium-static ];
        preBuild = ''
          export LD_LIBRARY_PATH="${super.ctypes}/lib/ocaml/${super.ocaml.version}/site-lib/ctypes";
        '';
      });

      rpc_parallel = super.rpc_parallel.overrideAttrs
        (oa: { buildInputs = oa.buildInputs ++ [ self.ctypes ]; });

      mina = pkgs'.stdenv.mkDerivation {
        pname = "mina";
        version = "dev";
        # Prevent unnecessary rebuilds on non-source changes
        src = builtins.filterSource (name: type:
          name == (toString (../. + "/dune"))
          || pkgs.lib.hasPrefix (toString (../. + "/src")) name) ../.;
        # todo: slimmed rocksdb
        buildInputs =
          (builtins.attrValues (pkgs.lib.getAttrs installedPackageNames self))
          ++ external-libs;
        nativeBuildInputs = [ self.dune self.ocamlfind pkgs.capnproto ]
          ++ builtins.attrValues (pkgs.lib.getAttrs installedPackageNames self);
        NIX_LDFLAGS = "-lsnappy -llz4 -lzstd";
        # TODO, get this from somewhere
        MARLIN_REPO_SHA = "bacef43ea34122286745578258066c29091dc36a";

        MINA_COMMIT_DATE = sourceInfo.lastModifiedDate or "<unknown>";
        MINA_COMMIT_SHA1 = sourceInfo.rev or "DIRTY";
        MINA_BRANCH = "<unknown>";

        OCAMLPARAM = "_,ccopt=-static";

        buildPhase = ''
          export MINA_ROOT="$NIX_BUILD_TOP/$sourceRoot"
          sed 's,/usr/local/lib/librocksdb_coda.a,${
            pkgs'.rocksdb.override { enableJemalloc = false; }
          }/lib/librocksdb.a,' -i src/external/ocaml-rocksdb/dune
          sed 's,make ,make GO_CAPNP_STD=${pkgs'.go-capnproto2.src}/std ,' -i src/libp2p_ipc/dune
          sed 's,cargo build --release,mkdir target,' -i src/lib/marlin_plonk_bindings/stubs/dune
          sed 's,target/release,${pkgs'.marlin_plonk_bindings_stubs}/lib,' -i src/lib/marlin_plonk_bindings/stubs/dune
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
