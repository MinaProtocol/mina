let yojson = (module struct
  type t = Yojson.Basic.json

  let pp formatter t =
    Format.pp_print_text formatter (Yojson.Basic.pretty_to_string t)

  let equal = (=)
end : Alcotest.TESTABLE with type t = Yojson.Basic.json) [@@warning "-3"]

let list_of_seq seq =
  let rec loop seq =
    match seq() with
      | Seq.Nil -> []
      | Seq.Cons (Ok x, next) -> x :: loop next
      | Seq.Cons (Error _, _) -> assert false
  in
  loop seq

let test_query schema ctx ?variables ?operation_name query expected =
  match Graphql_parser.parse query with
  | Error err -> failwith err
  | Ok doc ->
      let result = match Graphql.Schema.execute schema ctx ?variables ?operation_name doc with
      | Ok (`Response data) -> data
      | Ok (`Stream stream) ->
          begin try match stream () with
          | Seq.Cons (Ok _, _) -> `List (list_of_seq stream)
          | Seq.Cons (Error err, _) -> err
          | Seq.Nil -> `Null
          with _ -> `String "caught stream exn" end
      | Error err -> err
      in
      Alcotest.check yojson "invalid execution result" expected result
