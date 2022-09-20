# An overlay defining Rust parts&dependencies of Mina
final: prev:
let
  rustPlatformFor = rust:
    prev.makeRustPlatform {
      cargo = rust;
      rustc = rust;
      # override stdenv.targetPlatform here, if neccesary
    };
  toolchainHashes = {
    "1.58.1" = "sha256-NL+YHnOj1++1O7CAaQLijwAxKJW9SnHg8qsiOJ1m0Kk=";
    "nightly-2021-11-16" =
      "sha256-ErdLrUf9f3L/JtM5ghbefBMgsjDMYN3YHDTfGc008b4=";
    # copy this line with the correct toolchain name
    "placeholder" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
  rustChannelFromToolchainFileOf = file:
    with final.lib;
    let
      inherit (final.lib) hasPrefix removePrefix readFile warn;
      toolchain = (builtins.fromTOML (readFile file)).toolchain;
      # nice error message if the toolchain is missing
      placeholderPos = builtins.unsafeGetAttrPos "placeholder" toolchainHashes;
    in final.rustChannelOf rec {
      channel = if hasPrefix "nightly-" toolchain.channel then
        "nightly"
      else
        toolchain.channel;
      date = if channel == "nightly" then
        removePrefix "nightly-" toolchain.channel
      else
        null;
      sha256 = toolchainHashes.${toolchain.channel} or (warn ''
        Please add the rust toolchain hash (see error message below) for "${toolchain.channel}" at ${placeholderPos.file}:${
          toString placeholderPos.line
        }'' toolchainHashes.placeholder);
    };

  # mapFilterListToAttrs :: (x -> {name: str, value: b}) -> (x -> bool) -> [x] -> {b}
  mapFilterListToAttrs = f: m: l:
    builtins.listToAttrs (map m (builtins.filter f l));

  # extract git rev & urls from cargo lockfile, feed them to fetchgit to acquire
  # the sha256 hash that's used at build time
  # narHashesfromcargolock :: path -> {pkgname: hash}
  narHashesFromCargoLock = file:
    let
      inherit (final.lib) hasPrefix last head;
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

  kimchi_bindings_stubs = let
    toolchain = rustChannelFromToolchainFileOf
      ../src/lib/crypto/kimchi_bindings/stubs/rust-toolchain.toml;
    rust_platform = rustPlatformFor toolchain.rust;
  in rust_platform.buildRustPackage {
    pname = "kimchi_bindings_stubs";
    version = "0.1.0";
    src = final.lib.sourceByRegex ../src [
      "^lib(/crypto(/kimchi_bindings(/stubs(/.*)?)?)?)?$"
      "^lib(/crypto(/proof-systems(/.*)?)?)?$"
    ];
    sourceRoot = "source/lib/crypto/kimchi_bindings/stubs";
    nativeBuildInputs = [ final.ocamlPackages_mina.ocaml ];
    cargoLock = let fixupLockFile = path: builtins.readFile path;
    in {
      lockFileContents =
        fixupLockFile ../src/lib/crypto/kimchi_bindings/stubs/Cargo.lock;
    };
    # FIXME: tests fail
    doCheck = false;
  };

  kimchi-rust = rustChannelFromToolchainFileOf
    ../src/lib/crypto/kimchi_bindings/wasm/rust-toolchain.toml;
  kimchi-rust-wasm = final.kimchi-rust.rust.override {
    targets = [ "wasm32-unknown-unknown" ];
    # rust-src is needed for -Zbuild-std
    extensions = [ "rust-src" ];
  };

  # Work around https://github.com/rust-lang/wg-cargo-std-aware/issues/23
  kimchi-rust-std-deps = final.rustPlatform.importCargoLock {
    lockFile = final.runCommand "cargo.lock" { } ''
      cp ${final.kimchi-rust.rust-src}/lib/rustlib/src/rust/Cargo.lock $out
    '';
  };

  plonk_wasm = let

    lock = ../src/lib/crypto/kimchi_bindings/wasm/Cargo.lock;

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
        sha256 = "sha256-BQ8v3rCLUvyCCdxo5U+NHh30l9Jwvk9Sz8YQv6fa0SU=";
      };

      cargoSha256 = "sha256-mP85+qi2KA0GieaBzbrQOBqYxBZNRJipvd2brCRGyOM=";
      nativeBuildInputs = [ final.pkg-config ];

      buildInputs = with final;
        [ openssl ] ++ lib.optionals stdenv.isDarwin [
          curl
          darwin.apple_sdk.frameworks.Security
        ];

      checkInputs = [ final.nodejs ];

      # other tests require it to be ran in the wasm-bindgen monorepo
      cargoTestFlags = [ "--test=interface-types" ];
    };
  in rustPlatform.buildRustPackage {
    pname = "plonk_wasm";
    version = "0.1.0";
    src = final.lib.sourceByRegex ../src [
      "^lib(/crypto(/kimchi_bindings(/wasm(/.*)?)?)?)?$"
      "^lib(/crypto(/proof-systems(/.*)?)?)?$"
    ];
    sourceRoot = "source/lib/crypto/kimchi_bindings/wasm";
    nativeBuildInputs = [ final.wasm-pack wasm-bindgen-cli ];
    cargoLock.lockFile = lock;
    cargoLock.outputHashes = narHashesFromCargoLock lock;

    # Work around https://github.com/rust-lang/wg-cargo-std-aware/issues/23
    # Want to run after cargoSetupPostUnpackHook
    prePatch = ''
      chmod +w $NIX_BUILD_TOP/cargo-vendor-dir
      ln -sf ${final.kimchi-rust-std-deps}/*/ $NIX_BUILD_TOP/cargo-vendor-dir
      chmod -w $NIX_BUILD_TOP/cargo-vendor-dir
    '';

    # adapted from cargoBuildHook
    buildPhase = ''
      runHook preBuild
      (
      set -x
      export RUSTFLAGS="-C target-feature=+atomics,+bulk-memory,+mutable-globals -C link-arg=--no-check-features -C link-arg=--max-memory=4294967296"
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

