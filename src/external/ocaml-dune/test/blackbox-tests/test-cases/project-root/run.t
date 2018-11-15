%{SCOPE_ROOT} (or ${SCOPE_ROOT} in jbuild files) refers to the root of the
project.

  $ dune runtest
  From dune-file/a/b/: ../../..
  From dune-file/a/: ../..
  From jbuild/a/b/: ../../..
  From jbuild/a/: ../..
  From root: .
