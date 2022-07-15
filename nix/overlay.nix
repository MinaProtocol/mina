final: prev:
let
  pkgs = final;
  rustPlatformFor = rust:
    prev.makeRustPlatform {
      cargo = rust;
      rustc = rust;
      # override stdenv.targetPlatform here, if neccesary
    };
  toolchainHashes = {
    "1.58.0" = "sha256-eQBpSmy9+oHfVyPs0Ea+GVZ0fvIatj6QVhNhYKOJ6Jk=";
    "nightly-2021-11-16" = "sha256-ErdLrUf9f3L/JtM5ghbefBMgsjDMYN3YHDTfGc008b4=";
    # copy this line with the correct toolchain name
    "placeholder" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
  cargoHashes = narHashesFromCargoLock ../src/lib/crypto/Cargo.lock;
  rustChannelFromToolchainFileOf = file: with pkgs.lib; let
    inherit (pkgs.lib) hasPrefix removePrefix readFile warn;
    toolchain = (builtins.fromTOML (readFile file)).toolchain;
    # nice error message if the toolchain is missing
    placeholderPos = builtins.unsafeGetAttrPos "placeholder" toolchainHashes;
    in pkgs.rustChannelOf rec {
      channel = if hasPrefix "nightly-" toolchain.channel then "nightly" else toolchain.channel;
      date = if channel == "nightly" then removePrefix "nightly-" toolchain.channel else null;
      sha256 = toolchainHashes.${toolchain.channel} or
        (warn ''Please add the rust toolchain hash (see error message below) for "${toolchain.channel}" at ${placeholderPos.file}:${toString placeholderPos.line}'' toolchainHashes.placeholder);
    };

  # mapFilterListToAttrs :: (x -> {name: str, value: b}) -> (x -> bool) -> [x] -> {b}
  mapFilterListToAttrs = f: m: l:
    builtins.listToAttrs (map m (builtins.filter f l));

  # extract git rev & urls from cargo lockfile, feed them to fetchgit to acquire
  # the sha256 hash that's used at build time
  # narHashesfromcargolock :: path -> {pkgname: hash}
  narHashesFromCargoLock = file:
    let
      inherit (pkgs.lib) hasPrefix last head;
      inherit (builtins) split readFile;
      package = (fromTOML (readFile file)).package;
    in mapFilterListToAttrs (x: x ? source && hasPrefix "git+" x.source) (x: {
      name = "${x.name}-${x.version}";
      value = (fetchGit {
        rev = last (split "#" x.source);
        url = last (split "\\+" (head (split "\\?" x.source)));
        allRefs = true;
      }).narHash;
    }) package;
in {
  # nixpkgs + musl problems
  postgresql =
    (prev.postgresql.override { enableSystemd = false; }).overrideAttrs
    (o: { doCheck = false; });

  openssh = (if prev.stdenv.hostPlatform.isMusl then
    (prev.openssh.override {
      # todo: fix libredirect musl
      libredirect = "";
    }).overrideAttrs (o: { doCheck = !prev.stdenv.hostPlatform.isMusl; })
  else
    prev.openssh);

  git = prev.git.overrideAttrs
    (o: { doCheck = o.doCheck && !prev.stdenv.hostPlatform.isMusl; });

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
  crypto-rust-musl = ((final.crypto-rust.override {
    targets = [ "x86_64-unknown-linux-musl" ];
  }).overrideAttrs (oa: {
    nativeBuildInputs = [ final.makeWrapper ];
    buildCommand = oa.buildCommand + ''
      for exe in $(find "$out/bin" -type f -or -type l); do
        wrapProgram "$exe" --prefix LD_LIBRARY_PATH : ${final.gcc-unwrapped.lib}/lib
      done
    '';
  })) // {
    inherit (prev.rust) toRustTarget toRustTargetSpec;
  };

  crypto-rust = (rustChannelFromToolchainFileOf ../src/lib/crypto/rust-toolchain.toml).rust;

  # Dependencies which aren't in nixpkgs and local packages which need networking to build
  kimchi_bindings_stubs = (rustPlatformFor
    (if pkgs.stdenv.hostPlatform.isMusl then
      final.crypto-rust-musl
    else
      final.crypto-rust)).buildRustPackage {
        pname = "kimchi_bindings_stubs";
        version = "0.1.0";
        src = final.lib.sourceByRegex ../src [
          "^lib(/crypto(/.*)?)?$"
          "^external(/wasm-bindgen-rayon(/.*)?)?"
        ];
        cargoBuildFlags = ["-p wires_15_stubs" "-p binding_generation"];
        sourceRoot = "source/lib/crypto";
        nativeBuildInputs = [ pkgs.ocamlPackages_mina.ocaml ];
        # FIXME: tests fail
        doCheck = false;
        cargoLock.lockFile = ../src/lib/crypto/Cargo.lock;
        cargoLock.outputHashes = cargoHashes;
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

  kimchi-rust = rustChannelFromToolchainFileOf ../src/lib/crypto/kimchi_bindings/wasm/rust-toolchain.toml;
  kimchi-rust-wasm = pkgs.kimchi-rust.rust.override {
    targets = [ "wasm32-unknown-unknown" ];
    # rust-src is needed for -Zbuild-std
    extensions = [ "rust-src" ];
  };

  # Work around https://github.com/rust-lang/wg-cargo-std-aware/issues/23
  kimchi-rust-std-deps = pkgs.rustPlatform.importCargoLock {
    lockFile = pkgs.runCommand "cargo.lock" { } ''
      cp ${pkgs.kimchi-rust.rust-src}/lib/rustlib/src/rust/Cargo.lock $out
    '';
  };

  plonk_wasm = let

    lock = ../src/lib/crypto/Cargo.lock;

    deps = builtins.listToAttrs (map (pkg: {
      inherit (pkg) name;
      value = pkg;
    }) (builtins.fromTOML (builtins.readFile lock)).package);

    rustPlatform = rustPlatformFor final.kimchi-rust-wasm;

    wasm-bindgen-cli = rustPlatform.buildRustPackage rec {

      pname = "wasm-bindgen-cli";
      version = deps.wasm-bindgen.version;
      src = final.fetchCrate {
        inherit pname version;
        sha256 = "sha256-DUcY22b9+PD6RD53CwcoB+ynGulYTEYjkkonDNeLbGM=";
      };

      cargoSha256 = "sha256-mfVQ6rSzCgwYrN9WwydEpkm6k0E3302Kfs/LaGzRSHE=";
      nativeBuildInputs = [ final.pkg-config ];

      buildInputs = with final;
        [ openssl ] ++ lib.optionals stdenv.isDarwin [ curl darwin.apple_sdk.frameworks.Security ];

      checkInputs = [ final.nodejs ];

      # other tests require it to be ran in the wasm-bindgen monorepo
      cargoTestFlags = [ "--test=interface-types" ];
    };
  in rustPlatform.buildRustPackage {
    pname = "plonk_wasm";
    version = "0.1.0";
    src = final.lib.sourceByRegex ../src [
      "^lib(/crypto(/.*)?)?$"
      "^lib/crypto/Cargo\.(lock|toml)$"
      "^lib(/crypto(/kimchi_bindings(/wasm(/.*)?)?)?)?$"
      "^lib(/crypto(/proof-systems(/.*)?)?)?$"
    ];
    sourceRoot = "source/lib/crypto";
    nativeBuildInputs = [ pkgs.wasm-pack wasm-bindgen-cli ];
    cargoLock.lockFile = lock;
    cargoLock.outputHashes = cargoHashes;

    # Work around https://github.com/rust-lang/wg-cargo-std-aware/issues/23
    # Want to run after cargoSetupPostUnpackHook
    prePatch = ''
      chmod +w $NIX_BUILD_TOP/cargo-vendor-dir
      ln -sf ${pkgs.kimchi-rust-std-deps}/*/ $NIX_BUILD_TOP/cargo-vendor-dir
      chmod -w $NIX_BUILD_TOP/cargo-vendor-dir
    '';

    # adapted from cargoBuildHook
    buildPhase = ''
      runHook preBuild
      (
      set -x
      export RUSTFLAGS="-C target-feature=+atomics,+bulk-memory,+mutable-globals -C link-arg=--no-check-features -C link-arg=--max-memory=4294967296"
      cd kimchi_bindings/wasm
      wasm-pack build --mode no-install --target nodejs --out-dir $out/nodejs ./. -- --features nodejs
      wasm-pack build --mode no-install --target web --out-dir $out/web ./.
      )
      runHook postBuild
    '';
    dontCargoBuild = true;
    dontCargoCheck = true;
    installPhase = ":";
    cargoBuildFeatures = [ "nodejs" ];
  };
}
