with import
  (builtins.fetchTarball {
    url = "https://github.com/nixos/nixpkgs/archive/2fa862644fc15ecb525eb8cd0a60276f1c340c7c.tar.gz";
    sha256 = "00l884zydbrww2jxjvf62sm1y96jvys22jg9vb3fsznz2mbz41jb";
  }) {};
let
  sodium-static = libsodium.overrideAttrs (o: {
    dontDisableStatic = true;
  });
in
mkShell {
  name = "mina-shell";
  buildInputs = [
    opam
    pkg-config
    gnum4
    jemalloc
    gmp
    libffi
    openssl.dev
    postgresql.out
    sodium-static.out
    sodium-static.dev
    go
    capnproto
    zlib.dev
    bzip2.dev
  ];
  shellHook = ''
    eval $(opam env)
  '';
}
# opam init --bare
# opam switch import src/opam.export --switch mina
# eval $(opam env)
# ./scripts/pin-external-packages.sh
# make build
