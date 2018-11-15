`dune install` should handle destination directories that don't exist

  $ dune build @install
  $ dune install --prefix install --libdir lib
  Installing install/lib/foo/META
  Installing install/lib/foo/foo$ext_lib
  Installing install/lib/foo/foo.cma
  Installing install/lib/foo/foo.cmi
  Installing install/lib/foo/foo.cmt
  Installing install/lib/foo/foo.cmx
  Installing install/lib/foo/foo.cmxa
  Installing install/lib/foo/foo.cmxs
  Installing install/lib/foo/foo.dune
  Installing install/lib/foo/foo.ml
  Installing install/lib/foo/opam
  Installing install/bin/exec
  Installing install/man/a-man-page-with-no-ext
  Installing install/man/man1/a-man-page.1
  Installing install/man/man3/another-man-page.3

If prefix is passed, the default for libdir is `$prefix/lib`:

  $ dune install --prefix install --dry-run
  Installing install/lib/foo/META
  Installing install/lib/foo/foo$ext_lib
  Installing install/lib/foo/foo.cma
  Installing install/lib/foo/foo.cmi
  Installing install/lib/foo/foo.cmt
  Installing install/lib/foo/foo.cmx
  Installing install/lib/foo/foo.cmxa
  Installing install/lib/foo/foo.cmxs
  Installing install/lib/foo/foo.dune
  Installing install/lib/foo/foo.ml
  Installing install/lib/foo/opam
  Installing install/bin/exec
  Installing install/man/a-man-page-with-no-ext
  Installing install/man/man1/a-man-page.1
  Installing install/man/man3/another-man-page.3
  Creating directory install/lib/foo
  Copying _build/install/default/lib/foo/META to install/lib/foo/META (executable: false)
  Creating directory install/lib/foo
  Copying _build/install/default/lib/foo/foo$ext_lib to install/lib/foo/foo$ext_lib (executable: false)
  Creating directory install/lib/foo
  Copying _build/install/default/lib/foo/foo.cma to install/lib/foo/foo.cma (executable: false)
  Creating directory install/lib/foo
  Copying _build/install/default/lib/foo/foo.cmi to install/lib/foo/foo.cmi (executable: false)
  Creating directory install/lib/foo
  Copying _build/install/default/lib/foo/foo.cmt to install/lib/foo/foo.cmt (executable: false)
  Creating directory install/lib/foo
  Copying _build/install/default/lib/foo/foo.cmx to install/lib/foo/foo.cmx (executable: false)
  Creating directory install/lib/foo
  Copying _build/install/default/lib/foo/foo.cmxa to install/lib/foo/foo.cmxa (executable: false)
  Creating directory install/lib/foo
  Copying _build/install/default/lib/foo/foo.cmxs to install/lib/foo/foo.cmxs (executable: false)
  Creating directory install/lib/foo
  Copying _build/install/default/lib/foo/foo.dune to install/lib/foo/foo.dune (executable: false)
  Creating directory install/lib/foo
  Copying _build/install/default/lib/foo/foo.ml to install/lib/foo/foo.ml (executable: false)
  Creating directory install/lib/foo
  Copying _build/install/default/lib/foo/opam to install/lib/foo/opam (executable: false)
  Creating directory install/bin
  Copying _build/install/default/bin/exec to install/bin/exec (executable: true)
  Creating directory install/man
  Copying _build/install/default/man/a-man-page-with-no-ext to install/man/a-man-page-with-no-ext (executable: false)
  Creating directory install/man/man1
  Copying _build/install/default/man/man1/a-man-page.1 to install/man/man1/a-man-page.1 (executable: false)
  Creating directory install/man/man3
  Copying _build/install/default/man/man3/another-man-page.3 to install/man/man3/another-man-page.3 (executable: false)

