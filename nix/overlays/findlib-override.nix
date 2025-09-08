final: prev: 
let 
  findlibOverride = old: {
    version = "1.9.3";
    src = prev.fetchFromGitHub {
      owner = "ocaml";
      repo  = "ocamlfind";
      rev   = "findlib-1.9.3";
      hash  = "sha256-lOAfGE0JKDtgFNnvbVQvJfUEKPqsqTQDFIZlJjenHUo=";
    };
    patches = [];
    postPatch = ''
      echo 'ldconf="ignore"' >> findlib.conf.in
      sed -i 's|$(prefix)$(OCAML_CORE_STDLIB)|$(prefix)$(OCAML_SITELIB)|g' src/findlib/Makefile
    '';
  };
in {
  # Override findlib everywhere it might be used
  ocamlPackages = prev.ocamlPackages.overrideScope (self: super: {
    findlib = super.findlib.overrideAttrs findlibOverride;
  });
  
  # Also override in ocaml-ng if it exists
  ocaml-ng = prev.ocaml-ng or {} // {
    ocamlPackages_4_14 = (prev.ocaml-ng.ocamlPackages_4_14 or prev.ocamlPackages).overrideScope (self: super: {
      findlib = super.findlib.overrideAttrs findlibOverride;
    });
  };
}
