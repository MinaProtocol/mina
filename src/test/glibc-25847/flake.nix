{
  description = "glibc #25847 reproducer — pins affected and fixed glibc versions";

  inputs = {
    # nixos-24.11 ships glibc 2.40, the last version affected by bug #25847.
    # The fix landed in glibc 2.41 (January 2025).
    # Binaries compiled in this shell link against glibc 2.40 via nix rpath,
    # so they use the vulnerable glibc at runtime even on a host with 2.41+.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    # Pinned to a nixos-unstable commit with glibc 2.42, which includes the
    # fix for bug #25847. This is necessary because no stable nixpkgs channel
    # ships a fixed glibc yet — nixos-24.11 and nixos-25.05 both have 2.40.
    # nixpkgs skipped glibc 2.41 entirely, so 2.42 is the first fixed version
    # available in nixpkgs.
    nixpkgs-fixed.url = "github:NixOS/nixpkgs/b40629efe5d6ec48dd1efba650c797ddbd39ace0";
  };

  outputs = { self, nixpkgs, nixpkgs-fixed }:
    let
      system = "x86_64-linux";

      mkPackageFor = npkgs:
        let
          pkgs = npkgs.legacyPackages.${system};
          ocamlPkgs = pkgs.ocaml-ng.ocamlPackages_4_14;
        in
        pkgs.stdenv.mkDerivation {
          pname = "glibc-25847-reproducer";
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = [
            ocamlPkgs.ocaml
            ocamlPkgs.findlib
          ];

          buildInputs = [
            ocamlPkgs.async
            ocamlPkgs.core
            ocamlPkgs.core_unix
            ocamlPkgs.ppx_jane
          ];

          buildPhase = ''
            ocamlfind ocamlopt -g -thread \
              -package async,core,core_unix,ppx_jane -linkpkg \
              -o async_tcp_server async_tcp_server.ml
            ocamlfind ocamlopt -g -thread \
              -package async,core,core_unix,ppx_jane -linkpkg \
              -o async_tcp_client async_tcp_client.ml
            $CC -shared -fPIC -o allow_ptrace.so allow_ptrace.c
          '';

          installPhase = ''
            mkdir -p $out/bin $out/lib
            cp async_tcp_server $out/bin/
            cp async_tcp_client $out/bin/
            cp allow_ptrace.so $out/lib/
          '';
        };

      mkShellFor = npkgs:
        let
          pkgs = npkgs.legacyPackages.${system};
          pkg = mkPackageFor npkgs;
        in
        pkgs.mkShell {
          buildInputs = [ pkg pkgs.gdb ];
        };
    in
    {
      packages.${system} = {
        default = mkPackageFor nixpkgs;       # glibc 2.40 (affected)
        fixed   = mkPackageFor nixpkgs-fixed; # glibc 2.42 (fixed)
      };

      devShells.${system} = {
        default = mkShellFor nixpkgs;       # glibc 2.40 (affected)
        fixed   = mkShellFor nixpkgs-fixed; # glibc 2.42 (fixed)
      };
    };
}
