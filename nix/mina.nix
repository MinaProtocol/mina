inputs:
pkgs:
let
  opam-nix = inputs.opam-nix.lib.${pkgs.system};

  repos = [
    (opam-nix.makeOpamRepo ../src/external) # Pin external packages
    ./fake-opam-repo # Remove opam version restriction imposed by a depext dependency
    inputs.opam-repository
  ];

  export = opam-nix.opamListToQuery
    (opam-nix.fromOPAM ../src/opam.export).installed;
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

  scope = opam-nix.queryToScope { inherit repos pkgs; }
    (export // external-packages // query);

  installedPackageNames =
    map (x: (opam-nix.splitNameVer x).name) (builtins.attrNames implicit-deps);

  sourceInfo = inputs.self.sourceInfo or {};

  overlay = self: super:
    let
      deps = builtins.attrValues (pkgs.lib.getAttrs installedPackageNames self);

      unique' = builtins.foldl' (acc: e:
        if builtins.elem (toString e) (map toString acc) then
          acc
        else
          acc ++ [ e ]) [ ];

      propagatedExternalBuildInputs = pkgs.lib.concatMap (dep:
        pkgs.lib.optionals (dep ? passthru.pkgdef)
        (dep.buildInputs or [ ] ++ dep.propagatedBuildInputs or [ ]))
        deps;
    in {
      sodium = super.sodium.overrideAttrs (_: {
        NIX_CFLAGS_COMPILE = "-I${pkgs.sodium-static.dev}/include";
        propagatedBuildInputs = [pkgs.sodium-static];
        preBuild = ''
          export LD_LIBRARY_PATH="${super.ctypes}/lib/ocaml/${super.ocaml.version}/site-lib/ctypes";
        '';
      });

      mina = pkgs.stdenv.mkDerivation {
        pname = "mina";
        version = "dev";
        src = ../src;
        # todo: slimmed rocksdb
        buildInputs = unique' (deps ++ propagatedExternalBuildInputs ++ [pkgs.zlib pkgs.bzip2 pkgs.snappy pkgs.lz4 pkgs.zstd]);
        nativeBuildInputs = [ self.dune self.ocamlfind ];
        NIX_LDFLAGS = "-lsnappy -llz4 -lzstd";
        # TODO, get this from somewhere
        MARLIN_REPO_SHA = "bacef43ea34122286745578258066c29091dc36a";

        MINA_COMMIT_DATE = sourceInfo.lastModifiedDate or "<unknown>";
        MINA_COMMIT_SHA1 = sourceInfo.rev or "DIRTY";
        MINA_BRANCH = "<unknown>";

        buildPhase = ''
          export MINA_ROOT="$NIX_BUILD_TOP/$sourceRoot"
          sed 's,/usr/local/lib/librocksdb_coda.a,${pkgs.rocksdb}/lib/librocksdb.a,' -i external/ocaml-rocksdb/dune
          sed 's,make ,make GO_CAPNP_STD=${pkgs.go-capnproto2.src}/std ,' -i libp2p_ipc/dune
          sed 's,cargo build --release,mkdir target,' -i lib/marlin_plonk_bindings/stubs/dune
          sed 's,target/release,${pkgs.marlin_plonk_bindings_stubs}/lib,' -i lib/marlin_plonk_bindings/stubs/dune
          patchShebangs .
          dune build app/logproc/logproc.exe app/cli/src/mina.exe -j$NIX_BUILD_CORES
        '';
        installPhase = ''
          mkdir -p $out/bin
          mv _build/default/app/{logproc/logproc.exe,cli/src/mina.exe} $out/bin
        '';
      };
    };
in scope.overrideScope' overlay
