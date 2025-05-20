let test_query variables =
  Test_common.test_query Echo_schema.schema () ~variables

let string_variable_test () =
  let variables = [ ("x", `String "foo bar baz") ] in
  let query = "{ string(x: $x) }" in
  test_query variables query
    (`Assoc [ ("data", `Assoc [ ("string", `String "foo bar baz") ]) ])

let float_variable_test () =
  let variables = [ ("x", `Float 42.5) ] in
  let query = "{ float(x: $x) }" in
  test_query variables query
    (`Assoc [ ("data", `Assoc [ ("float", `Float 42.5) ]) ])

let int_variable_test () =
  let variables = [ ("x", `Int 42) ] in
  let query = "{ int(x: $x) }" in
  test_query variables query (`Assoc [ ("data", `Assoc [ ("int", `Int 42) ]) ])

let bool_variable_test () =
  let variables = [ ("x", `Bool false) ] in
  let query = "{ bool(x: $x) }" in
  test_query variables query
    (`Assoc [ ("data", `Assoc [ ("bool", `Bool false) ]) ])

let enum_variable_test () =
  let variables = [ ("x", `Enum "RED") ] in
  let query = "{ enum(x: $x) }" in
  test_query variables query
    (`Assoc [ ("data", `Assoc [ ("enum", `String "RED") ]) ])

let list_variable_test () =
  let variables = [ ("x", `List [ `Bool true; `Bool false ]) ] in
  let query = "{ bool_list(x: [false, true]) }" in
  test_query variables query
    (`Assoc
      [ ("data", `Assoc [ ("bool_list", `List [ `Bool false; `Bool true ]) ]) ]
      )

let input_object_variable_test () =
  let obj =
    `Assoc
      [ ("title", `String "Mr")
      ; ("first_name", `String "John")
      ; ("last_name", `String "Doe")
      ]
  in
  let variables = [ ("x", obj) ] in
  let query =
    "{ input_obj(x: {title: \"Mr\", first_name: \"John\", last_name: \"Doe\"}) \
     }"
  in
  test_query variables query
    (`Assoc [ ("data", `Assoc [ ("input_obj", `String "John Doe") ]) ])

let null_for_optional_variable_test () =
  test_query
    [ ("x", `Null) ]
    "{ string(x: $x) }"
    (`Assoc [ ("data", `Assoc [ ("string", `Null) ]) ])

let null_for_required_variable_test () =
  let variables = [ ("x", `Null) ] in
  let query = "{ input_obj(x: $x) }" in
  test_query variables query
    (`Assoc
      [ ( "errors"
        , `List
            [ `Assoc
                [ ( "message"
                  , `String
                      "Argument `x` of type `person!` expected on field \
                       `input_obj`, found null." )
                ]
            ] )
      ; ("data", `Null)
      ] )

let variable_coercion_single_value_to_list_test () =
  let variables = [ ("x", `Bool false) ] in
  let query = "{ bool_list(x: $x) }" in
  test_query variables query
    (`Assoc [ ("data", `Assoc [ ("bool_list", `List [ `Bool false ]) ]) ])

let variable_coercion_int_to_float_test () =
  let variables = [ ("x", `Int 42) ] in
  let query = "{ float(x: $x) }" in
  test_query variables query
    (`Assoc [ ("data", `Assoc [ ("float", `Float 42.0) ]) ])

let variable_coercion_int_to_id_test () =
  let variables = [ ("x", `Int 42) ] in
  let query = "{ id(x: $x) }" in
  test_query variables query
    (`Assoc [ ("data", `Assoc [ ("id", `String "42") ]) ])

let variable_coercion_string_to_id_test () =
  let variables = [ ("x", `String "42") ] in
  let query = "{ id(x: $x) }" in
  test_query variables query
    (`Assoc [ ("data", `Assoc [ ("id", `String "42") ]) ])

let default_variable_test () =
  let query = "query has_defaults($x : Int! = 42) { int(x: $x) }" in
  test_query [] query (`Assoc [ ("data", `Assoc [ ("int", `Int 42) ]) ])

let variable_overrides_default_variable_test () =
  let variables = [ ("x", `Int 43) ] in
  let query = "query has_defaults($x : Int! = 42) { int(x: $x) }" in
  test_query variables query (`Assoc [ ("data", `Assoc [ ("int", `Int 43) ]) ])

(* Run tests *)
let () =
  Alcotest.run "GraphQL Variable Tests"
    [ ( "variable handling"
      , [ Alcotest.test_case "string variable" `Quick string_variable_test
        ; Alcotest.test_case "float variable" `Quick float_variable_test
        ; Alcotest.test_case "int variable" `Quick int_variable_test
        ; Alcotest.test_case "bool variable" `Quick bool_variable_test
        ; Alcotest.test_case "enum variable" `Quick enum_variable_test
        ; Alcotest.test_case "list variable" `Quick list_variable_test
        ; Alcotest.test_case "input object variable" `Quick
            input_object_variable_test
        ; Alcotest.test_case "null for optional variable" `Quick
            null_for_optional_variable_test
        ; Alcotest.test_case "null for required variable" `Quick
            null_for_required_variable_test
        ; Alcotest.test_case "variable coercion: single value to list" `Quick
            variable_coercion_single_value_to_list_test
        ; Alcotest.test_case "variable coercion: int to float" `Quick
            variable_coercion_int_to_float_test
        ; Alcotest.test_case "variable coercion: int to ID" `Quick
            variable_coercion_int_to_id_test
        ; Alcotest.test_case "variable coercion: string to ID" `Quick
            variable_coercion_string_to_id_test
        ; Alcotest.test_case "default variable" `Quick default_variable_test
        ; Alcotest.test_case "variable overrides default variable" `Quick
            variable_overrides_default_variable_test
        ] )
    ]
