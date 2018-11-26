The empty list and atoms are printed as is:

  $ echo '()' | dune unstable-fmt
  ()

  $ echo 'a' | dune unstable-fmt
  a

Lists containing only atoms, quoted strings, templates, and singleton lists are
printed inline:

  $ echo '(atom "string" %{template} (singleton))' | dune unstable-fmt
  (atom "string" %{template} (singleton))

Other lists are displayed one element per line:

  $ echo '(a (b c d) e)' | dune unstable-fmt
  (a
   (b c d)
   e
  )

When there are several s-expressions, they are printed with an empty line
between them:

  $ echo '(a b) (c d)' | dune unstable-fmt
  (a b)
  
  (c d)

It is possible to pass a file name:

  $ dune unstable-fmt dune
  (a b)

A file can be fixed in place:

  $ echo '(a (b c))' > dune_temp
  $ dune unstable-fmt --inplace dune_temp
  $ cat dune_temp
  (a
   (b c)
  )

The --inplace flag requires a file name:

  $ dune unstable-fmt --inplace
  --inplace requires a file name
  [1]

Parse errors are displayed:

  $ echo '(' | dune unstable-fmt
  Parse error: unclosed parenthesis at end of input

and files are not removed when there is an error:

  $ echo '(a' > dune_temp
  $ dune unstable-fmt --inplace dune_temp
  Parse error: unclosed parenthesis at end of input
  $ cat dune_temp
  (a