If prefix is not passed, libdir defaults to the output of `ocamlfind printconf
destdir`:

  $ export OCAMLFIND_DESTDIR=/OCAMLFIND_DESTDIR; dune install --dry-run 2>&1 | sed "s#$(opam config var prefix)#OPAM_VAR_PREFIX#" ; dune uninstall --dry-run 2>&1 | sed "s#$(opam config var prefix)#OPAM_VAR_PREFIX#"
  Installing /OCAMLFIND_DESTDIR/foo/META
  Installing /OCAMLFIND_DESTDIR/foo/foo$ext_lib
  Installing /OCAMLFIND_DESTDIR/foo/foo.cma
  Installing /OCAMLFIND_DESTDIR/foo/foo.cmi
  Installing /OCAMLFIND_DESTDIR/foo/foo.cmt
  Installing /OCAMLFIND_DESTDIR/foo/foo.cmx
  Installing /OCAMLFIND_DESTDIR/foo/foo.cmxa
  Installing /OCAMLFIND_DESTDIR/foo/foo.cmxs
  Installing /OCAMLFIND_DESTDIR/foo/foo.dune
  Installing /OCAMLFIND_DESTDIR/foo/foo.ml
  Installing /OCAMLFIND_DESTDIR/foo/opam
  Installing OPAM_VAR_PREFIX/bin/exec
  Installing OPAM_VAR_PREFIX/man/a-man-page-with-no-ext
  Installing OPAM_VAR_PREFIX/man/man1/a-man-page.1
  Installing OPAM_VAR_PREFIX/man/man3/another-man-page.3
  Creating directory /OCAMLFIND_DESTDIR/foo
  Copying _build/install/default/lib/foo/META to /OCAMLFIND_DESTDIR/foo/META (executable: false)
  Creating directory /OCAMLFIND_DESTDIR/foo
  Copying _build/install/default/lib/foo/foo$ext_lib to /OCAMLFIND_DESTDIR/foo/foo$ext_lib (executable: false)
  Creating directory /OCAMLFIND_DESTDIR/foo
  Copying _build/install/default/lib/foo/foo.cma to /OCAMLFIND_DESTDIR/foo/foo.cma (executable: false)
  Creating directory /OCAMLFIND_DESTDIR/foo
  Copying _build/install/default/lib/foo/foo.cmi to /OCAMLFIND_DESTDIR/foo/foo.cmi (executable: false)
  Creating directory /OCAMLFIND_DESTDIR/foo
  Copying _build/install/default/lib/foo/foo.cmt to /OCAMLFIND_DESTDIR/foo/foo.cmt (executable: false)
  Creating directory /OCAMLFIND_DESTDIR/foo
  Copying _build/install/default/lib/foo/foo.cmx to /OCAMLFIND_DESTDIR/foo/foo.cmx (executable: false)
  Creating directory /OCAMLFIND_DESTDIR/foo
  Copying _build/install/default/lib/foo/foo.cmxa to /OCAMLFIND_DESTDIR/foo/foo.cmxa (executable: false)
  Creating directory /OCAMLFIND_DESTDIR/foo
  Copying _build/install/default/lib/foo/foo.cmxs to /OCAMLFIND_DESTDIR/foo/foo.cmxs (executable: false)
  Creating directory /OCAMLFIND_DESTDIR/foo
  Copying _build/install/default/lib/foo/foo.dune to /OCAMLFIND_DESTDIR/foo/foo.dune (executable: false)
  Creating directory /OCAMLFIND_DESTDIR/foo
  Copying _build/install/default/lib/foo/foo.ml to /OCAMLFIND_DESTDIR/foo/foo.ml (executable: false)
  Creating directory /OCAMLFIND_DESTDIR/foo
  Copying _build/install/default/lib/foo/opam to /OCAMLFIND_DESTDIR/foo/opam (executable: false)
  Creating directory OPAM_VAR_PREFIX/bin
  Copying _build/install/default/bin/exec to OPAM_VAR_PREFIX/bin/exec (executable: true)
  Creating directory OPAM_VAR_PREFIX/man
  Copying _build/install/default/man/a-man-page-with-no-ext to OPAM_VAR_PREFIX/man/a-man-page-with-no-ext (executable: false)
  Creating directory OPAM_VAR_PREFIX/man/man1
  Copying _build/install/default/man/man1/a-man-page.1 to OPAM_VAR_PREFIX/man/man1/a-man-page.1 (executable: false)
  Creating directory OPAM_VAR_PREFIX/man/man3
  Copying _build/install/default/man/man3/another-man-page.3 to OPAM_VAR_PREFIX/man/man3/another-man-page.3 (executable: false)
  Removing (if it exists) /OCAMLFIND_DESTDIR/foo/META
  Removing directory (if empty) /OCAMLFIND_DESTDIR/foo
  Removing (if it exists) /OCAMLFIND_DESTDIR/foo/foo$ext_lib
  Removing directory (if empty) /OCAMLFIND_DESTDIR/foo
  Removing (if it exists) /OCAMLFIND_DESTDIR/foo/foo.cma
  Removing directory (if empty) /OCAMLFIND_DESTDIR/foo
  Removing (if it exists) /OCAMLFIND_DESTDIR/foo/foo.cmi
  Removing directory (if empty) /OCAMLFIND_DESTDIR/foo
  Removing (if it exists) /OCAMLFIND_DESTDIR/foo/foo.cmt
  Removing directory (if empty) /OCAMLFIND_DESTDIR/foo
  Removing (if it exists) /OCAMLFIND_DESTDIR/foo/foo.cmx
  Removing directory (if empty) /OCAMLFIND_DESTDIR/foo
  Removing (if it exists) /OCAMLFIND_DESTDIR/foo/foo.cmxa
  Removing directory (if empty) /OCAMLFIND_DESTDIR/foo
  Removing (if it exists) /OCAMLFIND_DESTDIR/foo/foo.cmxs
  Removing directory (if empty) /OCAMLFIND_DESTDIR/foo
  Removing (if it exists) /OCAMLFIND_DESTDIR/foo/foo.dune
  Removing directory (if empty) /OCAMLFIND_DESTDIR/foo
  Removing (if it exists) /OCAMLFIND_DESTDIR/foo/foo.ml
  Removing directory (if empty) /OCAMLFIND_DESTDIR/foo
  Removing (if it exists) /OCAMLFIND_DESTDIR/foo/opam
  Removing directory (if empty) /OCAMLFIND_DESTDIR/foo
  Removing (if it exists) OPAM_VAR_PREFIX/bin/exec
  Removing directory (if empty) OPAM_VAR_PREFIX/bin
  Removing directory (if empty) /OCAMLFIND_DESTDIR/foo
  Removing (if it exists) OPAM_VAR_PREFIX/man/a-man-page-with-no-ext
  Removing directory (if empty) OPAM_VAR_PREFIX/man
  Removing directory (if empty) OPAM_VAR_PREFIX/bin
  Removing directory (if empty) /OCAMLFIND_DESTDIR/foo
  Removing (if it exists) OPAM_VAR_PREFIX/man/man1/a-man-page.1
  Removing directory (if empty) OPAM_VAR_PREFIX/man/man1
  Removing directory (if empty) OPAM_VAR_PREFIX/man
  Removing directory (if empty) OPAM_VAR_PREFIX/bin
  Removing directory (if empty) /OCAMLFIND_DESTDIR/foo
  Removing (if it exists) OPAM_VAR_PREFIX/man/man3/another-man-page.3
  Removing directory (if empty) OPAM_VAR_PREFIX/man/man3
  Removing directory (if empty) OPAM_VAR_PREFIX/man/man1
  Removing directory (if empty) OPAM_VAR_PREFIX/man
  Removing directory (if empty) OPAM_VAR_PREFIX/bin
  Removing directory (if empty) /OCAMLFIND_DESTDIR/foo

