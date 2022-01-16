{ inputs, static ? false, ... }@args:
let
  opam-nix = inputs.opam-nix.lib.${pkgs.system};

  pkgs = if static then args.pkgs.pkgsMusl else args.pkgs;

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

  overlay = self: super: {
    sodium = super.sodium.overrideAttrs (_: {
      NIX_CFLAGS_COMPILE = "-I${pkgs.sodium-static.dev}/include";
      propagatedBuildInputs = [ pkgs.sodium-static ];
      preBuild = ''
        export LD_LIBRARY_PATH="${super.ctypes}/lib/ocaml/${super.ocaml.version}/site-lib/ctypes";
      '';
    });

    rpc_parallel = super.rpc_parallel.overrideAttrs
      (oa: { buildInputs = oa.buildInputs ++ [ self.ctypes ]; });

    mina = pkgs.stdenv.mkDerivation ({
      pname = "mina";
      version = "dev";
      # Prevent unnecessary rebuilds on non-source changes
      src = builtins.filterSource (name: type:
        name == (toString (../. + "/dune"))
        || pkgs.lib.hasPrefix (toString (../. + "/src")) name) ../.;
      # TODO, get this from somewhere
      MARLIN_REPO_SHA = "<unknown>";

      MINA_COMMIT_DATE = sourceInfo.lastModifiedDate or "<unknown>";
      MINA_COMMIT_SHA1 = sourceInfo.rev or "DIRTY";
      MINA_BRANCH = "<unknown>";

      buildInputs =
        (builtins.attrValues (pkgs.lib.getAttrs installedPackageNames self))
        ++ external-libs;
      nativeBuildInputs = [ self.dune self.ocamlfind pkgs.capnproto pkgs.removeReferencesTo ]
        ++ builtins.attrValues (pkgs.lib.getAttrs installedPackageNames self);

      # todo: slimmed rocksdb
      MINA_ROCKSDB = "${pkgs.rocksdb}/lib/librocksdb.a";
      GO_CAPNP_STD = "${pkgs.go-capnproto2.src}/std";
      MARLIN_PLONK_STUBS = "${pkgs.marlin_plonk_bindings_stubs}/lib";

      configurePhase = ''
        export MINA_ROOT="$PWD"
        patchShebangs .
      '';

      buildPhase = ''
        dune build --display=short src/app/logproc/logproc.exe src/app/cli/src/mina.exe -j$NIX_BUILD_CORES
      '';

      installPhase = ''
        mkdir -p $out/bin
        mv _build/default/src/app/{logproc/logproc.exe,cli/src/mina.exe} $out/bin
        remove-references-to -t $(dirname $(dirname $(command -v ocaml))) $out/bin/*
      '';
    } // pkgs.lib.optionalAttrs static { OCAMLPARAM = "_,ccopt=-static"; });
  };
in scope.overrideScope' overlay
