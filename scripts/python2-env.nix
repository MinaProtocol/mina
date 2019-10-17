with import ../pinned-nixpkgs.nix;
(pkgs.python2.withPackages(ps: with ps;
    [
      sexpdata
    ]))
    .env