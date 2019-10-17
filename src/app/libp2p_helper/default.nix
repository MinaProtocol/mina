(import ../../../pinned-nixpkgs.nix).buildGoModule rec {
  name = "libp2p_helper-${version}";
  version = "0.1";
  src = ./src;
  modSha256 = "1spndcx0z50cmpfxfd0971nj9n0v77fghxl36hr1pvs6kv0ra5c3";
}

