let _ =
  Coda_graphql.result_of_exn (fun x -> x) Coda_graphql.schema ~error:`Error

let () = print_endline "help"
