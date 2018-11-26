  $ dune build

  $ dune exec mytool
  m: init

  $ dune exec mytool inexistent
  m: init
  The package "inexistent" can't be found.

  $ dune exec mytool a
  m: init
  a: init

  $ dune exec mytool_modes_byte a
  m: init
  a: init

  $ dune exec mytool mytool-plugin-b
  m: init
  a: init
  b: init
  b: registering
  b: called
  a: called

  $ dune exec mytool mytool-plugin-b a
  m: init
  a: init
  b: init
  b: registering
  b: called
  a: called

  $ dune exec mytool_with_a
  a: init
  m: init

  $ dune exec mytool_with_a mytool-plugin-b
  a: init
  m: init
  b: init
  b: registering
  b: called
  a: called

  $ dune exec mytool_with_a a mytool-plugin-b
  a: init
  m: init
  b: init
  b: registering
  b: called
  a: called

  $ dune exe mytool_auto
  m: init
  a: init
  b: init
  b: registering
  b: called
  a: called

  $ dune exe mytool c_thread
  m: init
  c_thread: registering
