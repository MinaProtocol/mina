with import <nixpkgs> { };

stdenv.mkDerivation {
  name = "sage-nix";

  buildInputs = [ sage ];

  shellHook = ''
    export SAGE_PATH=".:$SAGE_PATH"
  '';
}

