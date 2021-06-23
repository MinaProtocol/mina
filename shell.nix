with import <nixpkgs> {};
mkShell {
  nativeBuildInputs = 
    [ opam pkgconfig
      m4 openssl gmp jemalloc libffi
      libsodium postgresql
      rocksdb
      rustup # ships both cargo and rustc
      zlib bzip2
      capnproto go_1_16
      pythonPackages.jinja2
      pythonPackages.readchar
    ];
  shellHook = ''
    export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:${pkgs.postgresql.lib}/lib"
    eval $(opam env 2>/dev/null)
    '';
}
