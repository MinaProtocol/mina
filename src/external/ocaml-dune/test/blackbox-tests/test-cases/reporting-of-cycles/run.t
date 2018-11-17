These tests is a regression test for the detection of dynamic cycles.

In all tests, we have a cycle that only becomes apparent after we
start running things. In the past, the error was only reported during
the second run of dune.

  $ dune build @package-cycle
  Dependency cycle between the following files:
      _build/.aliases/default/.b-files-00000000000000000000000000000000
  --> _build/.aliases/default/.a-files-00000000000000000000000000000000
  --> _build/.aliases/default/.b-files-00000000000000000000000000000000
  [1]

  $ dune build @simple-repro-case
  Dependency cycle between the following files:
      _build/default/x
  --> _build/default/y
  --> _build/default/x
  [1]

  $ dune build x1
  Dependency cycle between the following files:
      _build/default/x2
  --> _build/default/x3
  --> _build/default/x2
  [1]
