  $ dune build @print-merlins --display short --profile release
      ocamldep sanitize-dot-merlin/.sanitize_dot_merlin.eobjs/sanitize_dot_merlin.ml.d
        ocamlc sanitize-dot-merlin/.sanitize_dot_merlin.eobjs/sanitize_dot_merlin.{cmi,cmo,cmt}
      ocamlopt sanitize-dot-merlin/.sanitize_dot_merlin.eobjs/sanitize_dot_merlin.{cmx,o}
      ocamlopt sanitize-dot-merlin/sanitize_dot_merlin.exe
  sanitize_dot_merlin alias print-merlins
  # Processing exe/.merlin
  B $LIB_PREFIX/lib/bytes
  B $LIB_PREFIX/lib/findlib
  B $LIB_PREFIX/lib/ocaml
  B ../_build/default/exe/.x.eobjs
  B ../_build/default/lib/.foo.objs
  B ../_build/default/lib/.foo.objs/.private
  S $LIB_PREFIX/lib/bytes
  S $LIB_PREFIX/lib/findlib
  S $LIB_PREFIX/lib/ocaml
  S .
  S ../lib
  FLG -w -40
  # Processing lib/.merlin
  B $LIB_PREFIX/lib/bytes
  B $LIB_PREFIX/lib/findlib
  B $LIB_PREFIX/lib/ocaml
  B ../_build/default/lib/.bar.objs
  B ../_build/default/lib/.foo.objs
  S $LIB_PREFIX/lib/bytes
  S $LIB_PREFIX/lib/findlib
  S $LIB_PREFIX/lib/ocaml
  S .
  S subdir
  FLG -ppx '$PPX/2bf184f0d30fb809b587a965d82ab3a5/ppx.exe --as-ppx --cookie '\''library-name="foo"'\'''
  FLG -open Foo -w -40 -open Bar -w -40

Make sure a ppx directive is generated

  $ grep -q ppx lib/.merlin
