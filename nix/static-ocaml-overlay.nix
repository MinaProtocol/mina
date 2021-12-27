self: super: {
    conf-gmp = super.conf-gmp.overrideAttrs (oa: {
      nativeBuildInputs = oa.nativeBuildInputs ++ [
        (self.nixpkgs.writeShellScriptBin "cc" ''$CC "$@"'')
      ];
    });

    base58 = super.base58.overrideAttrs (oa: {
      buildPhase = ''
        make lib.byte
        ocamlbuild -I src -I tests base58.cmxa
      '';
    });

    zarith = super.zarith.overrideAttrs (oa: {
      preBuild = ''
        sed "s/ar='ar'/ar='$AR'/" -i configure
      '';
    });

    digestif = super.digestif.overrideAttrs (oa: {
      buildPhase = ''
        dune build -p digestif -j $NIX_BUILD_CORES
      '';
    });

    cmdliner = super.cmdliner.overrideAttrs (oa: {
      buildPhase = ''
        make build-byte build-native
      '';
      installPhase = ''
        make PREFIX=$out LIBDIR=$OCAMLFIND_DESTDIR install-common install-native
      '';
    });

    ocaml-extlib = super.ocaml-extlib.overrideAttrs (oa: {
      buildPhase = ''
        make -C src all opt
      '';
    });

    ocamlgraph = super.ocamlgraph.overrideAttrs (oa: {
      buildPhase = ''
        ./configure
        sed 's/graph.cmxs//' -i Makefile
        make NATIVE_DYNLINK=false
      '';
    });


}
