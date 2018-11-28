Environment variables defined in (env) are set during execution.

They can be set from the workspace:

  $ dune exec --root precedence ./printenv.exe VARIABLE_FROM_WORKSPACE
  Entering directory 'precedence'
  Entering directory 'precedence'
  VARIABLE_FROM_WORKSPACE=value1

From a (context) stanza in the workspace:

  $ dune exec --root precedence ./printenv.exe VARIABLE_FROM_CONTEXT
  Entering directory 'precedence'
  Entering directory 'precedence'
  VARIABLE_FROM_CONTEXT=value2

When a variable is set from both a context and a global one, the context one is
used.

  $ dune exec --root precedence ./printenv.exe VARIABLE_FROM_BOTH
  Entering directory 'precedence'
  Entering directory 'precedence'
  VARIABLE_FROM_BOTH=from_workspace

When a variable is repeated, an error message is displayed:

  $ dune build --root duplicate
  File "dune-workspace", line 4, characters 4-43:
  4 |     (VARIABLE value1)
  5 |     (VARIABLE value2)
  Error: Variable VARIABLE is specified several times
  [1]
