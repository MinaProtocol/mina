((import (builtins.fetchTarball {
  name = "nixpkgs-stable-2019-12-05";
  url = https://github.com/nixos/nixpkgs/archive/19.09.tar.gz;
  sha256 = "0mhqhq21y5vrr1f30qd2bvydv4bbbslvyzclhw0kdxmkgg3z4c92";
  })) {}).buildGoModule rec {
  name = "libp2p_helper-${version}";
  version = "0.1";
  src = ./src;
  modSha256 = "06121zifvdx7dx611ang07wjclz7wvcccvaw4kk0nrwgn6gsd1q3";
}

