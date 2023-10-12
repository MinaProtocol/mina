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
    "1.72" = "sha256-dxE7lmCFWlq0nl/wKcmYvpP9zqQbBitAQgZ1zx9Ooik=";
    "nightly-2023-09-01" = "sha256-zek9JAnRaoX8V0U2Y5ssXVe9tvoQ0ERGXfUCUGYdrMA=";
    # copy the placeholder line with the correct toolchain name when adding a new toolchain
    # That is,
    # 1. Put the correct version name;
    #
    # 2. Put the hash you get in line "got" from the error you obtain, which looks like
    #    error: hash mismatch in fixed-output derivation '/nix/store/XXXXX'
    #          specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
    #             got:    sha256-Q9UgzzvxLi4x9aWUJTn+/5EXekC98ODRU1TwhUs9RnY=
    "placeholder" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
  # rust-toolchain.toml -> { rustc, cargo, rust-analyzer, ... }
  rustChannelFromToolchainFileOf = file:
    with final.lib;
    let
      inherit (final.lib) hasPrefix removePrefix readFile warn;
      toolchain = (builtins.fromTOML (readFile file)).toolchain;
      # nice error message if the toolchain is missing
      placeholderPos = builtins.unsafeGetAttrPos "placeholder" toolchainHashes;
    in
    final.rustChannelOf rec {
      channel =
        if hasPrefix "nightly-" toolchain.channel then
          "nightly"
        else
          toolchain.channel;
      date =
        if channel == "nightly" then
          removePrefix "nightly-" toolchain.channel
        else
          null;
      sha256 = toolchainHashes.${toolchain.channel} or (warn ''
        Please add the rust toolchain hash (see error message below) for "${toolchain.channel}" at ${placeholderPos.file}:${
          toString placeholderPos.line
        }''
        toolchainHashes.placeholder);
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
    in
    mapFilterListToAttrs (x: x ? source && hasPrefix "git+" x.source)
      (x: {
        name = "${x.name}-${x.version}";
        value = (fetchGit {
          rev = last (split "#" x.source);
          url = last (split "\\+" (head (split "\\?" x.source)));
          allRefs = true;
        }).narHash;
      })
      package;
in
{

  kimchi_bindings_stubs =
    let
      toolchain = rustChannelFromToolchainFileOf
        ../src/lib/crypto/kimchi_bindings/stubs/rust-toolchain.toml;
      rust_platform = rustPlatformFor toolchain.rust;
    in
    rust_platform.buildRustPackage {
      pname = "kimchi_bindings_stubs";
      version = "0.1.0";
      src = final.lib.sourceByRegex ../src [
        "^lib(/crypto(/kimchi_bindings(/stubs(/.*)?)?)?)?$"
        "^lib(/crypto(/proof-systems(/.*)?)?)?$"
      ];
      sourceRoot = "source/lib/crypto/kimchi_bindings/stubs";
      nativeBuildInputs = [ final.ocamlPackages_mina.ocaml ];
      buildInputs = with final; lib.optional stdenv.isDarwin libiconv;
      cargoLock =
        let fixupLockFile = path: builtins.readFile path;
        in {
          lockFileContents =
            fixupLockFile ../src/lib/crypto/kimchi_bindings/stubs/Cargo.lock;
        };
      # FIXME: tests fail
      doCheck = false;
    };

  kimchi-rust = rustChannelFromToolchainFileOf
    ../src/lib/snarkyjs/src/bindings/kimchi/wasm/rust-toolchain.toml;

  # TODO: raise issue on nixpkgs and remove workaround when fix is applied
  kimchi-rust-wasm = (final.kimchi-rust.rust.override {
    targets = [ "wasm32-unknown-unknown" ];
    # rust-src is needed for -Zbuild-std
    extensions = [ "rust-src" ];
  }).overrideAttrs (oa: {
    nativeBuildInputs = oa.nativeBuildInputs or [ ] ++ [ final.makeWrapper ];
    buildCommand = oa.buildCommand + ''
      wrapProgram "$out/bin/rustc" --append-flags --sysroot --append-flags "$out"
    '';
  });

  # Work around https://github.com/rust-lang/wg-cargo-std-aware/issues/23
  kimchi-rust-std-deps = final.rustPlatform.importCargoLock {
    lockFile = final.runCommand "cargo.lock" { } ''
      cp ${final.kimchi-rust.rust-src}/lib/rustlib/src/rust/Cargo.lock $out
    '';
  };

  plonk_wasm =
    let

      lock = ../src/lib/snarkyjs/src/bindings/kimchi/wasm/Cargo.lock;

      deps = builtins.listToAttrs (map
        (pkg: {
          inherit (pkg) name;
          value = pkg;
        })
        (builtins.fromTOML (builtins.readFile lock)).package);

      rustPlatform = rustPlatformFor final.kimchi-rust-wasm;

      wasm-bindgen-cli = rustPlatform.buildRustPackage rec {

        pname = "wasm-bindgen-cli";
        version = deps.wasm-bindgen.version;
        src = final.fetchCrate {
          inherit pname version;
          sha256 = "sha256-0pTIzpu7dJM34CXmi83e8UV0E3N2bKJiOMw5WJQ2s/Y=";
        };

        cargoSha256 = "sha256-ZwmoFKmGaf5VvTTXjLyb2714Pu536E/8UxUzxI40ID8=";
        nativeBuildInputs = [ final.pkg-config ];

        buildInputs = with final;
          [ openssl ] ++ lib.optionals stdenv.isDarwin [
            curl
            darwin.apple_sdk.frameworks.Security
            libiconv
          ];

        checkInputs = [ final.nodejs ];

        # other tests, like --test=wasm-bindgen, require it to be ran in the
        # wasm-bindgen monorepo
        cargoTestFlags = [ "--test=reference" ];
      };
    in
    rustPlatform.buildRustPackage {
      pname = "plonk_wasm";
      version = "0.1.0";
      src = final.lib.sourceByRegex ../src [
        "^lib(/snarkyjs(/src(/bindings(/kimchi(/wasm(/.*)?)?)?)?)?)?$"
        "^lib(/crypto(/proof-systems(/.*)?)?)?$"
      ];
      sourceRoot = "source/lib/snarkyjs/src/bindings/kimchi/wasm";
      nativeBuildInputs = [ final.wasm-pack wasm-bindgen-cli ];
      buildInputs = with final; lib.optional stdenv.isDarwin libiconv;
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

  # Jobs/Lint/Rust.dhall
  trace-tool = final.rustPlatform.buildRustPackage rec {
    pname = "trace-tool";
    version = "0.1.0";
    src = ../src/app/trace-tool;
    cargoLock.lockFile = ../src/app/trace-tool/Cargo.lock;
  };
}
