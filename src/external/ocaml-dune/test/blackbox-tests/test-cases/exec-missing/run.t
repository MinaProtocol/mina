When using dune exec, the external-lib-deps command refers to the executable:

  $ dune exec ./x.exe
  File "dune", line 3, characters 12-26:
  3 |  (libraries does-not-exist))
                  ^^^^^^^^^^^^^^
  Error: Library "does-not-exist" not found.
  Hint: try: dune external-lib-deps --missing ./x.exe
  [1]
