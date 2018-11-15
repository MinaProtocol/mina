Successes:

  $ dune build --display short --root foo --debug-dep
  Entering directory 'foo'
      ocamldep test/.bar.objs/bar.ml.d
      ocamldep .foo.objs/foo.ml.d
        ocamlc .foo.objs/foo__.{cmi,cmo,cmt}
      ocamlopt .foo.objs/foo__.{cmx,o}
      ocamldep .foo.objs/intf.mli.d
        ocamlc .foo.objs/foo__Intf.{cmi,cmti}
        ocamlc .foo.objs/foo.{cmi,cmo,cmt}
        ocamlc test/.bar.objs/bar.{cmi,cmo,cmt}
      ocamlopt test/.bar.objs/bar.{cmx,o}
      ocamlopt test/bar.{a,cmxa}
      ocamlopt test/bar.cmxs
      ocamlopt .foo.objs/foo.{cmx,o}
      ocamlopt foo.{a,cmxa}
      ocamlopt foo.cmxs
        ocamlc foo.cma
        ocamlc test/bar.cma

Errors:

  $ dune build --display short --root a foo.cma
  Entering directory 'a'
  File "dune", line 1, characters 0-21:
  1 | (library
  2 |  (name foo))
  Warning: Some modules don't have an implementation.
  You need to add the following field to this stanza:
  
    (modules_without_implementation x y)
  
  This will become an error in the future.
        ocamlc .foo.objs/foo.{cmi,cmo,cmt}
        ocamlc foo.cma
  $ dune build --display short --root b foo.cma
  Entering directory 'b'
  File "dune", line 3, characters 33-34:
  3 |  (modules_without_implementation x))
                                       ^
  Warning: The following modules must be listed here as they don't have an implementation:
  - Y
  This will become an error in the future.
        ocamlc .foo.objs/foo.{cmi,cmo,cmt}
        ocamlc foo.cma
  $ dune build --display short --root c foo.cma
  Entering directory 'c'
  File "dune", line 3, characters 33-34:
  3 |  (modules_without_implementation x))
                                       ^
  Error: Module X doesn't exist.
  [1]
  $ dune build --display short --root d foo.cma
  Entering directory 'd'
  File "dune", line 3, characters 33-34:
  3 |  (modules_without_implementation x))
                                       ^
  Error: Module X has an implementation, it cannot be listed here
  [1]
