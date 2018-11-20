  $ dune build --root exe @check --display short && ls exe/.merlin
  Entering directory 'exe'
      ocamldep .foo.eobjs/foo.ml.d
        ocamlc .foo.eobjs/foo.{cmi,cmo,cmt}
  exe/.merlin

  $ dune build --root lib @check --display short && ls lib/.merlin
  Entering directory 'lib'
      ocamldep .foo.objs/foo.ml.d
        ocamlc .foo.objs/foo.{cmi,cmo,cmt}
  lib/.merlin
