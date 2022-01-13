final: prev:
let pkgs = final;
in {
  postgresql =
    (prev.postgresql.override { enableSystemd = false; }).overrideAttrs
    (o: { doCheck = !prev.stdenv.hostPlatform.isMusl; });
  openssh = (if prev.stdenv.hostPlatform.isMusl then
    (prev.openssh.override {
      # todo: fix libredirect musl
      libredirect = "";
    }).overrideAttrs (o: { doCheck = !prev.stdenv.hostPlatform.isMusl; })
  else
    prev.openssh);

  jemalloc = prev.jemalloc.overrideAttrs (_: {
    nativeBuildInputs = [ final.autoconf ];
    preConfigure = "./autogen.sh";
    src = final.fetchFromGitHub {
      owner = "jemalloc";
      repo = "jemalloc";
      rev = "011449f17bdddd4c9e0510b27a3fb34e88d072ca";
      sha256 = "FwMs8m/yYsXCEOd94ZWgpwqtVrTLncEQCSDj/FqGewE=";
    };
  });

  git = prev.git.overrideAttrs
    (o: { doCheck = o.doCheck && !prev.stdenv.hostPlatform.isMusl; });
  #mozillaOverlay = import (builtins.fetchTarball https://github.com/mozilla/nixpkgs-mozilla/archive/master.tar.gz); nixpkgs = import nixpkgs-unstable { overlays = [ mozillaOverlay ]; }; rust = (nixpkgs.rustChannelOf { channel = "nightly"; }).rust.override { targets = [ "x86_64-unknown-linux-musl" ]; }; rustPlatform = nixpkgs.makeRustPlatform { cargo = rust; rustc = rust; }; in nixpkgs.stdenv.mkDerivation { name = "rust-env"; nativeBuildInputs = [ rustPlatform.rust.cargo rustPlatform.rust.rustc nixpkgs.file ]; }
  pkgs_normal = import (final.path) {
    overlays = final.overlays;
    system = "x86_64-linux";
  };
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
  sodium-static =
    pkgs.libsodium.overrideAttrs (o: { dontDisableStatic = true; });

  marlin_plonk_bindings_stubs = pkgs.rustPlatform-musl.buildRustPackage {
    pname = "marlin_plonk_bindings_stubs";
    version = "0.1.0";
    srcs = [ ../src/lib/marlin_plonk_bindings/stubs ../src/lib/marlin ];
    nativeBuildInputs = [ pkgs.ocaml-ng.ocamlPackages_4_11.ocaml ];
    sourceRoot = "stubs";
    postUnpack = ''
      mkdir -p marlin_plonk_bindings
      mv stubs marlin_plonk_bindings
      export sourceRoot=marlin_plonk_bindings/stubs
    '';
    cargoLock.lockFile = ../src/lib/marlin_plonk_bindings/stubs/Cargo.lock;
  };

  # Jobs/Test/Libp2pUnitTest
  libp2p_helper = pkgs.buildGoModule {
    pname = "libp2p_helper";
    version = "0.1";
    src = ../src/app/libp2p_helper/src;
    runVend = true; # missing some schema files
    vendorSha256 = "sha256-g0DsuLMiXjUTsGbhCSeFKEFKMEMtg3UTUjmYwUka6iE=";
    postConfigure = ''
      chmod +w vendor
      cp -r --reflink=auto ${pkgs.libp2p_ipc_go}/ vendor/libp2p_ipc
    '';
    NO_MDNS_TEST = 1; # no multicast support inside the nix sandbox
    overrideModAttrs = n: {
      # remove libp2p_ipc from go.mod, inject it back in postconfigure
      postConfigure = ''
        sed -i '/libp2p_ipc/d' go.mod
      '';
    };
  };
}
