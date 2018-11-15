  $ dune build --root accessible-via-public
  Entering directory 'accessible-via-public'
        runfoo alias default
  private module bar

  $ dune build --root inaccessible-in-deps 2>&1 | grep -v "cd _build"
  Entering directory 'inaccessible-in-deps'
        ocamlc .foo.eobjs/foo.{cmi,cmo,cmt} (exit 2)
  File "foo.ml", line 1, characters 0-5:
  Error: Unbound module X

  $ dune build --root excluded-from-install-file | grep -i priv
  Entering directory 'excluded-from-install-file'
    "_build/install/default/lib/lib/foo/priv2.cmt" {"foo/priv2.cmt"}
    "_build/install/default/lib/lib/foo/priv2.cmx" {"foo/priv2.cmx"}
    "_build/install/default/lib/lib/foo/priv2.ml" {"foo/priv2.ml"}
    "_build/install/default/lib/lib/lib__Priv.cmt" {"lib__Priv.cmt"}
    "_build/install/default/lib/lib/lib__Priv.cmx" {"lib__Priv.cmx"}
    "_build/install/default/lib/lib/priv.ml" {"priv.ml"}
