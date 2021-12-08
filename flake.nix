{
  description = "A very basic flake";
  inputs.utils.url = "github:gytis-ivaskevicius/flake-utils-plus";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";

  outputs = inputs@{ self, nixpkgs, utils }:
    utils.lib.mkFlake {
      inherit self inputs;
      supportedSystems = [ "x86_64-linux" ];
      channelsConfig.allowUnfree = true;
      outputsBuilder = channels: {

        packages.trace-tool = channels.nixpkgs.rustPlatform.buildRustPackage rec {
          pname = "trace-tool";
          version = "0.1.0";
          src = ./src/app/trace-tool;
          cargoLock.lockFile = ./src/app/trace-tool/Cargo.lock;
        };

      };
    };
}
