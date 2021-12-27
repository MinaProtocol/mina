self: super:
let

  fake-cxx = self.nixpkgs.writeShellScriptBin "g++" ''$CXX "$@"'';
  fake-cc = self.nixpkgs.writeShellScriptBin "cc" ''$CC "$@"'';

in {
  "conf-g++" = super."conf-g++".overrideAttrs
    (oa: { nativeBuildInputs = oa.nativeBuildInputs ++ [ fake-cxx ]; });

  ppx_deriving = self.nixpkgs.pkgsBuildBuild.ocamlPackages.ppx_deriving;

  sodium = super.sodium.overrideAttrs (oa: {
    buildInputs = oa.buildInputs ++ [ self.nixpkgs.sodium-static ];
    nativeBuildInputs = oa.nativeBuildInputs ++ [ fake-cc ];
    buildPhase = ''
      ocamlbuild lib/sodium.cma lib/sodium.cmxa
    '';
    installPhase = ''
	  ocamlfind install sodium lib/META \
		  $(addprefix _build/lib/,sodium.mli sodium.cmi sodium.cmti \
			  sodium.cma sodium.cmx sodium.cmxa sodium.cmxs \
		                        sodium$(EXT_LIB) \
					libsodium_stubs$(EXT_LIB))
    '';
  });

  conf-gmp = super.conf-gmp.overrideAttrs
    (oa: { nativeBuildInputs = oa.nativeBuildInputs ++ [ fake-cc ]; });

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
      make PREFIX=$out LIBDIR=$OCAMLFIND_DESTDIR/cmdliner install-common install-native
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