If only libdir is passed, binaries are installed under prefix/bin and libraries
in libdir:

  $ dune install --libdir /LIBDIR --dry-run 2>&1 | sed "s#$(opam config var prefix)#OPAM_VAR_PREFIX#" ; dune uninstall --libdir /LIBDIR --dry-run 2>&1 | sed "s#$(opam config var prefix)#OPAM_VAR_PREFIX#"
  Installing /LIBDIR/foo/META
  Installing /LIBDIR/foo/foo$ext_lib
  Installing /LIBDIR/foo/foo.cma
  Installing /LIBDIR/foo/foo.cmi
  Installing /LIBDIR/foo/foo.cmt
  Installing /LIBDIR/foo/foo.cmx
  Installing /LIBDIR/foo/foo.cmxa
  Installing /LIBDIR/foo/foo.cmxs
  Installing /LIBDIR/foo/foo.dune
  Installing /LIBDIR/foo/foo.ml
  Installing /LIBDIR/foo/opam
  Installing OPAM_VAR_PREFIX/bin/exec
  Installing OPAM_VAR_PREFIX/man/a-man-page-with-no-ext
  Installing OPAM_VAR_PREFIX/man/man1/a-man-page.1
  Installing OPAM_VAR_PREFIX/man/man3/another-man-page.3
  Creating directory /LIBDIR/foo
  Copying _build/install/default/lib/foo/META to /LIBDIR/foo/META (executable: false)
  Creating directory /LIBDIR/foo
  Copying _build/install/default/lib/foo/foo$ext_lib to /LIBDIR/foo/foo$ext_lib (executable: false)
  Creating directory /LIBDIR/foo
  Copying _build/install/default/lib/foo/foo.cma to /LIBDIR/foo/foo.cma (executable: false)
  Creating directory /LIBDIR/foo
  Copying _build/install/default/lib/foo/foo.cmi to /LIBDIR/foo/foo.cmi (executable: false)
  Creating directory /LIBDIR/foo
  Copying _build/install/default/lib/foo/foo.cmt to /LIBDIR/foo/foo.cmt (executable: false)
  Creating directory /LIBDIR/foo
  Copying _build/install/default/lib/foo/foo.cmx to /LIBDIR/foo/foo.cmx (executable: false)
  Creating directory /LIBDIR/foo
  Copying _build/install/default/lib/foo/foo.cmxa to /LIBDIR/foo/foo.cmxa (executable: false)
  Creating directory /LIBDIR/foo
  Copying _build/install/default/lib/foo/foo.cmxs to /LIBDIR/foo/foo.cmxs (executable: false)
  Creating directory /LIBDIR/foo
  Copying _build/install/default/lib/foo/foo.dune to /LIBDIR/foo/foo.dune (executable: false)
  Creating directory /LIBDIR/foo
  Copying _build/install/default/lib/foo/foo.ml to /LIBDIR/foo/foo.ml (executable: false)
  Creating directory /LIBDIR/foo
  Copying _build/install/default/lib/foo/opam to /LIBDIR/foo/opam (executable: false)
  Creating directory OPAM_VAR_PREFIX/bin
  Copying _build/install/default/bin/exec to OPAM_VAR_PREFIX/bin/exec (executable: true)
  Creating directory OPAM_VAR_PREFIX/man
  Copying _build/install/default/man/a-man-page-with-no-ext to OPAM_VAR_PREFIX/man/a-man-page-with-no-ext (executable: false)
  Creating directory OPAM_VAR_PREFIX/man/man1
  Copying _build/install/default/man/man1/a-man-page.1 to OPAM_VAR_PREFIX/man/man1/a-man-page.1 (executable: false)
  Creating directory OPAM_VAR_PREFIX/man/man3
  Copying _build/install/default/man/man3/another-man-page.3 to OPAM_VAR_PREFIX/man/man3/another-man-page.3 (executable: false)
  Removing (if it exists) /LIBDIR/foo/META
  Removing directory (if empty) /LIBDIR/foo
  Removing (if it exists) /LIBDIR/foo/foo$ext_lib
  Removing directory (if empty) /LIBDIR/foo
  Removing (if it exists) /LIBDIR/foo/foo.cma
  Removing directory (if empty) /LIBDIR/foo
  Removing (if it exists) /LIBDIR/foo/foo.cmi
  Removing directory (if empty) /LIBDIR/foo
  Removing (if it exists) /LIBDIR/foo/foo.cmt
  Removing directory (if empty) /LIBDIR/foo
  Removing (if it exists) /LIBDIR/foo/foo.cmx
  Removing directory (if empty) /LIBDIR/foo
  Removing (if it exists) /LIBDIR/foo/foo.cmxa
  Removing directory (if empty) /LIBDIR/foo
  Removing (if it exists) /LIBDIR/foo/foo.cmxs
  Removing directory (if empty) /LIBDIR/foo
  Removing (if it exists) /LIBDIR/foo/foo.dune
  Removing directory (if empty) /LIBDIR/foo
  Removing (if it exists) /LIBDIR/foo/foo.ml
  Removing directory (if empty) /LIBDIR/foo
  Removing (if it exists) /LIBDIR/foo/opam
  Removing directory (if empty) /LIBDIR/foo
  Removing (if it exists) OPAM_VAR_PREFIX/bin/exec
  Removing directory (if empty) OPAM_VAR_PREFIX/bin
  Removing directory (if empty) /LIBDIR/foo
  Removing (if it exists) OPAM_VAR_PREFIX/man/a-man-page-with-no-ext
  Removing directory (if empty) OPAM_VAR_PREFIX/man
  Removing directory (if empty) OPAM_VAR_PREFIX/bin
  Removing directory (if empty) /LIBDIR/foo
  Removing (if it exists) OPAM_VAR_PREFIX/man/man1/a-man-page.1
  Removing directory (if empty) OPAM_VAR_PREFIX/man/man1
  Removing directory (if empty) OPAM_VAR_PREFIX/man
  Removing directory (if empty) OPAM_VAR_PREFIX/bin
  Removing directory (if empty) /LIBDIR/foo
  Removing (if it exists) OPAM_VAR_PREFIX/man/man3/another-man-page.3
  Removing directory (if empty) OPAM_VAR_PREFIX/man/man3
  Removing directory (if empty) OPAM_VAR_PREFIX/man/man1
  Removing directory (if empty) OPAM_VAR_PREFIX/man
  Removing directory (if empty) OPAM_VAR_PREFIX/bin
  Removing directory (if empty) /LIBDIR/foo

