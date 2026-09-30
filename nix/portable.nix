# Turn a nix closure into a tree that runs anywhere, with no /nix on the host.
#
# This is the single producer the Debian packages and the docker images both
# consume: nix builds binaries and this flattens them into an ordinary directory,
# rather than nix building packages or images itself.
#
# The mechanism: each binary's PT_INTERP is repointed at the bundled loader and
# its DT_RUNPATH at $ORIGIN, so it runs as itself, directly. bin/<name> is a
# thin wrapper that only sets environment and execs the real ELF.
#
# It is deliberately NOT the explicit-loader invocation
# (`ld-linux --library-path ... ./mina`), which needs no patchelf and relocates
# anywhere -- and which breaks the daemon. Under that scheme /proc/self/exe is
# the LOADER, so `Sys.executable_name` (mina_lib.ml, Snark_worker.run_process)
# returns the ld-linux path and the daemon spawns its snark worker as
# `ld-linux internal snark-worker`. `mina version` never touches this; a running
# daemon does.
#
# The cost is that PT_INTERP is an absolute path, so the tree only runs from the
# prefix it was built for. That is why `prefix` is an argument: the .deb builds
# one for /opt/mina, and automode builds one per runtime directory. Everything
# else in the tree is $ORIGIN-relative.
#
# ONE LIB DIRECTORY PER EXECUTABLE, which is not mere caution: mina is built
# against glibc 2.40 and libp2p_helper against 2.37 (it comes from nixpkgs-old),
# so a single flat lib/ has two libc.so.6 candidates for one soname. Resolving
# by soname across the whole closure picks one of them arbitrarily; when it
# picks the older, the loader falls back to the HOST's libc and the daemon dies
# in a stack-smash. Each binary's deps are therefore resolved through its own
# DT_RUNPATH, exactly as the dynamic linker would.
# ponytail: per-exe duplication of shared libs is a few MB against a 107 MB
# daemon; dedup by content hash if the tree ever gets tight.
#
# NOT bundled, deliberately: tar and gzip. The mina daemon shells out to them,
# and wrapMina in ocaml.nix puts them on PATH because a from-scratch container
# has no OS. Here the host provides them, exactly as it does for the .deb today
# -- which never shipped them either.
{ lib, stdenv, closureInfo, patchelf }:

# exes: attrset of <installed name> -> path to the real ELF.
{ name ? "mina-portable", exes, commit ? "<unknown>", prefix ? "/opt/mina" }:

let
  closure = closureInfo { rootPaths = lib.attrValues exes; };
in stdenv.mkDerivation {
  inherit name;
  nativeBuildInputs = [ patchelf ];

  buildCommand = ''
    mkdir -p $out/bin $out/libexec $out/lib

    # Collect one executable and its transitive DT_NEEDED closure into
    # lib/<name>/, resolving every soname through the referring file's own
    # DT_RUNPATH (falling back to the loader's own directory, which is where
    # glibc lives, for binaries that record no runpath -- the Go helper).
    bundle_one() {
      local n="$1" src="$2"
      local dir="$out/lib/$n"
      mkdir -p "$dir"

      cp -L "$src" "$out/libexec/$n"
      chmod +w "$out/libexec/$n"

      local interp libcdir
      interp=$(patchelf --print-interpreter "$out/libexec/$n")
      libcdir=$(dirname "$interp")
      cp -L "$interp" "$dir/$(basename "$interp")"
      chmod +w "$dir/$(basename "$interp")"

      local todo="$out/libexec/$n"
      while [ -n "$todo" ]; do
        set -- $todo; local f="$1"; shift; todo="$*"

        local rpath
        rpath=$(patchelf --print-rpath "$f" 2>/dev/null | tr ':' ' ')

        local soname
        for soname in $(patchelf --print-needed "$f" 2>/dev/null); do
          [ -e "$dir/$soname" ] && continue

          local d found=""
          for d in $rpath "$libcdir"; do
            if [ -e "$d/$soname" ]; then found="$d/$soname"; break; fi
          done
          [ -n "$found" ] || {
            echo "ERROR: $(basename "$f") needs $soname, not found in its" >&2
            echo "       DT_RUNPATH ($rpath) nor $libcdir" >&2
            exit 1
          }

          cp -L "$found" "$dir/$soname"
          chmod +w "$dir/$soname"
          todo="$todo $dir/$soname"
        done
      done

      # Point the binary at its own bundled loader and libs. DT_RUNPATH does
      # NOT apply to transitive dependencies, so every bundled library needs
      # $ORIGIN too, not just the executable.
      patchelf \
        --set-interpreter "${prefix}/lib/$n/$(basename "$interp")" \
        --set-rpath "\$ORIGIN/../lib/$n" \
        "$out/libexec/$n"
      local so
      for so in "$dir"/*.so*; do
        case "$(basename "$so")" in ld-linux*) continue ;; esac
        patchelf --set-rpath "\$ORIGIN" "$so" 2>/dev/null || true
      done

      cat > "$out/bin/$n" <<WRAPPER
    #!/bin/sh
    # Resolve the bundle from this script's own location so the tree relocates.
    # readlink -f is load-bearing: the .deb symlinks /usr/local/bin/mina here,
    # and the tree must be found from the symlink, not from where it sits.
    # \''${p%/*} rather than dirname keeps this to one fork.
    p=\$(readlink -f "\$0"); d=\$(cd "\''${p%/*}/.." && pwd)
    # Without this the daemon dies in Mina_version.commit_id with Not_found.
    export MINA_COMMIT_SHA1="\''${MINA_COMMIT_SHA1:-${commit}}"
    export MINA_LIBP2P_HELPER_PATH="\''${MINA_LIBP2P_HELPER_PATH:-\$d/bin/mina-libp2p_helper}"
    # exec the real ELF, not the loader: the daemon spawns its snark worker via
    # Sys.executable_name, which reads /proc/self/exe.
    exec "\$d/libexec/$n" "\$@"
    WRAPPER
      sed -i 's/^    //' "$out/bin/$n"
      chmod +x "$out/bin/$n"
    }

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: p: ''
      bundle_one ${lib.escapeShellArg n} ${lib.escapeShellArg (toString p)}
    '') exes)}

    # Fail closed: every bundled ELF must resolve entirely inside its own lib
    # dir. Without this the loader silently falls back to the host's libraries,
    # which is how a missing dependency turns into a stack-smash at runtime
    # instead of a build failure here.
    for n in $(ls $out/libexec); do
      for f in "$out/libexec/$n" "$out/lib/$n"/*.so*; do
        for soname in $(patchelf --print-needed "$f" 2>/dev/null); do
          [ -e "$out/lib/$n/$soname" ] || {
            echo "ERROR: $n: $(basename "$f") needs $soname, which is not bundled" >&2
            exit 1
          }
        done
      done
      echo "$n: $(ls $out/lib/$n | wc -l) libraries"
    done
  '';
}
