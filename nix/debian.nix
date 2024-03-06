{ rpmDebUtils, ocamlPackages_mina }: {
  # FIXME: This package basically just wraps some nix store paths in the .deb format.
  # It works, but has some problems.
  # In particular, if there's already Nix installed on the target system, it won't work.
  # Also, after this package is installed, installing Nix is likely to be wonky.
  # We should fix it, e.g. by installing the nix store somewhere else, e.g. /opt/mina/nix/store, and use user namespaces to remap it to /nix/store.
  mina = rpmDebUtils.buildFakeSingleDeb ocamlPackages_mina.mina;
}
