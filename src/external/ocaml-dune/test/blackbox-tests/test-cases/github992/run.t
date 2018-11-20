Variaous regression tests fixed by ocaml/dune#992

Interaction of (menhir ...) and -p
----------------------------------

This used to fail because dune couldn't associate a compilation
context to the menhir files when package bar was hidden.

  $ cd menhir-and-dash-p && dune build -p foo

package field without public_name field
---------------------------------------

This used to fail because the parser for the "package" field when
there is no "public_name"/"public_names" field used to not parse the
argument of "package".

  $ cd package-without-pub-name && dune build -p foo
  File "dune", line 3, characters 1-14:
  3 |  (package foo))
       ^^^^^^^^^^^^^
  Error: This field is useless without a (public_name ...) field.
  [1]

  $ cd package-without-pub-name-jbuild && dune build -p foo
  File "jbuild", line 3, characters 2-15:
  3 |   (package foo)))
        ^^^^^^^^^^^^^
  Warning: This field is useless without a (public_name ...) field.
