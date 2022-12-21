with import ./nix/compat.nix;
shellNix // shellNix.devShells.${builtins.currentSystem}.impure
