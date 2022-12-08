open Test_common

module Field_error = struct
  type t = String of string | Extension of string * string

  let message_of_field_error t =
    match t with String s -> s | Extension _ -> ""

  let extensions_of_field_error t =
    match t with
    | String _ ->
        None
    | Extension (k, v) ->
        Some [ (k, `String v) ]
end

module CustomErrorsSchemaUnwrapped =
  Graphql_schema.Make
    (struct
      type +'a t = 'a

      let bind t f = f t

      let return t = t

      module Stream = struct
        type 'a t = 'a Seq.t

        let map t f = Seq.map f t

        let iter t f = Seq.iter f t

        let close _t = ()
      end
    end)
    (Field_error)

module CustomErrorsSchema = Graphql_wrapper.Make (CustomErrorsSchemaUnwrapped)

let test_query schema ctx ?variables ?operation_name query expected =
  match Graphql_parser.parse query with
  | Error err ->
      failwith err
  | Ok doc ->
      let result =
        match
          CustomErrorsSchema.execute schema ctx ?variables ?operation_name doc
        with
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
      result = expected
(* Alcotest.check yojson "invalid execution result" expected result *)

let schema =
  CustomErrorsSchema.(
    schema
      [ io_field "string_error" ~typ:int
          ~args:Arg.[]
          ~resolve:(fun _ () -> Error (Field_error.String "error string"))
      ; io_field "extensions_error" ~typ:int
          ~args:Arg.[]
          ~resolve:(fun _ () -> Error (Field_error.Extension ("custom", "json")))
      ])

let%test "message without extensions" =
  let query = "{ string_error }" in
  test_query schema () query
    (`Assoc
      [ ( "errors"
        , `List
            [ `Assoc
                [ ("message", `String "error string")
                ; ("path", `List [ `String "string_error" ])
                ]
            ] )
      ; ("data", `Assoc [ ("string_error", `Null) ])
      ] )

let%test "message with extensions" =
  let query = "{ extensions_error }" in
  test_query schema () query
    (`Assoc
      [ ( "errors"
        , `List
            [ `Assoc
                [ ("message", `String "")
                ; ("path", `List [ `String "extensions_error" ])
                ; ("extensions", `Assoc [ ("custom", `String "json") ])
                ]
            ] )
      ; ("data", `Assoc [ ("extensions_error", `Null) ])
      ] )
