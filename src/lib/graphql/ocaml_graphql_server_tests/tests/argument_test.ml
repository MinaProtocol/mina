let test_query = Test_common.test_query Echo_schema.schema ()

let string_argument_test () =
  let query = "{ string(x: \"foo bar baz\") }" in
  test_query query
    (`Assoc [ ("data", `Assoc [ ("string", `String "foo bar baz") ]) ])

let float_argument_test () =
  let query = "{ float(x: 42.5) }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("float", `Float 42.5) ]) ])

let int_argument_test () =
  let query = "{ int(x: 42) }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("int", `Int 42) ]) ])

let bool_argument_test () =
  let query = "{ bool(x: false) }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("bool", `Bool false) ]) ])

let enum_argument_test () =
  let query = "{ enum(x: RED) }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("enum", `String "RED") ]) ])

let list_argument_test () =
  let query = "{ bool_list(x: [false, true]) }" in
  test_query query
    (`Assoc
      [ ("data", `Assoc [ ("bool_list", `List [ `Bool false; `Bool true ]) ]) ]
      )

let input_object_argument_test () =
  let query =
    "{ input_obj(x: {title: \"Mr\", first_name: \"John\", last_name: \"Doe\"}) \
     }"
  in
  test_query query
    (`Assoc [ ("data", `Assoc [ ("input_obj", `String "John Doe") ]) ])

let null_for_optional_argument_test () =
  let query = "{ string(x: null) }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("string", `Null) ]) ])

let null_for_required_argument_test () =
  let query = "{ input_obj(x: null) }" in
  test_query query
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

let missing_optional_argument_test () =
  let query = "{ string }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("string", `Null) ]) ])

let missing_required_argument_test () =
  let query = "{ input_obj }" in
  test_query query
    (`Assoc
      [ ( "errors"
        , `List
            [ `Assoc
                [ ( "message"
                  , `String
                      "Argument `x` of type `person!` expected on field \
                       `input_obj`, but not provided." )
                ]
            ] )
      ; ("data", `Null)
      ] )

let input_coercion_single_value_to_list_test () =
  let query = "{ bool_list(x: false) }" in
  test_query query
    (`Assoc [ ("data", `Assoc [ ("bool_list", `List [ `Bool false ]) ]) ])

let input_coercion_int_to_float_test () =
  let query = "{ float(x: 42) }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("float", `Float 42.0) ]) ])

let input_coercion_int_to_id_test () =
  let query = "{ id(x: 42) }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("id", `String "42") ]) ])

let input_coercion_string_to_id_test () =
  let query = "{ id(x: \"42\") }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("id", `String "42") ]) ])

let default_arguments_test () =
  let query = "{ sum_defaults }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("sum_defaults", `Int 45) ]) ])

(* Run tests *)
let () =
  Alcotest.run "GraphQL Argument Tests"
    [ ( "argument handling"
      , [ Alcotest.test_case "string argument" `Quick string_argument_test
        ; Alcotest.test_case "float argument" `Quick float_argument_test
        ; Alcotest.test_case "int argument" `Quick int_argument_test
        ; Alcotest.test_case "bool argument" `Quick bool_argument_test
        ; Alcotest.test_case "enum argument" `Quick enum_argument_test
        ; Alcotest.test_case "list argument" `Quick list_argument_test
        ; Alcotest.test_case "input object argument" `Quick
            input_object_argument_test
        ; Alcotest.test_case "null for optional argument" `Quick
            null_for_optional_argument_test
        ; Alcotest.test_case "null for required argument" `Quick
            null_for_required_argument_test
        ; Alcotest.test_case "missing optional argument" `Quick
            missing_optional_argument_test
        ; Alcotest.test_case "missing required argument" `Quick
            missing_required_argument_test
        ; Alcotest.test_case "input coercion: single value to list" `Quick
            input_coercion_single_value_to_list_test
        ; Alcotest.test_case "input coercion: int to float" `Quick
            input_coercion_int_to_float_test
        ; Alcotest.test_case "input coercion: int to ID" `Quick
            input_coercion_int_to_id_test
        ; Alcotest.test_case "input coercion: string to ID" `Quick
            input_coercion_string_to_id_test
        ; Alcotest.test_case "default arguments" `Quick default_arguments_test
        ] )
    ]
