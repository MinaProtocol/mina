#!/bin/bash

# The one implementation of "what goes into a shared-library bundle".
#
# Two consumers need the same answer and used to each carry their own copy:
#
#   apps/write_to_cache.sh   stages one bundle per cached binary, so a job that
#                            restores a bare binary stops depending on whatever
#                            libraries the agent image happens to carry.
#   build-artifact.sh        assembles _build_portable/, the relocatable tree a
#                            single portable build ships instead of one build
#                            per Debian codename.
#
# They package the result differently -- a tarball beside each cached exe versus
# one deduplicated tree -- but the collection rules are identical, and they are
# subtle enough that two copies drifted apart the moment they existed.
#
# The rules:
#
# * glibc and the dynamic loader are BUNDLED, not left to the host. Carrying our
#   own libc is what removes the host's glibc from the support matrix (the
#   constraint becomes the host kernel instead), and it is why one build can
#   target every codename rather than the build having to happen on the oldest
#   one.
#
# * Because glibc is in the bundle, the BUNDLED loader must run the process. A
#   binary's PT_INTERP names the HOST loader, and a host loader cannot correctly
#   load a foreign libc, so exporting LD_LIBRARY_PATH would be undefined
#   behaviour. Callers invoke ld-linux explicitly (see bundle_write_wrapper);
#   an RPATH alone does NOT make a bundle with glibc in it work.
#
# * libnss_* modules are collected by hand. glibc dlopens them rather than
#   linking them, so ldd never lists them, and a bundled glibc that cannot find
#   matching NSS modules breaks DNS and user lookups -- which for these binaries
#   means peer discovery and archive connections failing in ways that look
#   nothing like a packaging fault.
#
# Bundling can only ship what ldd resolves. A library missing from the build
# image is reported "not found" and cannot be collected, and it stays missing at
# run time -- which is why the toolchain image must carry runtime packages and
# not only their -dev counterparts. Use bundle_missing to catch that before a
# bundle ships; a cache entry can tolerate it (the agent image may still have
# the library), a released artifact cannot.
#
# Known gap: gconv modules and locale data are not collected yet, so a bundled
# glibc falls back to the host's for iconv/locale lookups.

# Copy everything $exe needs into $libdir, which may already hold libraries from
# an earlier call -- copies are no-clobber, so a shared libdir deduplicates
# across binaries. Symlinks are dereferenced (-L) so the tree stands alone.
bundle_collect() {
  local exe="$1" libdir="$2" lib libc_dir
  command -v ldd >/dev/null 2>&1 || return 0

  mkdir -p "$libdir"

  # everything ldd resolves to a real path, glibc included
  ldd "$exe" 2>/dev/null \
    | sed -nE 's|.*=> (/[^ ]+) \(0x[0-9a-f]+\)$|\1|p' \
    | while read -r lib; do
        [[ -f "$lib" ]] && cp -Ln "$lib" "$libdir/" 2>/dev/null || true
      done

  # the loader itself: named as an interpreter, not as a "=>" dependency
  ldd "$exe" 2>/dev/null \
    | sed -nE 's|^\s*(/[^ ]*ld-linux[^ ]*\.so[^ ]*) \(0x[0-9a-f]+\)$|\1|p' \
    | while read -r lib; do
        [[ -f "$lib" ]] && cp -Ln "$lib" "$libdir/" 2>/dev/null || true
      done

  # NSS modules are dlopened, so ldd cannot see them; take them from beside the
  # libc this binary actually resolved, so they match the glibc we ship.
  libc_dir="$(dirname "$(ldd "$exe" 2>/dev/null | sed -nE 's|.*=> (/[^ ]+libc\.so[^ ]*) .*|\1|p' | head -1)")"
  # shellcheck disable=SC2231  # the glob is the point; libc_dir cannot be empty
  for lib in $libc_dir/libnss_*.so.*; do
    [[ -f "$lib" ]] && cp -Ln "$lib" "$libdir/" 2>/dev/null || true
  done
}

# Echo the basename of the loader in $libdir, or nothing if the bundle has none.
#
# A glob loop, not `find ... | head -1`, on purpose. Callers run under
# `set -eo pipefail`, and once a producer writes past the pipe buffer (~64KB)
# after head has taken its one line, it dies of SIGPIPE: find exits 141,
# pipefail makes that the pipeline's status, and set -e exits with no
# diagnostic. Callers invoke restore_app.sh as `if restore_app ...`, so such an
# exit is indistinguishable from a cache miss.
#
# The size threshold is why this is worth stating: the same pipeline over a
# small bundle is fine, so the bug appears only once a bundle grows -- and a
# bundle carrying glibc grows. A glob has no producer to kill.
bundle_loader_name() {
  local libdir="$1" cand
  for cand in "$libdir"/ld-linux*.so*; do
    if [[ -e "$cand" ]]; then basename "$cand"; return 0; fi
  done
  return 0
}

# Write a wrapper at $wrapper that runs $exe under the bundled loader.
#
# $lib_rel and $exe_rel are relative to the wrapper's parent directory, so the
# whole tree can be moved or mounted anywhere: the wrapper resolves its own
# location at run time. Invoking the loader directly (rather than exporting
# LD_LIBRARY_PATH) also keeps the library override off child processes.
bundle_write_wrapper() {
  local wrapper="$1" lib_rel="$2" exe_rel="$3" loader="$4"

  cat >"$wrapper" <<WRAPPER
#!/bin/sh
# Generated by buildkite/scripts/bundle-libs.sh -- runs the bundled loader
# against the bundled libraries, so the host's glibc is never used.
root=\$(CDPATH= cd -- "\$(dirname -- "\$0")/.." && pwd)
exec "\$root/${lib_rel}/${loader}" --library-path "\$root/${lib_rel}" "\$root/${exe_rel}" "\$@"
WRAPPER
  chmod 0755 "$wrapper"
}

# Echo the SONAMEs $exe needs that ldd could not resolve, one per line. Empty
# output means the bundle can be complete.
bundle_missing() {
  local exe="$1"
  command -v ldd >/dev/null 2>&1 || return 0

  ldd "$exe" 2>/dev/null | sed -nE 's|^[[:space:]]*([^[:space:]]+) => not found$|\1|p'
}

# Echo one "<binary><TAB><library>" line per library $exe resolves, for the
# closure audit. Sorted and deduplicated across the whole bundle this answers
# "what does the artifact set actually depend on", which is otherwise only
# knowable by building mina and running ldd by hand.
#
# It reports basenames, not paths: the paths are build-image specific and the
# question is which SONAMEs travel with us.
bundle_report() {
  local exe="$1" lib
  command -v ldd >/dev/null 2>&1 || return 0

  ldd "$exe" 2>/dev/null \
    | sed -nE 's|.*=> (/[^ ]+) \(0x[0-9a-f]+\)$|\1|p' \
    | while read -r lib; do
        printf '%s\t%s\n' "$(basename "$exe")" "$(basename "$lib")"
      done
}
