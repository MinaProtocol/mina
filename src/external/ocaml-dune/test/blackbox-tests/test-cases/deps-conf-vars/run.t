  $ dune build --root static
  Entering directory 'static'
  deps: ../install/default/lib/foo/foo.cma
  $ dune build --root dynamic
  Entering directory 'dynamic'
  File "dune", line 3, characters 9-18:
  3 |  (deps %{read:foo}))
               ^^^^^^^^^
  Error: %{read:..} cannot be used in this position
  [1]

  $ dune build --root alias-lib-file
  Entering directory 'alias-lib-file'
  deps: ../install/default/lib/foo/theories/a
