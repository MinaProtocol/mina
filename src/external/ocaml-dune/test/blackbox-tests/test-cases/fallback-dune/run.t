fallback isn't allowed in dune

  $ dune build --root dune1
  File "dune", line 2, characters 1-11:
  2 |  (fallback)
       ^^^^^^^^^^
  Error: 'fallback' was renamed to '(mode fallback)' in the 1.0 version of the dune language
  [1]

2nd fallback form isn't allowed either

  $ dune build --root dune2
  File "dune", line 2, characters 1-17:
  2 |  (fallback false)
       ^^^^^^^^^^^^^^^^
  Error: 'fallback' was renamed to '(mode fallback)' in the 1.0 version of the dune language
  [1]

But it is allowed in jbuilder

  $ jbuilder build --root jbuild
  Entering directory 'jbuild'
