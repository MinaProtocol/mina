  $ dune runtest

  $ cp hello.wrong-output hello.expected
  $ dune runtest
  File "hello.expected", line 1, characters 0-0:
  Files _build/default/hello.expected and _build/default/hello.output differ.
  [1]
  $ dune promote
  Promoting _build/default/hello.output to hello.expected.
  $ cat hello.expected
  Hello, world!

  $ dune build @cmp
  Error: Files _build/default/a and _build/default/b differ.
  [1]
