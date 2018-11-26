  $ dune build @install @runtest --display short
         ocaml config.full
      ocamldep src/.plop.eobjs/config.ml.d
      ocamldep src/.plop.eobjs/plop.ml.d
        ocamlc src/.plop.eobjs/config.{cmi,cmo,cmt}
      ocamlopt src/.plop.eobjs/config.{cmx,o}
        ocamlc src/.plop.eobjs/plop.{cmi,cmo,cmt}
      ocamlopt src/.plop.eobjs/plop.{cmx,o}
      ocamlopt src/plop.exe
