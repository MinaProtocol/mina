final: prev: {
  ocamlPackages = prev.ocamlPackages // {
    findlib = prev.ocamlPackages.findlib.overrideAttrs (old: {
      version = "1.9.3";
      src = prev.fetchFromGitHub {
        owner = "ocaml";
        repo  = "ocamlfind";
        rev   = "findlib-1.9.3";
        hash  = "sha256-lOAfGE0JKDtgFNnvbVQvJfUEKPqsqTQDFIZlJjenHUo=";
      };
      # Disable original patches that don't apply to GitHub source
      patches = [];
      # Apply necessary changes manually in postPatch
      postPatch = ''
        # Add ldconf="ignore" to findlib.conf.in (equivalent to ldconf.patch)
        echo 'ldconf="ignore"' >> findlib.conf.in
        
        # Fix INSTALL_TOPFIND paths (equivalent to install_topfind.patch) 
        sed -i 's|$(prefix)$(OCAML_CORE_STDLIB)|$(prefix)$(OCAML_SITELIB)|g' src/findlib/Makefile
      '';
    });
  };
}
