with import <nixpkgs> {};
buildGoModule rec {
  name = "libp2p_helper-${version}";
  version = "0.1";
  src = ./src;
  modSha256 = "0vcxbf0i97x5qwrz5r8lh54inwrcczwx9iap8fpcdhgi5myb01wg";
}
