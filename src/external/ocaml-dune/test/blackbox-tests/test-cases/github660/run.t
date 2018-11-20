  $ echo 'let hello = "hello"' > explicit-interfaces/lib_sub.ml
  $ echo 'let hello = "hello"' > no-interfaces/lib_sub.ml

When there are explicit interfaces, modules must be rebuilt.

  $ dune runtest --root explicit-interfaces
  Entering directory 'explicit-interfaces'
          main alias runtest
  hello
  $ echo 'let _x = 1' >> explicit-interfaces/lib_sub.ml
  $ dune runtest --root explicit-interfaces
  Entering directory 'explicit-interfaces'
          main alias runtest
  hello

When there are no interfaces, the situation is the same, but it is not possible
to rely on these.

  $ dune runtest --root no-interfaces
  Entering directory 'no-interfaces'
          main alias runtest
  hello
  $ echo 'let _x = 1' >> no-interfaces/lib_sub.ml
  $ dune runtest --root no-interfaces
  Entering directory 'no-interfaces'
          main alias runtest
  hello
