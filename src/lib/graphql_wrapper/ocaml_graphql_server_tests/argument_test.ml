let test_query = Test_common.test_query Echo_schema.schema ()

let%test_unit "string argument" =
  let query = "{ string(x: \"foo bar baz\") }" in
  test_query query
    (`Assoc [ ("data", `Assoc [ ("string", `String "foo bar baz") ]) ])

let%test_unit "float argument" =
  let query = "{ float(x: 42.5) }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("float", `Float 42.5) ]) ])

let%test_unit "int argument" =
  let query = "{ int(x: 42) }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("int", `Int 42) ]) ])

let%test_unit "bool argument" =
  let query = "{ bool(x: false) }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("bool", `Bool false) ]) ])

let%test_unit "enum argument" =
  let query = "{ enum(x: RED) }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("enum", `String "RED") ]) ])

let%test_unit "list argument" =
  let query = "{ bool_list(x: [false, true]) }" in
  test_query query
    (`Assoc
      [ ("data", `Assoc [ ("bool_list", `List [ `Bool false; `Bool true ]) ]) ]
      )

let%test_unit "input object argument" =
  let query =
    "{ input_obj(x: {title: \"Mr\", first_name: \"John\", last_name: \"Doe\"}) \
     }"
  in
  test_query query
    (`Assoc [ ("data", `Assoc [ ("input_obj", `String "John Doe") ]) ])

let%test_unit "null for optional argument" =
  let query = "{ string(x: null) }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("string", `Null) ]) ])

let%test_unit "null for required argument" =
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

let%test_unit "missing optional argument" =
  let query = "{ string }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("string", `Null) ]) ])

let%test_unit "missing required argument" =
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

let%test_unit "input coercion: single value to list" =
  let query = "{ bool_list(x: false) }" in
  test_query query
    (`Assoc [ ("data", `Assoc [ ("bool_list", `List [ `Bool false ]) ]) ])

let%test_unit "input coercion: int to float" =
  let query = "{ float(x: 42) }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("float", `Float 42.0) ]) ])

let%test_unit "input coercion: int to ID" =
  let query = "{ id(x: 42) }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("id", `String "42") ]) ])

let%test_unit "input coercion: string to ID" =
  let query = "{ id(x: \"42\") }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("id", `String "42") ]) ])

let%test_unit "default arguments" =
  let query = "{ sum_defaults }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("sum_defaults", `Int 45) ]) ])
