ppx artifacts installed for rewriters

  $ dune build --root ppx
  Entering directory 'ppx'
  lib: [
    "_build/install/default/lib/foo/META" {"META"}
    "_build/install/default/lib/foo/opam" {"opam"}
    "_build/install/default/lib/foo/ppx_rewriter_dune/foo.ppx_rewriter_dune.dune" {"ppx_rewriter_dune/foo.ppx_rewriter_dune.dune"}
    "_build/install/default/lib/foo/ppx_rewriter_dune/foo_ppx_rewriter_dune$ext_lib" {"ppx_rewriter_dune/foo_ppx_rewriter_dune$ext_lib"}
    "_build/install/default/lib/foo/ppx_rewriter_dune/foo_ppx_rewriter_dune.cma" {"ppx_rewriter_dune/foo_ppx_rewriter_dune.cma"}
    "_build/install/default/lib/foo/ppx_rewriter_dune/foo_ppx_rewriter_dune.cmi" {"ppx_rewriter_dune/foo_ppx_rewriter_dune.cmi"}
    "_build/install/default/lib/foo/ppx_rewriter_dune/foo_ppx_rewriter_dune.cmt" {"ppx_rewriter_dune/foo_ppx_rewriter_dune.cmt"}
    "_build/install/default/lib/foo/ppx_rewriter_dune/foo_ppx_rewriter_dune.cmx" {"ppx_rewriter_dune/foo_ppx_rewriter_dune.cmx"}
    "_build/install/default/lib/foo/ppx_rewriter_dune/foo_ppx_rewriter_dune.cmxa" {"ppx_rewriter_dune/foo_ppx_rewriter_dune.cmxa"}
    "_build/install/default/lib/foo/ppx_rewriter_dune/foo_ppx_rewriter_dune.cmxs" {"ppx_rewriter_dune/foo_ppx_rewriter_dune.cmxs"}
    "_build/install/default/lib/foo/ppx_rewriter_dune/foo_ppx_rewriter_dune.ml" {"ppx_rewriter_dune/foo_ppx_rewriter_dune.ml"}
    "_build/install/default/lib/foo/ppx_rewriter_jbuild/foo.ppx_rewriter_jbuild.dune" {"ppx_rewriter_jbuild/foo.ppx_rewriter_jbuild.dune"}
    "_build/install/default/lib/foo/ppx_rewriter_jbuild/foo_ppx_rewriter_jbuild$ext_lib" {"ppx_rewriter_jbuild/foo_ppx_rewriter_jbuild$ext_lib"}
    "_build/install/default/lib/foo/ppx_rewriter_jbuild/foo_ppx_rewriter_jbuild.cma" {"ppx_rewriter_jbuild/foo_ppx_rewriter_jbuild.cma"}
    "_build/install/default/lib/foo/ppx_rewriter_jbuild/foo_ppx_rewriter_jbuild.cmi" {"ppx_rewriter_jbuild/foo_ppx_rewriter_jbuild.cmi"}
    "_build/install/default/lib/foo/ppx_rewriter_jbuild/foo_ppx_rewriter_jbuild.cmt" {"ppx_rewriter_jbuild/foo_ppx_rewriter_jbuild.cmt"}
    "_build/install/default/lib/foo/ppx_rewriter_jbuild/foo_ppx_rewriter_jbuild.cmx" {"ppx_rewriter_jbuild/foo_ppx_rewriter_jbuild.cmx"}
    "_build/install/default/lib/foo/ppx_rewriter_jbuild/foo_ppx_rewriter_jbuild.cmxa" {"ppx_rewriter_jbuild/foo_ppx_rewriter_jbuild.cmxa"}
    "_build/install/default/lib/foo/ppx_rewriter_jbuild/foo_ppx_rewriter_jbuild.cmxs" {"ppx_rewriter_jbuild/foo_ppx_rewriter_jbuild.cmxs"}
    "_build/install/default/lib/foo/ppx_rewriter_jbuild/foo_ppx_rewriter_jbuild.ml" {"ppx_rewriter_jbuild/foo_ppx_rewriter_jbuild.ml"}
  ]
  libexec: [
    "_build/install/default/lib/foo/ppx_rewriter_dune/ppx.exe" {"ppx_rewriter_dune/ppx.exe"}
    "_build/install/default/lib/foo/ppx_rewriter_jbuild/ppx.exe" {"ppx_rewriter_jbuild/ppx.exe"}
  ]

stubs and js files installed

  $ dune build --root stubs
  Entering directory 'stubs'
  lib: [
    "_build/install/default/lib/foo/META" {"META"}
    "_build/install/default/lib/foo/cfoo.h" {"cfoo.h"}
    "_build/install/default/lib/foo/foo$ext_lib" {"foo$ext_lib"}
    "_build/install/default/lib/foo/foo.cma" {"foo.cma"}
    "_build/install/default/lib/foo/foo.cmi" {"foo.cmi"}
    "_build/install/default/lib/foo/foo.cmt" {"foo.cmt"}
    "_build/install/default/lib/foo/foo.cmx" {"foo.cmx"}
    "_build/install/default/lib/foo/foo.cmxa" {"foo.cmxa"}
    "_build/install/default/lib/foo/foo.cmxs" {"foo.cmxs"}
    "_build/install/default/lib/foo/foo.dune" {"foo.dune"}
    "_build/install/default/lib/foo/foo.js" {"foo.js"}
    "_build/install/default/lib/foo/foo.ml" {"foo.ml"}
    "_build/install/default/lib/foo/libfoo_stubs$ext_lib" {"libfoo_stubs$ext_lib"}
    "_build/install/default/lib/foo/opam" {"opam"}
  ]
  stublibs: [
    "_build/install/default/lib/stublibs/dllfoo_stubs$ext_dll"
  ]

