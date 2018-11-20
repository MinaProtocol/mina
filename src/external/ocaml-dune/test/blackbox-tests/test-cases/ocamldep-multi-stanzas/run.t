  $ dune exec ./test.exe --debug-dep --display short --root jbuild --profile release
  Entering directory 'jbuild'
  File "jbuild", line 1, characters 0-0:
  Warning: Module "Lib" is used in several stanzas:
  - jbuild:2
  - jbuild:6
  To remove this warning, you must specify an explicit "modules" field in every
  library, executable, and executables stanzas in this jbuild file. Note that
  each module cannot appear in more than one "modules" field - it must belong
  to a single library or executable.
  This warning will become an error in the future.
  Multiple rules generated for _build/default/lib$ext_obj:
  - <internal location>
  - <internal location>
  [1]

  $ dune build src/a.cma --debug-dep --display short --root jbuild
  Entering directory 'jbuild'
  File "src/jbuild", line 1, characters 0-0:
  Warning: Module "X" is used in several stanzas:
  - src/jbuild:1
  - src/jbuild:2
  To remove this warning, you must specify an explicit "modules" field in every
  library, executable, and executables stanzas in this jbuild file. Note that
  each module cannot appear in more than one "modules" field - it must belong
  to a single library or executable.
  This warning will become an error in the future.
      ocamldep src/.a.objs/x.ml.d
        ocamlc src/.a.objs/a.{cmi,cmo,cmt}
        ocamlc src/.a.objs/a__X.{cmi,cmo,cmt}
        ocamlc src/a.cma

  $ dune exec ./test.exe --debug-dep --display short --root dune
  Entering directory 'dune'
  File "dune", line 1, characters 0-0:
  Error: Module "Lib" is used in several stanzas:
  - dune:1
  - dune:5
  To fix this error, you must specify an explicit "modules" field in every
  library, executable, and executables stanzas in this dune file. Note that
  each module cannot appear in more than one "modules" field - it must belong
  to a single library or executable.
  [1]

  $ dune build src/a.cma --debug-dep --display short --root dune
  Entering directory 'dune'
  File "src/dune", line 1, characters 0-0:
  Error: Module "X" is used in several stanzas:
  - src/dune:1
  - src/dune:2
  To fix this error, you must specify an explicit "modules" field in every
  library, executable, and executables stanzas in this dune file. Note that
  each module cannot appear in more than one "modules" field - it must belong
  to a single library or executable.
  [1]
