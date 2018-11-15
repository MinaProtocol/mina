This test checks that there is no clash when two private libraries have the same name

  $ dune build --display short @doc-private
          odoc _doc/_html/odoc.css
      ocamldep a/.test.objs/test.ml.d
        ocamlc a/.test.objs/test.{cmi,cmo,cmt}
          odoc _doc/_odoc/lib/test@a/test.odoc
          odoc _doc/_html/test@a/Test/.dune-keep,_doc/_html/test@a/Test/index.html
      ocamldep b/.test.objs/test.ml.d
        ocamlc b/.test.objs/test.{cmi,cmo,cmt}
          odoc _doc/_odoc/lib/test@b/test.odoc
          odoc _doc/_html/test@b/Test/.dune-keep,_doc/_html/test@b/Test/index.html
