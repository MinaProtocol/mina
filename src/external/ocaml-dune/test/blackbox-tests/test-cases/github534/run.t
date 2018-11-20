  $ dune exec ./main.exe --display short
          echo main.ml
      ocamldep .main.eobjs/main.ml.d
        ocamlc .main.eobjs/main.{cmi,cmo,cmt}
      ocamlopt .main.eobjs/main.{cmx,o}
      ocamlopt main.exe
  Hello World