The DESTDIR var is supported. When set, it is prepended to the prefix.
This is the case when the prefix is implicit:

  $ DESTDIR=DESTDIR dune install --dry-run 2>&1 | sed "s#$(opam config var prefix)#/OPAM_VAR_PREFIX#"
  Installing DESTDIR/OPAM_VAR_PREFIX/lib/foo/META
  Installing DESTDIR/OPAM_VAR_PREFIX/lib/foo/foo$ext_lib
  Installing DESTDIR/OPAM_VAR_PREFIX/lib/foo/foo.cma
  Installing DESTDIR/OPAM_VAR_PREFIX/lib/foo/foo.cmi
  Installing DESTDIR/OPAM_VAR_PREFIX/lib/foo/foo.cmt
  Installing DESTDIR/OPAM_VAR_PREFIX/lib/foo/foo.cmx
  Installing DESTDIR/OPAM_VAR_PREFIX/lib/foo/foo.cmxa
  Installing DESTDIR/OPAM_VAR_PREFIX/lib/foo/foo.cmxs
  Installing DESTDIR/OPAM_VAR_PREFIX/lib/foo/foo.dune
  Installing DESTDIR/OPAM_VAR_PREFIX/lib/foo/foo.ml
  Installing DESTDIR/OPAM_VAR_PREFIX/lib/foo/opam
  Installing DESTDIR/OPAM_VAR_PREFIX/bin/exec
  Installing DESTDIR/OPAM_VAR_PREFIX/man/a-man-page-with-no-ext
  Installing DESTDIR/OPAM_VAR_PREFIX/man/man1/a-man-page.1
  Installing DESTDIR/OPAM_VAR_PREFIX/man/man3/another-man-page.3
  Creating directory DESTDIR/OPAM_VAR_PREFIX/lib/foo
  Copying _build/install/default/lib/foo/META to DESTDIR/OPAM_VAR_PREFIX/lib/foo/META (executable: false)
  Creating directory DESTDIR/OPAM_VAR_PREFIX/lib/foo
  Copying _build/install/default/lib/foo/foo$ext_lib to DESTDIR/OPAM_VAR_PREFIX/lib/foo/foo$ext_lib (executable: false)
  Creating directory DESTDIR/OPAM_VAR_PREFIX/lib/foo
  Copying _build/install/default/lib/foo/foo.cma to DESTDIR/OPAM_VAR_PREFIX/lib/foo/foo.cma (executable: false)
  Creating directory DESTDIR/OPAM_VAR_PREFIX/lib/foo
  Copying _build/install/default/lib/foo/foo.cmi to DESTDIR/OPAM_VAR_PREFIX/lib/foo/foo.cmi (executable: false)
  Creating directory DESTDIR/OPAM_VAR_PREFIX/lib/foo
  Copying _build/install/default/lib/foo/foo.cmt to DESTDIR/OPAM_VAR_PREFIX/lib/foo/foo.cmt (executable: false)
  Creating directory DESTDIR/OPAM_VAR_PREFIX/lib/foo
  Copying _build/install/default/lib/foo/foo.cmx to DESTDIR/OPAM_VAR_PREFIX/lib/foo/foo.cmx (executable: false)
  Creating directory DESTDIR/OPAM_VAR_PREFIX/lib/foo
  Copying _build/install/default/lib/foo/foo.cmxa to DESTDIR/OPAM_VAR_PREFIX/lib/foo/foo.cmxa (executable: false)
  Creating directory DESTDIR/OPAM_VAR_PREFIX/lib/foo
  Copying _build/install/default/lib/foo/foo.cmxs to DESTDIR/OPAM_VAR_PREFIX/lib/foo/foo.cmxs (executable: false)
  Creating directory DESTDIR/OPAM_VAR_PREFIX/lib/foo
  Copying _build/install/default/lib/foo/foo.dune to DESTDIR/OPAM_VAR_PREFIX/lib/foo/foo.dune (executable: false)
  Creating directory DESTDIR/OPAM_VAR_PREFIX/lib/foo
  Copying _build/install/default/lib/foo/foo.ml to DESTDIR/OPAM_VAR_PREFIX/lib/foo/foo.ml (executable: false)
  Creating directory DESTDIR/OPAM_VAR_PREFIX/lib/foo
  Copying _build/install/default/lib/foo/opam to DESTDIR/OPAM_VAR_PREFIX/lib/foo/opam (executable: false)
  Creating directory DESTDIR/OPAM_VAR_PREFIX/bin
  Copying _build/install/default/bin/exec to DESTDIR/OPAM_VAR_PREFIX/bin/exec (executable: true)
  Creating directory DESTDIR/OPAM_VAR_PREFIX/man
  Copying _build/install/default/man/a-man-page-with-no-ext to DESTDIR/OPAM_VAR_PREFIX/man/a-man-page-with-no-ext (executable: false)
  Creating directory DESTDIR/OPAM_VAR_PREFIX/man/man1
  Copying _build/install/default/man/man1/a-man-page.1 to DESTDIR/OPAM_VAR_PREFIX/man/man1/a-man-page.1 (executable: false)
  Creating directory DESTDIR/OPAM_VAR_PREFIX/man/man3
  Copying _build/install/default/man/man3/another-man-page.3 to DESTDIR/OPAM_VAR_PREFIX/man/man3/another-man-page.3 (executable: false)

