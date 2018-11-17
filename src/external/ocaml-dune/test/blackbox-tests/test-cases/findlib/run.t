  $ dune external-lib-deps @install
  These are the external library dependencies in the default context:
  - a
  - b
  - c

Reproduction case for #484. The error should point to src/jbuild

  $ dune build @install
  File "src/dune", line 4, characters 14-15:
  4 |  (libraries   a b c))
                    ^
  Error: Library "a" not found.
  Hint: try: dune external-lib-deps --missing @install
  [1]

When passing --dev, the profile should be displayed only once (#1106):

  $ jbuilder build --dev @install
  File "src/dune", line 4, characters 14-15:
  4 |  (libraries   a b c))
                    ^
  Error: Library "a" not found.
  Hint: try: dune external-lib-deps --missing --profile dev @install
  [1]

With dune and an explicit profile, it is the same:

  $ dune build --profile dev @install
  File "src/dune", line 4, characters 14-15:
  4 |  (libraries   a b c))
                    ^
  Error: Library "a" not found.
  Hint: try: dune external-lib-deps --missing --profile dev @install
  [1]
