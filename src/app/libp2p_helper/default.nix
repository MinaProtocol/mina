with import <nixpkgs> {};
buildGoModule rec {
  name = "libp2p_helper-${version}";
  version = "0.1";
  src = ./src;
  modSha256 = "00kqp7y8igafnajddcqzqplrsfls4a67n2ivsq1ifw3dfviqwx7n";
}
