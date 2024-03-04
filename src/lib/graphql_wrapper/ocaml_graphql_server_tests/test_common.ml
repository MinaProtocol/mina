module Schema = Graphql_wrapper.Make (Graphql.Schema)

let list_of_seq seq =
  let rec loop seq =
    match seq () with
    | Seq.Nil ->
        []
    | Seq.Cons (Ok x, next) ->
        x :: loop next
    | Seq.Cons (Error _, _) ->
        assert false
  in
  loop seq

let test_query schema ctx ?variables ?operation_name query expected =
  match Graphql_parser.parse query with
  | Error err ->
      failwith err
  | Ok doc ->
      let result =
        match Schema.execute schema ctx ?variables ?operation_name doc with
        | Ok (`Response data) ->
            data
        | Ok (`Stream stream) -> (
            try
              match stream () with
              | Seq.Cons (Ok _, _) ->
                  `List (list_of_seq stream)
              | Seq.Cons (Error err, _) ->
                  err
              | Seq.Nil ->
                  `Null
            with _ -> `String "caught stream exn" )
        | Error err ->
            err
      in
      if result <> expected then
        failwith
        @@ Format.asprintf "@[result:@;%a@;expected:@;%a@]" Yojson.Basic.pp
             result Yojson.Basic.pp expected
