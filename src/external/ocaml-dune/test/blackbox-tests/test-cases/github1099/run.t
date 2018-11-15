If the source directory does not exist, an error message is printed:

  $ dune build --root no-dir demo.exe
  Entering directory 'no-dir'
  File "dune", line 1, characters 13-23:
  1 | (copy_files# "no_dir/*")
                   ^^^^^^^^^^
  Error: cannot find directory: no_dir
  [1]

This works also is a file exists with the same name:

  $ dune build --root file-with-same-name demo.exe
  Entering directory 'file-with-same-name'
  File "dune", line 1, characters 13-23:
  1 | (copy_files# "no_dir/*")
                   ^^^^^^^^^^
  Error: cannot find directory: no_dir
  [1]
