let () =
  let module C = Configurator.V1 in
  C.main ~name:"foo" (fun _c ->
    C.Flags.write_lines "foo" ["asdf"])
