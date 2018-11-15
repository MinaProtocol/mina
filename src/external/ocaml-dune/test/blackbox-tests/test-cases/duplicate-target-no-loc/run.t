There are 2 rules for a single install file, but the error message doesn't show
us their origin.

Issue: https://github.com/ocaml/dune/issues/1405
  $ dune build foo.install
  Multiple rules generated for _build/install/default/doc/foo/foo:
  - <internal location>
  - <internal location>
  [1]
