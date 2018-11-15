@all builds private exe's

  $ dune build --display short --root private-exe @all
  Entering directory 'private-exe'
      ocamldep .foo.eobjs/foo.ml.d
        ocamlc .foo.eobjs/foo.{cmi,cmo,cmt}
        ocamlc foo.bc
      ocamlopt .foo.eobjs/foo.{cmx,o}
      ocamlopt foo.exe

@all builds private libs

  $ dune build --display short --root private-lib @all
  Entering directory 'private-lib'
      ocamldep .bar.objs/bar.ml.d
        ocamlc .bar.objs/bar.{cmi,cmo,cmt}
      ocamlopt .bar.objs/bar.{cmx,o}
      ocamlopt bar.{a,cmxa}
      ocamlopt bar.cmxs
        ocamlc bar.cma

@all builds custom install stanzas

  $ dune build --root install-stanza @subdir/all
  Entering directory 'install-stanza'
  No rule found for subdir/foobar
  [1]

@all builds user defined rules

  $ dune build --display short --root user-defined @all
  Entering directory 'user-defined'
          echo foo

@all includes user defined install alias

  $ dune build --display short --root install-alias @all
  Entering directory 'install-alias'
          echo foo
