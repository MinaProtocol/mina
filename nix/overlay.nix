final: prev:
let pkgs = final;
in {
  # Overrides for dependencies

  sodium-static =
    pkgs.libsodium.overrideAttrs (o: { dontDisableStatic = true; });

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

  # Rust stuff (for marlin_plonk_bindings_stubs)
  rust-musl = (((final.rustChannelOf {
    channel = "nightly";
    sha256 = "sha256-eKL7cdPXGBICoc9FGMSHgUs6VGMg+3W2y/rXN8TuuAI=";
    date = "2021-12-27";
  }).rust.override { targets = [ "x86_64-unknown-linux-musl" ]; }).overrideAttrs
    (oa: {
      nativeBuildInputs = [ final.makeWrapper ];
      buildCommand = oa.buildCommand + ''
        for exe in $(find "$out/bin" -type f -or -type l); do
          wrapProgram "$exe" --prefix LD_LIBRARY_PATH : ${final.gcc-unwrapped.lib}/lib
        done
      '';
    })) // {
      inherit (prev.rust) toRustTarget toRustTargetSpec;
    };

  rustPlatform-musl = prev.makeRustPlatform {
    cargo = final.rust-musl;
    rustc = final.rust-musl;
  };

  # Dependencies which aren't in nixpkgs and local packages which need networking to build

  marlin_plonk_bindings_stubs = (if pkgs.stdenv.hostPlatform.isMusl then
    pkgs.rustPlatform-musl
  else
    pkgs.rustPlatform).buildRustPackage {
      pname = "marlin_plonk_bindings_stubs";
      version = "0.1.0";
      srcs = [ ../src/lib/marlin_plonk_bindings/stubs ../src/lib/marlin ];
      nativeBuildInputs = [ pkgs.ocamlPackages_mina.ocaml ];
      sourceRoot = "stubs";
      postUnpack = ''
        mkdir -p marlin_plonk_bindings
        mv stubs marlin_plonk_bindings
        export sourceRoot=marlin_plonk_bindings/stubs
      '';
      cargoLock.lockFile = ../src/lib/marlin_plonk_bindings/stubs/Cargo.lock;
    };

  go-capnproto2 = pkgs.buildGoModule rec {
    pname = "capnpc-go";
    version = "v3.0.0-alpha.1";
    vendorSha256 = "sha256-jbX/nnlnQoItFXFL/MZZKe4zAjM/EA3q+URJG8I3hok=";
    src = final.fetchFromGitHub {
      owner = "capnproto";
      repo = "go-capnproto2";
      rev = "v3.0.0-alpha.1";
      hash = "sha256-afdLw7of5AksR4ErCMqXqXCOnJ/nHK2Lo4xkC5McBfM";
    };
  };

  libp2p_ipc_go = pkgs.stdenv.mkDerivation {
    # todo: buildgomodule?
    name = "libp2p_ipc-go";
    buildInputs = [ pkgs.capnproto pkgs.go-capnproto2 ];
    src = ../src/libp2p_ipc;
    buildPhase = ''
      capnp compile -ogo -I${pkgs.go-capnproto2.src}/std libp2p_ipc.capnp
    '';
    installPhase = ''
      mkdir $out
      cp go.mod go.sum *.go $out/
    '';
  };
  # Jobs/Test/Libp2pUnitTest
  libp2p_helper = pkgs.buildGoModule {
    pname = "libp2p_helper";
    version = "0.1";
    src = ../src/app/libp2p_helper/src;
    runVend = true; # missing some schema files
    doCheck = false; # TODO: tests hang
    vendorSha256 =
      # sanity check, to make sure the fixed output drv doesn't keep working
      # when the inputs change
      if builtins.hashFile "sha256" ../src/app/libp2p_helper/src/go.mod
      == "4ce9e2efa7e35cce9b7b131bef15652830756f6f6da250afefd4751efa1d6565"
      && builtins.hashFile "sha256" ../src/app/libp2p_helper/src/go.sum
      == "8b90b3cee4be058eeca0bc9a5a2ee88d62cada9fb09785e0ced5e5cea7893192" then
        "sha256-MXLfE122UCNizqvGUu6WlThh1rnZueTqirCzaEWmbno="
      else
        pkgs.lib.warn
        "Please update the hashes in ${__curPos.file}#${toString __curPos.line}"
        pkgs.lib.fakeHash;
    NO_MDNS_TEST = 1; # no multicast support inside the nix sandbox
    overrideModAttrs = n: {
      # remove libp2p_ipc from go.mod, inject it back in postconfigure
      postConfigure = ''
        sed -i 's/.*libp2p_ipc.*//' go.mod
      '';
    };
    postConfigure = ''
      chmod +w vendor
      cp -r --reflink=auto ${pkgs.libp2p_ipc_go}/ vendor/libp2p_ipc
      sed -i 's/.*libp2p_ipc.*//' go.mod
    '';
  };
}
