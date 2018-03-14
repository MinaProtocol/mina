let
  config = {
    packageOverrides = pkgs: rec {
      haskellPackages = pkgs.haskellPackages.override {
        overrides = haskellPackagesNew: haskellPackagesOld: rec {
          kademlia = haskellPackagesNew.callPackage ./kademlia1101.nix { };
        };
      };
    };
  };

pkgs = import <nixpkgs> { inherit config; };

in
{ kademlia-lib = pkgs.haskellPackages.kademlia;
}

