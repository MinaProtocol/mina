When a public executable is built in shared_object mode, a specific error
message is displayed:

  $ dune build --root=public --display=short
  File "jbuild", line 4, characters 2-74:
  4 |   (
  5 |    (name mylib)
  6 |    (public_name mylib)
  7 |    (modes (shared_object))
  8 |    )
  Error: No installable mode found for this executable.
  One of the following modes is required:
   - exe
   - native
   - byte
  [1]

However, it is possible to build a private one explicitly.

  $ dune build --root=private --display=short myprivatelib.so
  Entering directory 'private'
      ocamldep .myprivatelib.eobjs/myprivatelib.ml.d
        ocamlc .myprivatelib.eobjs/myprivatelib.{cmi,cmo,cmt}
      ocamlopt .myprivatelib.eobjs/myprivatelib.{cmx,o}
      ocamlopt myprivatelib$ext_dll
