with import ../pinned-nixpkgs.nix;
(pkgs.python3.withPackages(ps: with ps;
    [
      jinja2
      requests
    ]))
    .env