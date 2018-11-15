The error message for (copy_files ...) from another non sub directory should report the
version that introduced this feature:

  $ dune build
  File "src/dune", line 1, characters 12-24:
  1 | (copy_files ../to_copy/*)
                  ^^^^^^^^^^^^
  Error: to_copy/* is not a sub-directory of src. This is only available since version 1.3 of the dune language
  [1]
