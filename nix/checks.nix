inputs: pkgs: {

  # Jobs/Lint/OCaml.dhall
  lint-check-format = pkgs.stdenv.mkDerivation {
    # todo: only depend on ./src
    name = "lint-check-format";
    buildInputs = with inputs.self.ocamlPackages.${pkgs.system}; [
      exes.reformat
      ocamlformat
    ];
    src = ../.;
    buildPhase = "reformat -path . -check";
    installPhase = "touch $out";
    meta.checkDescription = "that OCaml code is formatted properly";
  };
}
