In dune files
-------------

Duplicating a field in a dune file is an error:

  $ dune build --root dune
  File "dune", line 4, characters 1-20:
  4 |  (action (echo bar)))
       ^^^^^^^^^^^^^^^^^^^
  Error: Field "action" is present too many times
  [1]

In jbuild files
---------------

For backward compatibility, it is only a warning in jbuild files:

  $ dune build --root jbuild
  File "jbuild", line 4, characters 2-21:
  4 |   (action (echo bar))))
        ^^^^^^^^^^^^^^^^^^^
  Warning: Field "action" is present several times, previous occurrences are ignored.
  Entering directory 'jbuild'
  bar
