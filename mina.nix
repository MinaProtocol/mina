inputs:
pkgs:
let
  opam-nix = inputs.opam-nix.lib.${pkgs.system};

  repos = {
    default = pkgs.runCommand "opam-repository-depext-fix" {
      src = inputs.opam-repository;
    } ''
      cp --no-preserve=all -R $src $out
      sed 's/available: .*//' -i $out/packages/depext/depext.transition/opam
    '';

    mina = opam-nix.makeOpamRepo ./src/external;
  };

  export = opam-nix.opamListToQuery
    (opam-nix.fromOPAM ./src/opam.export).installed;
  external-packages = {
    "sodium" = null;
    "capnp" = null;
    "rpc_parallel" = null;
    "ocaml-extlib" = null;
    "async_kernel" = null;
    "base58" = null;
    "graphql_ppx" = null;
    "ppx_deriving_yojson" = null;
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
        NIX_CFLAGS_COMPILE = "-I${super.native.libsodium.dev}/include";
        preBuild = ''
          export LD_LIBRARY_PATH="${super.ctypes}/lib/ocaml/${super.ocaml.version}/site-lib/ctypes";
        '';
      });

      mina = pkgs.stdenv.mkDerivation {
        pname = "mina";
        version = "dev";
        src = ./.;
        buildInputs = unique' (deps ++ propagatedExternalBuildInputs);
        nativeBuildInputs = [ self.dune self.ocamlfind pkgs.cargo pkgs.rustc ];

        buildPhase = ''
          sed 's/mina_version.normal/mina_version.dummy/' -i src/lib/mina_version/dune
          sed 's,/usr/local/lib/librocksdb_coda.a,${pkgs.rocksdb}/lib/librocksdb.a,' -i src/external/ocaml-rocksdb/dune
          dune build src/app/logproc/logproc.exe src/app/cli/src/mina.exe
        '';
        installPhase = ''
          mkdir -p $out/bin
          mv src/app/logproc/logproc.exe src/app/cli/src/mina.exe $out/bin
        '';
      };
    };
in scope.overrideScope' overlay
