  $ dune build @install @runtest --display short
      ocamldep bin/.main.eobjs/main.ml.d
      ocamldep lib/.hello_world.objs/hello_world.ml.d
        ocamlc lib/.hello_world.objs/hello_world.{cmi,cmo,cmt}
      ocamlopt lib/.hello_world.objs/hello_world.{cmx,o}
      ocamlopt lib/hello_world.{a,cmxa}
      ocamlopt lib/hello_world.cmxs
      ocamldep test/.test.eobjs/test.ml.d
        ocamlc test/.test.eobjs/test.{cmi,cmo,cmt}
      ocamlopt test/.test.eobjs/test.{cmx,o}
      ocamlopt test/test.exe
          test test/test.output
        ocamlc lib/hello_world.cma
        ocamlc bin/.main.eobjs/main.{cmi,cmo,cmt}
      ocamlopt bin/.main.eobjs/main.{cmx,o}
      ocamlopt bin/main.exe
