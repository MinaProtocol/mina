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

  # Jobs/Lint/ValidationService
  # Jobs/Test/ValidationService
  validation = ((final.mix-to-nix.override {
    beamPackages = final.beam.packagesWith final.erlangR23; # todo: jose
  }).mixToNix {
    src = ../src/app/validation;
    # todo: think about fixhexdep overlay
    # todo: dialyze
    overlay = (final: prev: {
      goth = prev.goth.overrideAttrs
        (o: { preConfigure = "sed -i '/warnings_as_errors/d' mix.exs"; });
    });
  });

}
