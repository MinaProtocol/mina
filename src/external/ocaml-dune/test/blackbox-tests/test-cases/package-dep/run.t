  $ dune runtest --display short
      ocamldep .bar.objs/bar.ml.d
      ocamldep .foo.objs/foo.ml.d
        ocamlc .foo.objs/foo.{cmi,cmo,cmt}
        ocamlc .bar.objs/bar.{cmi,cmo,cmt}
      ocamlopt .bar.objs/bar.{cmx,o}
      ocamlopt bar.{a,cmxa}
      ocamlopt bar.cmxs
        ocamlc bar.cma
      ocamlopt .foo.objs/foo.{cmx,o}
      ocamlopt foo.{a,cmxa}
      ocamlopt foo.cmxs
        ocamlc foo.cma
     ocamlfind test.exe
          test alias runtest
  42 42
