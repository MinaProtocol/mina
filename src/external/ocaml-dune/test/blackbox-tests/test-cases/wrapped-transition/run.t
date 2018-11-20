  $ dune build 2>&1 | grep -v ocamlc
  File "fooexe.ml", line 3, characters 0-7:
  Error (warning 3): deprecated: module Bar
  Will be removed past 2020-20-20. Use Mylib.Bar instead.
  File "fooexe.ml", line 4, characters 0-7:
  Error (warning 3): deprecated: module Foo
  Will be removed past 2020-20-20. Use Mylib.Foo instead.
  File "fooexe.ml", line 7, characters 11-22:
  Error (warning 3): deprecated: module Intf_only
  Will be removed past 2020-20-20. Use Mylib.Intf_only instead.
