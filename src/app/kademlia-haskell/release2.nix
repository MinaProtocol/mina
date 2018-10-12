let
  config = {
    packageOverrides = pkgs: rec {
      haskellPackages = pkgs.haskellPackages.override {
        overrides = haskellPackagesNew: haskellPackagesOld: rec {
          kademlia = haskellPackagesNew.callPackage ./prefetch/kademlia1101.nix { };

          project1 =
            haskellPackagesNew.callPackage ./default.nix { };
        };
      };
    };
  };

pkgs = import <nixpkgs> { inherit config; };

in
{ project1 = pkgs.haskellPackages.project1;
}

