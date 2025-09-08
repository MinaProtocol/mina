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
    });
  };
}
