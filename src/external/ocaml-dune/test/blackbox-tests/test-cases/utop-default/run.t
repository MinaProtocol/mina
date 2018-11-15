By default, dune utop tries to make a toplevel for the current directory:

  $ echo 'exit 0;;' | dune utop --root lib-in-root . -- -init "" | grep -v 'version'
  Entering directory 'lib-in-root'
  
  Init file not found: "".
  # 


Utop will load libs recursively:

  $ echo 'exit 0;;' | dune utop --root nothing-in-root . -- -init "" | grep -v 'version'
  Entering directory 'nothing-in-root'
  
  Init file not found: "".
  # 


The message where the library path does not exist is different:

  $ dune utop --root nothing-in-root does-not-exist . -- -init ""
  Cannot find directory: does-not-exist
  [1]
