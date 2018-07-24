with import <nixpkgs>{};

stdenv.mkDerivation rec {
  name = "coda";
  version = "0.1.0";
  buildInputs = [
    spirv-tools
  ];
}
