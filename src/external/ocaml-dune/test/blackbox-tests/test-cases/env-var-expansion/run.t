Make sure that we require a default value regardless of the context

  $ dune build --root missing-default-in-action @echo
  Entering directory 'missing-default-in-action'
  File "dune", line 3, characters 17-34:
  3 |  (action (echo %{env:DUNE_ENV_VAR})))
                       ^^^^^^^^^^^^^^^^^
  Error: %{env:..} must always come with a default value
  Hint: the syntax is %{env:VAR=DEFAULT-VALUE}
  [1]
  $ dune build --root missing-default-in-blang @echo
  Entering directory 'missing-default-in-blang'
  File "dune", line 3, characters 23-40:
  3 |  (enabled_if (= true %{env:DUNE_ENV_VAR}))
                             ^^^^^^^^^^^^^^^^^
  Error: %{env:..} must always come with a default value
  Hint: the syntax is %{env:VAR=DEFAULT-VALUE}
  [1]

Actually test that the environment changes are properly tracked, i.e. that
incrementality works properly, that (setenv ...) is taken into account, etc.

  $ dune build --root correct @echo1
  Entering directory 'correct'
  true
  $ DUNE_ENV_VAR=true dune build --root correct @echo1
  Entering directory 'correct'
  $ DUNE_ENV_VAR=false dune build --root correct @echo1
  Entering directory 'correct'
  false
  $ DUNE_ENV_VAR=false dune build --root correct @echo1
  Entering directory 'correct'
  $ DUNE_ENV_VAR=true dune build --root correct @echo1
  Entering directory 'correct'
  true

This test is broken because previous/new values should differ in these tests. In
the dune file, the environment variable ends up being set locally, but this
isn't reflected on a per action basis.
  $ dune build --root correct @echo2
  Entering directory 'correct'
  previous env: unset
  new env:set by setenv
  $ DUNE_ENV_VAR=true dune build --root correct @echo2
  Entering directory 'correct'
  previous env: true
  new env:set by setenv
  $ DUNE_ENV_VAR=false dune build --root correct @echo2
  Entering directory 'correct'
  previous env: false
  new env:set by setenv

  $ dune build --root correct @enabled
  Entering directory 'correct'
  enabled!
  $ DUNE_ENV_VAR=true dune build --root correct @enabled
  Entering directory 'correct'
  $ DUNE_ENV_VAR=false dune build --root correct @enabled
  Entering directory 'correct'

  $ dune build --root correct @disabled
  Entering directory 'correct'
  $ DUNE_ENV_VAR=true dune build --root correct @disabled
  Entering directory 'correct'
  enabled!
  $ DUNE_ENV_VAR=false dune build --root correct @disabled
  Entering directory 'correct'

  $ dune build --root nesting
  Entering directory 'nesting'
  Initial value of unset
  Now set: XXXX
  From bar: from bar
