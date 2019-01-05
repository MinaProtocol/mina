{ compiler ? "ghc863" }:

let
  config = {
    packageOverrides = pkgs: rec {
      haskell = pkgs.haskell // {
        packages = pkgs.haskell.packages // {
          "${compiler}" = pkgs.haskell.packages."${compiler}".override {
            overrides = haskellPackagesNew: haskellPackagesOld: rec {
              kademlia = haskellPackagesNew.callPackage ./prefetch/kademlia1101.nix { };

              project1 =
                haskellPackagesNew.callPackage ./default.nix { };
            };
          };
        };
      };
    };
  };

  pkgs = import <nixpkgs> { inherit config; };

in
  { project1 = pkgs.haskell.packages.${compiler}.project1;
  }

