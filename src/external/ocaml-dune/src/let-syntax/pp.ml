let () =
  let pp =
    Lexer.create
      ~output_fname:(Sys.argv.(1) ^ ".generated")
      ~oc:stdout
  in
  Lexer.apply pp ~fname:Sys.argv.(1)
