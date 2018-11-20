It is possible to add link-time dependencies.

In particular, these can depend on the result of the compilation (like a .cmo
file) and be created just before linking.

  $ dune build --display short link_deps.exe
      ocamldep .link_deps.eobjs/link_deps.ml.d
        ocamlc .link_deps.eobjs/link_deps.{cmi,cmo,cmt}
  link
      ocamlopt .link_deps.eobjs/link_deps.{cmx,o}
      ocamlopt link_deps.exe
