open Graphql
module Schema = Graphql_wrapper.Make (Schema)
open Test_common

let nullable_error_test () =
  let schema =
    Schema.(
      schema
        [ io_field "nullable" ~typ:int
            ~args:Arg.[]
            ~resolve:(fun _ () -> Error "boom")
        ])
  in
  let query = "{ nullable }" in
  test_query schema () query
    (`Assoc
      [ ( "errors"
        , `List
            [ `Assoc
                [ ("message", `String "boom")
                ; ("path", `List [ `String "nullable" ])
                ]
            ] )
      ; ("data", `Assoc [ ("nullable", `Null) ])
      ] )

let non_nullable_error_test () =
  let schema =
    Schema.(
      schema
        [ io_field "non_nullable" ~typ:(non_null int)
            ~args:Arg.[]
            ~resolve:(fun _ () -> Error "boom")
        ])
  in
  let query = "{ non_nullable }" in
  test_query schema () query
    (`Assoc
      [ ( "errors"
        , `List
            [ `Assoc
                [ ("message", `String "boom")
                ; ("path", `List [ `String "non_nullable" ])
                ]
            ] )
      ; ("data", `Null)
      ] )

let nested_nullable_error_test () =
  let obj_with_non_nullable_field =
    Schema.(
      obj "obj" ~fields:(fun _ ->
          [ io_field "non_nullable" ~typ:(non_null int)
              ~args:Arg.[]
              ~resolve:(fun _ () -> Error "boom")
          ] ))
  in
  let schema =
    Schema.(
      schema
        [ field "nullable" ~typ:obj_with_non_nullable_field
            ~args:Arg.[]
            ~resolve:(fun _ () -> Some ())
        ])
  in
  let query = "{ nullable { non_nullable } }" in
  test_query schema () query
    (`Assoc
      [ ( "errors"
        , `List
            [ `Assoc
                [ ("message", `String "boom")
                ; ("path", `List [ `String "nullable"; `String "non_nullable" ])
                ]
            ] )
      ; ("data", `Assoc [ ("nullable", `Null) ])
      ] )

let error_in_list_test () =
  let foo =
    Schema.(
      obj "Foo" ~fields:(fun _ ->
          [ io_field "id" ~typ:int
              ~args:Arg.[]
              ~resolve:(fun _ (id, should_fail) ->
                if should_fail then Error "boom" else Ok (Some id) )
          ] ))
  in
  let schema =
    Schema.(
      schema
        [ field "foos"
            ~typ:(non_null (list (non_null foo)))
            ~args:Arg.[]
            ~resolve:(fun _ () -> [ (0, false); (1, false); (2, true) ])
        ])
  in
  let query = "{ foos { id } }" in
  test_query schema () query
    (`Assoc
      [ ( "errors"
        , `List
            [ `Assoc
                [ ("message", `String "boom")
                ; ("path", `List [ `String "foos"; `Int 2; `String "id" ])
                ]
            ] )
      ; ( "data"
        , `Assoc
            [ ( "foos"
              , `List
                  [ `Assoc [ ("id", `Int 0) ]
                  ; `Assoc [ ("id", `Int 1) ]
                  ; `Assoc [ ("id", `Null) ]
                  ] )
            ] )
      ] )

(* Run tests *)
let () =
  Alcotest.run "GraphQL Error Tests"
    [ ( "error handling"
      , [ Alcotest.test_case "nullable error" `Quick nullable_error_test
        ; Alcotest.test_case "non-nullable error" `Quick non_nullable_error_test
        ; Alcotest.test_case "nested nullable error" `Quick
            nested_nullable_error_test
        ; Alcotest.test_case "error in list" `Quick error_in_list_test
        ] )
    ]