But also when the prefix is explicit:

  $ DESTDIR=DESTDIR dune install --prefix prefix --dry-run
  Installing DESTDIR/prefix/lib/foo/META
  Installing DESTDIR/prefix/lib/foo/foo$ext_lib
  Installing DESTDIR/prefix/lib/foo/foo.cma
  Installing DESTDIR/prefix/lib/foo/foo.cmi
  Installing DESTDIR/prefix/lib/foo/foo.cmt
  Installing DESTDIR/prefix/lib/foo/foo.cmx
  Installing DESTDIR/prefix/lib/foo/foo.cmxa
  Installing DESTDIR/prefix/lib/foo/foo.cmxs
  Installing DESTDIR/prefix/lib/foo/foo.dune
  Installing DESTDIR/prefix/lib/foo/foo.ml
  Installing DESTDIR/prefix/lib/foo/opam
  Installing DESTDIR/prefix/bin/exec
  Installing DESTDIR/prefix/man/a-man-page-with-no-ext
  Installing DESTDIR/prefix/man/man1/a-man-page.1
  Installing DESTDIR/prefix/man/man3/another-man-page.3
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/META to DESTDIR/prefix/lib/foo/META (executable: false)
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/foo$ext_lib to DESTDIR/prefix/lib/foo/foo$ext_lib (executable: false)
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/foo.cma to DESTDIR/prefix/lib/foo/foo.cma (executable: false)
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/foo.cmi to DESTDIR/prefix/lib/foo/foo.cmi (executable: false)
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/foo.cmt to DESTDIR/prefix/lib/foo/foo.cmt (executable: false)
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/foo.cmx to DESTDIR/prefix/lib/foo/foo.cmx (executable: false)
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/foo.cmxa to DESTDIR/prefix/lib/foo/foo.cmxa (executable: false)
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/foo.cmxs to DESTDIR/prefix/lib/foo/foo.cmxs (executable: false)
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/foo.dune to DESTDIR/prefix/lib/foo/foo.dune (executable: false)
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/foo.ml to DESTDIR/prefix/lib/foo/foo.ml (executable: false)
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/opam to DESTDIR/prefix/lib/foo/opam (executable: false)
  Creating directory DESTDIR/prefix/bin
  Copying _build/install/default/bin/exec to DESTDIR/prefix/bin/exec (executable: true)
  Creating directory DESTDIR/prefix/man
  Copying _build/install/default/man/a-man-page-with-no-ext to DESTDIR/prefix/man/a-man-page-with-no-ext (executable: false)
  Creating directory DESTDIR/prefix/man/man1
  Copying _build/install/default/man/man1/a-man-page.1 to DESTDIR/prefix/man/man1/a-man-page.1 (executable: false)
  Creating directory DESTDIR/prefix/man/man3
  Copying _build/install/default/man/man3/another-man-page.3 to DESTDIR/prefix/man/man3/another-man-page.3 (executable: false)

