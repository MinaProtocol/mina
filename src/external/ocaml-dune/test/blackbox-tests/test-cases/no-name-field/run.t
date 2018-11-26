the name field can be omitted for libraries when public_name is present
  $ dune build --root no-name-lib
  Entering directory 'no-name-lib'

this isn't possible for older syntax <= (1, 0)
  $ dune build --root no-name-lib-syntax-1-0
  File "dune", line 1, characters 22-25:
  1 | (library (public_name foo))
                            ^^^
  Error: name field cannot be omitted before version 1.1 of the dune language
  [1]

executable(s) stanza works the same way

  $ dune build --root no-name-exes
  Entering directory 'no-name-exes'

  $ dune build --root no-name-exes-syntax-1-0
  File "dune", line 1, characters 0-36:
  1 | (executables (public_names foo bar))
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Error: names field may not be omitted before dune version 1.1
  [1]

there's only a public name but it's invalid as a name

  $ dune build --root public-name-invalid-name
  File "dune", line 1, characters 22-28:
  1 | (library (public_name c.find))
                            ^^^^^^
  Error: invalid library name.
  Hint: library names must be non-empty and composed only of the following characters: 'A'..'Z',  'a'..'z', '_'  or '0'..'9'.
  Public library names don't have this restriction. You can either change this public name to be a valid library name or add a "name" field with a valid library name.
  [1]

there's only a public name which is invalid, but sine the library is unwrapped,
it's just a warning

  $ dune build --root public-name-invalid-wrapped-false
  File "dune", line 3, characters 14-21:
  3 |  (public_name foo.bar))
                    ^^^^^^^
  Error: invalid library name.
  Hint: library names must be non-empty and composed only of the following characters: 'A'..'Z',  'a'..'z', '_'  or '0'..'9'.
  Public library names don't have this restriction. You can either change this public name to be a valid library name or add a "name" field with a valid library name.
  [1]