install stanza is respected

  $ dune build --root install-stanza
  Entering directory 'install-stanza'
  lib: [
    "_build/install/default/lib/foo/META" {"META"}
    "_build/install/default/lib/foo/opam" {"opam"}
  ]
  share: [
    "_build/install/default/share/foo/foobar" {"foobar"}
    "_build/install/default/share/foo/share1"
  ]

public exes are installed

  $ dune build --root exe
  Entering directory 'exe'
  lib: [
    "_build/install/default/lib/foo/META" {"META"}
    "_build/install/default/lib/foo/opam" {"opam"}
  ]
  bin: [
    "_build/install/default/bin/bar" {"bar"}
  ]

mld files are installed

  $ dune build --root mld
  Entering directory 'mld'
  lib: [
    "_build/install/default/lib/foo/META" {"META"}
    "_build/install/default/lib/foo/opam" {"opam"}
  ]
  doc: [
    "_build/install/default/doc/foo/odoc-pages/doc.mld" {"odoc-pages/doc.mld"}
  ]

unwrapped libraries have the correct artifacts

  $ dune build --root lib-unwrapped
  Entering directory 'lib-unwrapped'
  lib: [
    "_build/install/default/lib/foo/META" {"META"}
    "_build/install/default/lib/foo/foo$ext_lib" {"foo$ext_lib"}
    "_build/install/default/lib/foo/foo.cma" {"foo.cma"}
    "_build/install/default/lib/foo/foo.cmi" {"foo.cmi"}
    "_build/install/default/lib/foo/foo.cmt" {"foo.cmt"}
    "_build/install/default/lib/foo/foo.cmti" {"foo.cmti"}
    "_build/install/default/lib/foo/foo.cmx" {"foo.cmx"}
    "_build/install/default/lib/foo/foo.cmxa" {"foo.cmxa"}
    "_build/install/default/lib/foo/foo.cmxs" {"foo.cmxs"}
    "_build/install/default/lib/foo/foo.dune" {"foo.dune"}
    "_build/install/default/lib/foo/foo.ml" {"foo.ml"}
    "_build/install/default/lib/foo/foo.mli" {"foo.mli"}
    "_build/install/default/lib/foo/opam" {"opam"}
  ]

wrapped lib with lib interface module

  $ dune build --root lib-wrapped-alias
  Entering directory 'lib-wrapped-alias'
  lib: [
    "_build/install/default/lib/foo/META" {"META"}
    "_build/install/default/lib/foo/bar.ml" {"bar.ml"}
    "_build/install/default/lib/foo/bar.mli" {"bar.mli"}
    "_build/install/default/lib/foo/foo$ext_lib" {"foo$ext_lib"}
    "_build/install/default/lib/foo/foo.cma" {"foo.cma"}
    "_build/install/default/lib/foo/foo.cmi" {"foo.cmi"}
    "_build/install/default/lib/foo/foo.cmt" {"foo.cmt"}
    "_build/install/default/lib/foo/foo.cmx" {"foo.cmx"}
    "_build/install/default/lib/foo/foo.cmxa" {"foo.cmxa"}
    "_build/install/default/lib/foo/foo.cmxs" {"foo.cmxs"}
    "_build/install/default/lib/foo/foo.dune" {"foo.dune"}
    "_build/install/default/lib/foo/foo.ml" {"foo.ml"}
    "_build/install/default/lib/foo/foo__.cmi" {"foo__.cmi"}
    "_build/install/default/lib/foo/foo__.cmt" {"foo__.cmt"}
    "_build/install/default/lib/foo/foo__.cmx" {"foo__.cmx"}
    "_build/install/default/lib/foo/foo__.ml" {"foo__.ml"}
    "_build/install/default/lib/foo/foo__Bar.cmi" {"foo__Bar.cmi"}
    "_build/install/default/lib/foo/foo__Bar.cmt" {"foo__Bar.cmt"}
    "_build/install/default/lib/foo/foo__Bar.cmti" {"foo__Bar.cmti"}
    "_build/install/default/lib/foo/foo__Bar.cmx" {"foo__Bar.cmx"}
    "_build/install/default/lib/foo/opam" {"opam"}
  ]

wrapped lib without lib interface module

  $ dune build --root lib-wrapped-no-alias
  Entering directory 'lib-wrapped-no-alias'
  lib: [
    "_build/install/default/lib/foo/META" {"META"}
    "_build/install/default/lib/foo/bar.ml" {"bar.ml"}
    "_build/install/default/lib/foo/bar.mli" {"bar.mli"}
    "_build/install/default/lib/foo/foo$ext_lib" {"foo$ext_lib"}
    "_build/install/default/lib/foo/foo.cma" {"foo.cma"}
    "_build/install/default/lib/foo/foo.cmi" {"foo.cmi"}
    "_build/install/default/lib/foo/foo.cmt" {"foo.cmt"}
    "_build/install/default/lib/foo/foo.cmx" {"foo.cmx"}
    "_build/install/default/lib/foo/foo.cmxa" {"foo.cmxa"}
    "_build/install/default/lib/foo/foo.cmxs" {"foo.cmxs"}
    "_build/install/default/lib/foo/foo.dune" {"foo.dune"}
    "_build/install/default/lib/foo/foo.ml" {"foo.ml"}
    "_build/install/default/lib/foo/foo__Bar.cmi" {"foo__Bar.cmi"}
    "_build/install/default/lib/foo/foo__Bar.cmt" {"foo__Bar.cmt"}
    "_build/install/default/lib/foo/foo__Bar.cmti" {"foo__Bar.cmti"}
    "_build/install/default/lib/foo/foo__Bar.cmx" {"foo__Bar.cmx"}
    "_build/install/default/lib/foo/opam" {"opam"}
  ]
