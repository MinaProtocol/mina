Formatting can be checked using the @fmt target:

  $ cp enabled/ocaml_file.ml.orig enabled/ocaml_file.ml
  $ cp enabled/reason_file.re.orig enabled/reason_file.re
  $ dune build --display short @fmt
      ocamldep fake-tools/.ocamlformat.eobjs/ocamlformat.ml.d
      ocamldep fake-tools/.ocamlformat.eobjs/refmt.ml.d
        ocamlc fake-tools/.ocamlformat.eobjs/refmt.{cmi,cmo,cmt}
      ocamlopt fake-tools/.ocamlformat.eobjs/refmt.{cmx,o}
      ocamlopt fake-tools/refmt.exe
         refmt enabled/.formatted/reason_file.re
  File "enabled/reason_file.re", line 1, characters 0-0:
  Files _build/default/enabled/reason_file.re and _build/default/enabled/.formatted/reason_file.re differ.
        ocamlc fake-tools/.ocamlformat.eobjs/ocamlformat.{cmi,cmo,cmt}
      ocamlopt fake-tools/.ocamlformat.eobjs/ocamlformat.{cmx,o}
      ocamlopt fake-tools/ocamlformat.exe
   ocamlformat enabled/.formatted/ocaml_file.mli
  File "enabled/ocaml_file.mli", line 1, characters 0-0:
  Files _build/default/enabled/ocaml_file.mli and _build/default/enabled/.formatted/ocaml_file.mli differ.
         refmt enabled/.formatted/reason_file.rei
  File "enabled/reason_file.rei", line 1, characters 0-0:
  Files _build/default/enabled/reason_file.rei and _build/default/enabled/.formatted/reason_file.rei differ.
   ocamlformat enabled/.formatted/ocaml_file.ml
  File "enabled/ocaml_file.ml", line 1, characters 0-0:
  Files _build/default/enabled/ocaml_file.ml and _build/default/enabled/.formatted/ocaml_file.ml differ.
   ocamlformat enabled/subdir/.formatted/lib.ml
  File "enabled/subdir/lib.ml", line 1, characters 0-0:
  Files _build/default/enabled/subdir/lib.ml and _build/default/enabled/subdir/.formatted/lib.ml differ.
   ocamlformat partial/.formatted/a.ml
  File "partial/a.ml", line 1, characters 0-0:
  Files _build/default/partial/a.ml and _build/default/partial/.formatted/a.ml differ.
  [1]

Configuration files are taken into account for this action:

  $ touch enabled/.ocamlformat
  $ dune build --display short @fmt
  File "enabled/reason_file.re", line 1, characters 0-0:
  Files _build/default/enabled/reason_file.re and _build/default/enabled/.formatted/reason_file.re differ.
  File "enabled/reason_file.rei", line 1, characters 0-0:
  Files _build/default/enabled/reason_file.rei and _build/default/enabled/.formatted/reason_file.rei differ.
  File "partial/a.ml", line 1, characters 0-0:
  Files _build/default/partial/a.ml and _build/default/partial/.formatted/a.ml differ.
   ocamlformat enabled/.formatted/ocaml_file.mli
  File "enabled/ocaml_file.mli", line 1, characters 0-0:
  Files _build/default/enabled/ocaml_file.mli and _build/default/enabled/.formatted/ocaml_file.mli differ.
   ocamlformat enabled/.formatted/ocaml_file.ml
  File "enabled/ocaml_file.ml", line 1, characters 0-0:
  Files _build/default/enabled/ocaml_file.ml and _build/default/enabled/.formatted/ocaml_file.ml differ.
   ocamlformat enabled/subdir/.formatted/lib.ml
  File "enabled/subdir/lib.ml", line 1, characters 0-0:
  Files _build/default/enabled/subdir/lib.ml and _build/default/enabled/subdir/.formatted/lib.ml differ.
  [1]

And fixable files can be promoted:

  $ dune promote enabled/ocaml_file.ml enabled/reason_file.re
  Promoting _build/default/enabled/.formatted/ocaml_file.ml to enabled/ocaml_file.ml.
  Promoting _build/default/enabled/.formatted/reason_file.re to enabled/reason_file.re.
  $ cat enabled/ocaml_file.ml
  Sys.argv: ../../install/default/bin/ocamlformat --impl ocaml_file.ml --name ../../../enabled/ocaml_file.ml -o .formatted/ocaml_file.ml
  ocamlformat output
  $ cat enabled/reason_file.re
  Sys.argv: ../../install/default/bin/refmt reason_file.re
  refmt output

All .ocamlformat files are considered dependencies:

  $ echo 'margin = 70' > .ocamlformat
  $ dune build --display short @fmt
  File "enabled/reason_file.rei", line 1, characters 0-0:
  Files _build/default/enabled/reason_file.rei and _build/default/enabled/.formatted/reason_file.rei differ.
         refmt enabled/.formatted/reason_file.re
   ocamlformat enabled/.formatted/ocaml_file.mli
  File "enabled/ocaml_file.mli", line 1, characters 0-0:
  Files _build/default/enabled/ocaml_file.mli and _build/default/enabled/.formatted/ocaml_file.mli differ.
   ocamlformat enabled/.formatted/ocaml_file.ml
   ocamlformat enabled/subdir/.formatted/lib.ml
  File "enabled/subdir/lib.ml", line 1, characters 0-0:
  Files _build/default/enabled/subdir/lib.ml and _build/default/enabled/subdir/.formatted/lib.ml differ.
   ocamlformat partial/.formatted/a.ml
  File "partial/a.ml", line 1, characters 0-0:
  Files _build/default/partial/a.ml and _build/default/partial/.formatted/a.ml differ.
  [1]
