  $ dune build @install
  $ dune install --dry-run 2>&1 | sed 's#'$(opam config var prefix)'#OPAM_PREFIX#'
  Installing OPAM_PREFIX/lib/mylib/META
  Installing OPAM_PREFIX/lib/mylib/mylib$ext_lib
  Installing OPAM_PREFIX/lib/mylib/mylib.cma
  Installing OPAM_PREFIX/lib/mylib/mylib.cmi
  Installing OPAM_PREFIX/lib/mylib/mylib.cmt
  Installing OPAM_PREFIX/lib/mylib/mylib.cmx
  Installing OPAM_PREFIX/lib/mylib/mylib.cmxa
  Installing OPAM_PREFIX/lib/mylib/mylib.cmxs
  Installing OPAM_PREFIX/lib/mylib/mylib.dune
  Installing OPAM_PREFIX/lib/mylib/mylib.ml
  Installing OPAM_PREFIX/lib/mylib/opam
  Creating directory OPAM_PREFIX/lib/mylib
  Copying _build/install/default/lib/mylib/META to OPAM_PREFIX/lib/mylib/META (executable: false)
  Creating directory OPAM_PREFIX/lib/mylib
  Copying _build/install/default/lib/mylib/mylib$ext_lib to OPAM_PREFIX/lib/mylib/mylib$ext_lib (executable: false)
  Creating directory OPAM_PREFIX/lib/mylib
  Copying _build/install/default/lib/mylib/mylib.cma to OPAM_PREFIX/lib/mylib/mylib.cma (executable: false)
  Creating directory OPAM_PREFIX/lib/mylib
  Copying _build/install/default/lib/mylib/mylib.cmi to OPAM_PREFIX/lib/mylib/mylib.cmi (executable: false)
  Creating directory OPAM_PREFIX/lib/mylib
  Copying _build/install/default/lib/mylib/mylib.cmt to OPAM_PREFIX/lib/mylib/mylib.cmt (executable: false)
  Creating directory OPAM_PREFIX/lib/mylib
  Copying _build/install/default/lib/mylib/mylib.cmx to OPAM_PREFIX/lib/mylib/mylib.cmx (executable: false)
  Creating directory OPAM_PREFIX/lib/mylib
  Copying _build/install/default/lib/mylib/mylib.cmxa to OPAM_PREFIX/lib/mylib/mylib.cmxa (executable: false)
  Creating directory OPAM_PREFIX/lib/mylib
  Copying _build/install/default/lib/mylib/mylib.cmxs to OPAM_PREFIX/lib/mylib/mylib.cmxs (executable: false)
  Creating directory OPAM_PREFIX/lib/mylib
  Copying _build/install/default/lib/mylib/mylib.dune to OPAM_PREFIX/lib/mylib/mylib.dune (executable: false)
  Creating directory OPAM_PREFIX/lib/mylib
  Copying _build/install/default/lib/mylib/mylib.ml to OPAM_PREFIX/lib/mylib/mylib.ml (executable: false)
  Creating directory OPAM_PREFIX/lib/mylib
  Copying _build/install/default/lib/mylib/opam to OPAM_PREFIX/lib/mylib/opam (executable: false)

  $ dune uninstall --dry-run 2>&1 | sed 's#'$(opam config var prefix)'#OPAM_PREFIX#'
  Removing (if it exists) OPAM_PREFIX/lib/mylib/META
  Removing directory (if empty) OPAM_PREFIX/lib/mylib
  Removing (if it exists) OPAM_PREFIX/lib/mylib/mylib$ext_lib
  Removing directory (if empty) OPAM_PREFIX/lib/mylib
  Removing (if it exists) OPAM_PREFIX/lib/mylib/mylib.cma
  Removing directory (if empty) OPAM_PREFIX/lib/mylib
  Removing (if it exists) OPAM_PREFIX/lib/mylib/mylib.cmi
  Removing directory (if empty) OPAM_PREFIX/lib/mylib
  Removing (if it exists) OPAM_PREFIX/lib/mylib/mylib.cmt
  Removing directory (if empty) OPAM_PREFIX/lib/mylib
  Removing (if it exists) OPAM_PREFIX/lib/mylib/mylib.cmx
  Removing directory (if empty) OPAM_PREFIX/lib/mylib
  Removing (if it exists) OPAM_PREFIX/lib/mylib/mylib.cmxa
  Removing directory (if empty) OPAM_PREFIX/lib/mylib
  Removing (if it exists) OPAM_PREFIX/lib/mylib/mylib.cmxs
  Removing directory (if empty) OPAM_PREFIX/lib/mylib
  Removing (if it exists) OPAM_PREFIX/lib/mylib/mylib.dune
  Removing directory (if empty) OPAM_PREFIX/lib/mylib
  Removing (if it exists) OPAM_PREFIX/lib/mylib/mylib.ml
  Removing directory (if empty) OPAM_PREFIX/lib/mylib
  Removing (if it exists) OPAM_PREFIX/lib/mylib/opam
  Removing directory (if empty) OPAM_PREFIX/lib/mylib
