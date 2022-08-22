# An overlay defining Rust parts&dependencies of Mina
final: prev: {
  marlin_plonk_bindings_stubs = final.rustPlatform.buildRustPackage {
    pname = "marlin_plonk_bindings_stubs";
    version = "0.1.0";
    srcs = [ ../src/lib/marlin_plonk_bindings/stubs ../src/lib/marlin ];
    nativeBuildInputs = [ final.ocamlPackages_mina.ocaml ];
    sourceRoot = "stubs";
    postUnpack = ''
      mkdir -p marlin_plonk_bindings
      mv stubs marlin_plonk_bindings
      export sourceRoot=marlin_plonk_bindings/stubs
    '';
    cargoLock.lockFile = ../src/lib/marlin_plonk_bindings/stubs/Cargo.lock;
  };
}