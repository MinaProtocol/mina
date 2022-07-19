with import ./nix/compat.nix;
defaultNix // defaultNix.defaultPackage.${builtins.currentSystem}
