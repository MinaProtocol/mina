If there is an (action) field, it is used to invoke to the executable (in both
regular and expect modes:

  $ dune build @explicit-regular/runtest
       my_test alias explicit-regular/runtest
  argv[0] = "./my_test.exe"
  argv[1] = "arg1"
  argv[2] = "arg2"
  argv[3] = "arg3"

  $ dune build @explicit-expect/runtest

If there is no field, the program is run with no arguments:

  $ dune build @default/runtest
       my_test alias default/runtest
  argv[0] = "./my_test.exe"
