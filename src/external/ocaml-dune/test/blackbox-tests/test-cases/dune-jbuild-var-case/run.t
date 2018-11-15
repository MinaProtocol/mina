All builtin variables are lower cased in Dune:

  $ dune runtest --root dune-lower
  Entering directory 'dune-lower'

  $ dune runtest --root dune-upper
  Entering directory 'dune-upper'
  File "dune", line 3, characters 41-46:
  3 |  (action (with-stdout-to %{null} (echo %{MAKE}))))
                                               ^^^^^
  Error: %{MAKE} was renamed to '%{make}' in the 1.0 version of the dune language
  [1]

jbuild files retain the the old names:

  $ dune runtest --root jbuilder-upper
  Entering directory 'jbuilder-upper'

  $ dune runtest --root jbuilder-upper
  Entering directory 'jbuilder-upper'
