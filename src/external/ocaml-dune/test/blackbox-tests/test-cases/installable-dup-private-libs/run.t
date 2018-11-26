  $ dune build @install --display short
      ocamldep a1/.a.objs/a.ml.d
        ocamlc a1/.a.objs/a.{cmi,cmo,cmt}
      ocamlopt a1/.a.objs/a.{cmx,o}
      ocamlopt a1/a.{a,cmxa}
      ocamlopt a1/a.cmxs
      ocamldep a2/.a.objs/a.ml.d
        ocamlc a2/.a.objs/a.{cmi,cmo,cmt}
      ocamlopt a2/.a.objs/a.{cmx,o}
      ocamlopt a2/a.{a,cmxa}
      ocamlopt a2/a.cmxs
        ocamlc a1/a.cma
        ocamlc a2/a.cma
