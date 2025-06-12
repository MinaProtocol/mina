# Overlay containing various overrides for nixpkgs packages used by Mina
final: prev: {
  sodium-static =
    final.libsodium.overrideAttrs (o: { dontDisableStatic = true; });

  # TODO: somehow enforce that version used here is
  #       same as used otherwise without Nix.
  rocksdb-mina =
    (final.rocksdb.override {
      snappy = null;
      lz4 = null;
      zstd = null;
      bzip2 = null;
      enableLiburing = false;
    }).overrideAttrs rec {
      version = "10.2.1";
      src = final.fetchFromGitHub {
        owner = "facebook";
        repo = "rocksdb";
        tag = "v${version}";
        hash = "sha256-v8kZShgz0O3nHZwWjTvhcM56qAs/le1XgMVYyvVd4tg=";
      };
      cmakeFlags = [
        "-DPORTABLE=1"
        "-DWITH_JEMALLOC=0"
        "-DWITH_LIBURING=0"
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
    };
}
