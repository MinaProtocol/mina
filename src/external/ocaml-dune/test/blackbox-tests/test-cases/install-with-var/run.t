`dune install` should handle destination directories that don't exist

  $ dune build @install
  $ dune install --prefix install --libdir lib
  Installing install/lib/foo/META
  Installing install/lib/foo/opam
  Installing install/man/man1/a-man-page.default.1
  Installing install/man/man3/another-man-page.3

