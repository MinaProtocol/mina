{ inputs, static ? false, ... }@args:
let
  opam-nix = inputs.opam-nix.lib.${pkgs.system};

  pkgs = if static then args.pkgs.pkgsMusl else args.pkgs;

  inherit (builtins) filterSource path;

  inherit (pkgs.lib) hasPrefix;

  external-repo =
    opam-nix.makeOpamRepoRec ../src/external; # Pin external packages
  repos = [ external-repo inputs.opam-repository ];

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

  filtered-src = path {
    path = filterSource (name: type:
      name == (toString (../. + "/dune"))
      || hasPrefix (toString (../. + "/src")) name) ../.;
    name = "mina";
  };

  overlay = self: super:
    let
      ocaml-libs =
        builtins.attrValues (pkgs.lib.getAttrs installedPackageNames self);
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

      mina = pkgs.stdenv.mkDerivation ({
        pname = "mina";
        version = "dev";
        # Prevent unnecessary rebuilds on non-source changes
        src = filtered-src;

      # TODO, get this from somewhere
      MARLIN_REPO_SHA = "<unknown>";
        MINA_COMMIT_DATE =
          if sourceInfo ? rev then sourceInfo.lastModifiedDate else "<unknown>";
        MINA_COMMIT_SHA1 = sourceInfo.rev or "DIRTY";
        MINA_BRANCH = "<unknown>";

        buildInputs = ocaml-libs ++ external-libs;
        nativeBuildInputs =
          [ self.dune self.ocamlfind pkgs.capnproto pkgs.removeReferencesTo ]
          ++ ocaml-libs;

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

      mina_client_sdk = pkgs.stdenv.mkDerivation {
        pname = "mina_client_sdk";
        version = "dev";
        src = filtered-src;

        buildInputs = ocaml-libs;

        buildPhase = ''
          export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$opam__zarith__lib/zarith"
          dune build --display=short src/app/client_sdk/client_sdk.bc.js --profile=nonconsensus_mainnet
        '';

        installPhase = ''
          mkdir -p $out/share/client_sdk
          mv _build/default/src/app/client_sdk/client_sdk.bc.js $out/share/client_sdk
        '';
      };
    };
in scope.overrideScope' overlay
