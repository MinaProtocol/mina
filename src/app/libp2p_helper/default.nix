((import (builtins.fetchTarball {
  name = "nixpkgs-unstable-2019-03-18";
  url = https://github.com/nixos/nixpkgs/archive/0125544e2a0552590c87dca1583768b49ba911c0.tar.gz;
  sha256 = "04xvlqw3zbq91zkfa506b2k1ajmj7pqh3nvdh9maabw6m5jhm5rl";
  })) {}).buildGoModule rec {
  name = "libp2p_helper-${version}";
  version = "0.1";
  src = ./src;
  modSha256 = "1ld6d6kz4d1dcm883dwsysn8k4agpndykd917n96w7yc2irqwafd";
}

