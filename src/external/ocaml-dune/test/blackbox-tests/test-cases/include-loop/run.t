  $ dune build --display short
  File "dune", line 1, characters 0-15:
  1 | (include a.inc)
      ^^^^^^^^^^^^^^^
  Error: Recursive inclusion of jbuild files detected:
  File a.inc is included from c.inc:1
  --> included from b.inc:1
  --> included from a.inc:1
  --> included from dune:1
  [1]
