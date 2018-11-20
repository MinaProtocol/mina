Check that the error messages produced when using too many parentheses
are readable.

  $ dune build --root a
  File "dune", line 1, characters 12-72:
  1 | (executable (
  2 |   (name hello)
  3 |   (public_name hello)
  4 |   (libraries (lib))
  5 | ))
  Error: Atom expected
  Hint: dune files require less parentheses than jbuild files.
  If you just converted this file from a jbuild file, try removing these parentheses.
  [1]

  $ dune build --root b
  File "dune", line 4, characters 12-17:
  4 |  (libraries (lib)))
                  ^^^^^
  Error: 'select' expected
  Hint: dune files require less parentheses than jbuild files.
  If you just converted this file from a jbuild file, try removing these parentheses.
  [1]

  $ dune build --root c
  File "dune", line 3, characters 7-14:
  3 |  (deps (x y z)))
             ^^^^^^^
  Error: Unknown constructor x
  Hint: dune files require less parentheses than jbuild files.
  If you just converted this file from a jbuild file, try removing these parentheses.
  [1]

Checking that extra long stanzas (over 10 lines) are truncated in the middle, and the two blocks are aligned.
  $ dune build --root d
  File "dune", line 3, characters 13-192:
   3 |   (libraries (a
   4 |               b
   5 |               c
  ....
  12 |               j
  13 |               k
  14 |               l)
  Error: 'select' expected
  Hint: dune files require less parentheses than jbuild files.
  If you just converted this file from a jbuild file, try removing these parentheses.
  [1]

When the inner syntax is wrong, do not warn about the parens:

  $ dune build --root e
  File "dune", line 3, characters 7-15:
  3 |  (deps (glob *)) ; this form doesn't exist
             ^^^^^^^^
  Error: Unknown constructor glob
  Hint: dune files require less parentheses than jbuild files.
  If you just converted this file from a jbuild file, try removing these parentheses.
  [1]
