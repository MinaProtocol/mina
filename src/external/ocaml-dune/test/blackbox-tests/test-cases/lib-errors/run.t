Test various errors related to resolving libraries

Cycle detection
---------------

  $ dune build cycle.exe
  Error: Dependency cycle detected between the following libraries:
  -> "a" in _build/default
  -> "b" in _build/default
  -> "c" in _build/default
  -> "a" in _build/default
  -> required by library "c" in _build/default
  [1]

Select with no solution
-----------------------

  $ dune build select_error.exe
  File "dune", line 25, characters 12-27:
  25 |  (libraries (select x from))
                   ^^^^^^^^^^^^^^^
  Error: No solution found for this select form.
  [1]

