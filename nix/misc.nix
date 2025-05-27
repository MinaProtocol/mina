# Overlay containing various overrides for nixpkgs packages used by Mina
final: prev: {
  sodium-static =
    final.libsodium.overrideAttrs (o: { dontDisableStatic = true; });

  rocksdb = (prev.rocksdb.override {
    snappy = null;
    lz4 = null;
    zstd = null;
    bzip2 = null;
  }).overrideAttrs (_: {
    cmakeFlags = [
      "-DPORTABLE=1"
      "-DWITH_JEMALLOC=0"
      "-DWITH_JNI=0"
      "-DWITH_BENCHMARK_TOOLS=0"
      "-DWITH_TESTS=1"
      "-DWITH_TOOLS=0"
      "-DWITH_BZ2=0"
      "-DWITH_LZ4=0"
      "-DWITH_SNAPPY=0"
      "-DWITH_ZLIB=0"
      "-DWITH_ZSTD=0"
      "-DWITH_GFLAGS=0"
      "-DUSE_RTTI=1"
    ];
  });

  rocksdb511 = let
    impl = (import (fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/archive/nixos-19.03-small.tar.gz";
      sha256 = "11z6ajj108fy2q5g8y4higlcaqncrbjm3dnv17pvif6avagw4mcb";
    }) { system = "x86_64-linux"; }).rocksdb.override {
      snappy = null;
      lz4 = null;
      bzip2 = null;
    };
  in if impl.version == "5.11.3" then
    impl
  else
    throw "Expected rocksdb version 5.11.3, but got ${impl.version}";
}
