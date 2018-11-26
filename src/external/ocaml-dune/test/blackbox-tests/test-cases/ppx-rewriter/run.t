  $ dune build ./w_omp_driver.exe --display short
      ocamldep ppx/.fooppx.objs/fooppx.ml.d
        ocamlc ppx/.fooppx.objs/fooppx.{cmi,cmo,cmt}
      ocamlopt ppx/.fooppx.objs/fooppx.{cmx,o}
      ocamlopt ppx/fooppx.{a,cmxa}
      ocamlopt .ppx/jbuild/f659d13f55bdcc8a6ad052ed2f063a39/ppx.exe
           ppx w_omp_driver.pp.ml
      ocamldep .w_omp_driver.eobjs/w_omp_driver.pp.ml.d
        ocamlc .w_omp_driver.eobjs/w_omp_driver.{cmi,cmo,cmt}
      ocamlopt .w_omp_driver.eobjs/w_omp_driver.{cmx,o}
      ocamlopt w_omp_driver.exe

This test is broken because ppx_driver doesn't support migrate custom arguments
#  $ dune build ./w_ppx_driver_flags.exe --display short
  $ dune build && dune exec -- ocamlfind opt -package fooppx -ppxopt "fooppx,-flag" -linkpkg w_omp_driver.ml -o w_omp_driver.exe
  pass -arg to fooppx
