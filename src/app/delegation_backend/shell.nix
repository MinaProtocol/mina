with import <nixpkgs> { };
let
  minaSigner = import (fetchgit {
    url = "https://github.com/MinaProtocol/c-reference-signer.git";
    rev = "6f492281cdf0206aa1771019e322a1fce03f2b35";
    sha256 = "sha256:0x5jwcqqz045ki9zmi2yn90k7bg10r66xcr7j6fdhf3dwpcvgcfi";
  });
in {
  devEnv = stdenv.mkDerivation {
    name = "dev";
    buildInputs = [ stdenv go_1_19 glibc minaSigner ];
    shellHook = ''
      export PKG_MINA_SIGNER=${minaSigner}
      return
    '';
  };
}
