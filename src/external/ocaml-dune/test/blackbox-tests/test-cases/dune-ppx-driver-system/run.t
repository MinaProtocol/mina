No ppx driver found

  $ dune build foo1.cma
  File "dune", line 6, characters 13-18:
  6 |  (preprocess (pps)))
                   ^^^^^
  Error: You must specify at least one ppx rewriter.
  [1]

Too many drivers

  $ dune build foo2.cma
  File "dune", line 13, characters 13-28:
  13 |  (preprocess (pps ppx1 ppx2)))
                    ^^^^^^^^^^^^^^^
  Error: Too many incompatible ppx drivers were found: foo.driver2 and
  foo.driver1.
  [1]

Not compatible with Dune

  $ dune build foo3.cma
  File "dune", line 20, characters 13-28:
  20 |  (preprocess (pps ppx_other)))
                    ^^^^^^^^^^^^^^^
  Error: No ppx driver were found. It seems that ppx_other is not compatible
  with Dune. Examples of ppx rewriters that are compatible with Dune are ones
  using ocaml-migrate-parsetree, ppxlib or ppx_driver.
  [1]

Same, but with error pointing to .ppx

  $ dune build .ppx/foo.ppx1+foo.ppx2/ppx.exe
  File "_build/default/.ppx/foo.ppx1+foo.ppx2/ppx.exe", line 1, characters 0-0:
  Error: Failed to create on-demand ppx rewriter for foo.ppx1 and foo.ppx2; too
  many incompatible ppx drivers were found: foo.driver2 and foo.driver1.
  [1]

  $ dune build .ppx/foo.ppx-other/ppx.exe
  File "_build/default/.ppx/foo.ppx-other/ppx.exe", line 1, characters 0-0:
  Error: Failed to create on-demand ppx rewriter for foo.ppx-other; no ppx
  driver were found. It seems that foo.ppx-other is not compatible with Dune.
  Examples of ppx rewriters that are compatible with Dune are ones using
  ocaml-migrate-parsetree, ppxlib or ppx_driver.
  [1]

Test the argument syntax

  $ dune build test_ppx_args.cma
           ppx test_ppx_args.pp.ml
  .ppx/69cada8dd199103fc89e225db10f626e/ppx.exe
  -arg1
  -arg2
  -foo
  bar
  --cookie
  library-name="test_ppx_args"
  -o
  test_ppx_args.pp.ml
  --impl
  test_ppx_args.ml
  --as-ppx
  Error: Rule failed to generate the following targets:
  - test_ppx_args.pp.ml
  [1]

Test that going throught the -ppx option of the compiler works

  $ dune build test_ppx_staged.cma
      ocamldep .test_ppx_staged.objs/test_ppx_staged.ml.d
  tool name: ocamldep
  args:--as-ppx --cookie library-name="test_ppx_staged"
        ocamlc .test_ppx_staged.objs/test_ppx_staged.{cmi,cmo,cmt}
  tool name: ocamlc
  args:--as-ppx --cookie library-name="test_ppx_staged"
