inputs: pkgs: {

  # todo: Fast
  lint-codeowners = pkgs.stdenv.mkDerivation {
    # todo: filter source
    name = "lint-codeowners";
    src = ../.;
    # todo: submodules :(
    buildPhase = ''
      mkdir -p src/lib/snarky
      bash ./scripts/lint_codeowners.sh
    '';
    installPhase = "touch $out";
  };
  # todo: this check succeeds with 0 rfcs
  lint-rfcs = pkgs.runCommand "lint-rfcs" { } ''
    ln -s ${../rfcs} ./rfcs
    bash ${../scripts/lint_rfcs.sh}
    touch $out
  '';
  # todo: ./scripts/check-snarky-submodule.sh # submodule issue
  lint-preprocessor-deps = pkgs.runCommand "lint-preprocessor-deps" { } ''
    ln -s ${../src} ./src
    bash ${../scripts/lint_preprocessor_deps.sh}
    touch $out
  '';
  # - compare ci diff_types
  # - compare_ci_diff_binables

  # todo: helmchart
  # todo: merges cleanly into develop -- wait why
  # todo: TestnetAlerts

  # Jobs/Lint/OCaml.dhall
  lint-check-format = pkgs.stdenv.mkDerivation {
    # todo: only depend on ./src
    name = "lint-check-format";
    buildInputs = with inputs.self.ocamlPackages.${pkgs.system}; [
        ocaml
        dune
        base_quickcheck
        ocamlfind
        async
        ocamlformat
        ppx_jane
      ];
    src = ../.;
    buildPhase = "make check-format";
    installPhase = "touch $out";
  };

  # todo: libp2p_ipc
  require-ppxs = pkgs.stdenv.mkDerivation {
    name = "require-ppxs";
    # todo: only depend on dune files
    src = ../.;
    buildInputs = [ (pkgs.python3.withPackages (p: [ p.sexpdata ])) ];
    buildPhase = "python ./scripts/require-ppxs.py";
    installPhase = "touch $out";
  };

}
