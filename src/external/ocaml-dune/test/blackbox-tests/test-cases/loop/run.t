  $ dune build --display short a
          true x
          true y
  Dependency cycle between the following files:
      _build/default/a
  --> _build/default/b
  --> _build/default/a
  [1]

This second example is slightly more complicated as we request result1
but the cycle doesn't involve result1. We must make sure the output
does show a cycle.

  $ dune build --display short result1
  Dependency cycle between the following files:
      _build/default/result2
  --> _build/default/input
  --> _build/default/result2
  [1]

  $ dune build --display short result1 --debug-dependency-path
  Dependency cycle between the following files:
      _build/default/result2
  --> _build/default/input
  --> _build/default/result2
  -> required by input
  -> required by result1
  [1]
