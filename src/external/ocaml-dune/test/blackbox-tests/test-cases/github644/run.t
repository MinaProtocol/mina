  $ dune runtest
  File "jbuild", line 4, characters 20-42:
  4 |   (preprocess (pps (ppx_that_doesn't_exist)))))
                          ^^^^^^^^^^^^^^^^^^^^^^
  Error: Library "ppx_that_doesn't_exist" not found.
  Hint: try: dune external-lib-deps --missing @runtest
  [1]

These should print something:

  $ dune external-lib-deps @runtest
  These are the external library dependencies in the default context:
  - ocaml-migrate-parsetree
  - ppx_that_doesn't_exist

  $ dune external-lib-deps --missing @runtest
  Error: The following libraries are missing in the default context:
  - ppx_that_doesn't_exist
  Hint: try: opam install ppx_that_doesn't_exist
  [1]
