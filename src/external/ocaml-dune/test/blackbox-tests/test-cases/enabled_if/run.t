Test that `enabled_if` fields work as expected.

This alias is disabled, building it should do nothing:
  $ dune build @x

This one is enabled:
  $ dune build @y
  Building alias y

This rule is disabled, trying to build a should fail:
  $ dune build a
  Don't know how to build a
  Hint: did you mean b?
  [1]

This one is enabled:
  $ dune build b
  Building file b
