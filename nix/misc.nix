# Overlay containing various overrides for nixpkgs packages used by Mina
final: prev: {
  sodium-static =
    final.libsodium.overrideAttrs (o: { dontDisableStatic = true; });

    rocksdb = final.stdenv.mkDerivation (_:
      let
        buildAndInstallFlags = [
          "USE_RTTI=1"
          "DEBUG_LEVEL=0"
          "DISABLE_WARNING_AS_ERROR=1"
        ];
      in
      {
        pname = "rocksdb";
        version = "5.11.3";

        src = final.fetchFromGitHub {
          owner = "facebook";
          repo = "rocksdb";
          rev = "v5.11.3";
          hash = "sha256:15x2r7aib1xinwcchl32wghs8g96k4q5xgv6z97mxgp35475x01p";
        };

        outputs = [ "out" ];

        nativeBuildInputs = with final; [ which perl ];
        buildInputs = with final; [ google-gflags ];

        postPatch = ''
          # Hack to fix typos
          sed -i 's,#inlcude,#include,g' build_tools/build_detect_platform
        '';

        # Environment vars used for building certain configurations
        PORTABLE = "1";
        USE_SSE = "1";
        CMAKE_CXX_FLAGS = "-std=gnu++11";
        JEMALLOC_LIB = "";

        # ${if enableLite then "LIBNAME" else null} = "librocksdb_lite";
        # ${if enableLite then "CXXFLAGS" else null} = "-DROCKSDB_LITE=1";

        buildFlags = buildAndInstallFlags ++ [
          "static_lib"
        ];

        installFlags = buildAndInstallFlags ++ [
          "INSTALL_PATH=\${out}"
          "install-static"
        ];

        enableParallelBuilding = true;

        meta = with final.lib; {
          homepage = http://rocksdb.org;
          description = "A library that provides an embeddable, persistent key-value store for fast storage";
          license = licenses.bsd3;
          platforms = platforms.all;
          maintainers = with maintainers; [ adev wkennington ];
        };
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
