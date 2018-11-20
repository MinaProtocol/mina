  $ dune exec ./qnativerun/run.exe --display short
      ocamldep qnativerun/.run.eobjs/run.ml.d
        ocamlc q/q_stub$ext_obj
    ocamlmklib q/dllq_stubs$ext_dll,q/libq_stubs$ext_lib
      ocamldep q/.q.objs/q.ml.d
      ocamldep q/.q.objs/q.mli.d
        ocamlc q/.q.objs/q.{cmi,cmti}
      ocamlopt q/.q.objs/q.{cmx,o}
      ocamlopt q/q.{a,cmxa}
        ocamlc qnativerun/.run.eobjs/run.{cmi,cmo,cmt}
      ocamlopt qnativerun/.run.eobjs/run.{cmx,o}
      ocamlopt qnativerun/run.exe
  42
#  $ dune exec ./qbyterun/run.bc --display short