DESTDIR can also be passed as a command line flag.

  $ dune install --destdir DESTDIR --prefix prefix --dry-run
  Installing DESTDIR/prefix/lib/foo/META
  Installing DESTDIR/prefix/lib/foo/foo$ext_lib
  Installing DESTDIR/prefix/lib/foo/foo.cma
  Installing DESTDIR/prefix/lib/foo/foo.cmi
  Installing DESTDIR/prefix/lib/foo/foo.cmt
  Installing DESTDIR/prefix/lib/foo/foo.cmx
  Installing DESTDIR/prefix/lib/foo/foo.cmxa
  Installing DESTDIR/prefix/lib/foo/foo.cmxs
  Installing DESTDIR/prefix/lib/foo/foo.dune
  Installing DESTDIR/prefix/lib/foo/foo.ml
  Installing DESTDIR/prefix/lib/foo/opam
  Installing DESTDIR/prefix/bin/exec
  Installing DESTDIR/prefix/man/a-man-page-with-no-ext
  Installing DESTDIR/prefix/man/man1/a-man-page.1
  Installing DESTDIR/prefix/man/man3/another-man-page.3
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/META to DESTDIR/prefix/lib/foo/META (executable: false)
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/foo$ext_lib to DESTDIR/prefix/lib/foo/foo$ext_lib (executable: false)
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/foo.cma to DESTDIR/prefix/lib/foo/foo.cma (executable: false)
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/foo.cmi to DESTDIR/prefix/lib/foo/foo.cmi (executable: false)
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/foo.cmt to DESTDIR/prefix/lib/foo/foo.cmt (executable: false)
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/foo.cmx to DESTDIR/prefix/lib/foo/foo.cmx (executable: false)
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/foo.cmxa to DESTDIR/prefix/lib/foo/foo.cmxa (executable: false)
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/foo.cmxs to DESTDIR/prefix/lib/foo/foo.cmxs (executable: false)
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/foo.dune to DESTDIR/prefix/lib/foo/foo.dune (executable: false)
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/foo.ml to DESTDIR/prefix/lib/foo/foo.ml (executable: false)
  Creating directory DESTDIR/prefix/lib/foo
  Copying _build/install/default/lib/foo/opam to DESTDIR/prefix/lib/foo/opam (executable: false)
  Creating directory DESTDIR/prefix/bin
  Copying _build/install/default/bin/exec to DESTDIR/prefix/bin/exec (executable: true)
  Creating directory DESTDIR/prefix/man
  Copying _build/install/default/man/a-man-page-with-no-ext to DESTDIR/prefix/man/a-man-page-with-no-ext (executable: false)
  Creating directory DESTDIR/prefix/man/man1
  Copying _build/install/default/man/man1/a-man-page.1 to DESTDIR/prefix/man/man1/a-man-page.1 (executable: false)
  Creating directory DESTDIR/prefix/man/man3
  Copying _build/install/default/man/man3/another-man-page.3 to DESTDIR/prefix/man/man3/another-man-page.3 (executable: false)
