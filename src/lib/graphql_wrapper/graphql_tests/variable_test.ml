let test_query variables = Test_common.test_query Echo_schema.schema () ~variables

let%test_unit "string variable" =
    let variables = ["x", `String "foo bar baz"] in
    let query = "{ string(x: $x) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "string", `String "foo bar baz"
      ]
    ])
let%test_unit "float variable" =
    let variables = ["x", `Float 42.5] in
    let query = "{ float(x: $x) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "float", `Float 42.5
      ]
    ])
let%test_unit "int variable" =
    let variables = ["x", `Int 42] in
    let query = "{ int(x: $x) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "int", `Int 42
      ]
    ])
let%test_unit "bool variable" =
    let variables = ["x", `Bool false] in
    let query = "{ bool(x: $x) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "bool", `Bool false
      ]
    ])
let%test_unit "enum variable" =
    let variables = ["x", `Enum "RED"] in
    let query = "{ enum(x: $x) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "enum", `String "RED"
      ]
    ])

let%test_unit "list variable" =
    let variables = ["x", `List [`Bool true; `Bool false]] in
    let query = "{ bool_list(x: [false, true]) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "bool_list", `List [
          `Bool false; `Bool true
        ]
      ]
    ])

let%test_unit "input object variable" =
    let obj = `Assoc [
      "title", `String "Mr";
      "first_name", `String "John";
      "last_name", `String "Doe";
    ] in
    let variables = ["x", obj] in
    let query = "{ input_obj(x: {title: \"Mr\", first_name: \"John\", last_name: \"Doe\"}) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "input_obj", `String "John Doe"
      ]
    ])

let%test_unit "null for optional variable" =
    test_query ["x", `Null]"{ string(x: $x) }" (`Assoc [
      "data", `Assoc [
        "string", `Null
      ]
    ])

let%test_unit "null for required variable" =
    let variables = ["x", `Null] in
    let query = "{ input_obj(x: $x) }" in
    test_query variables query (`Assoc [
      "errors", `List [
        `Assoc [
          "message", `String "Argument `x` of type `person!` expected on field `input_obj`, found null."
        ]
      ];
      "data", `Null;
    ])

let%test_unit "variable coercion: single value to list" =
    let variables = ["x", `Bool false] in
    let query = "{ bool_list(x: $x) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "bool_list", `List [
          `Bool false
        ]
      ]
    ])

let%test_unit "variable coercion: int to float" =
    let variables = ["x", `Int 42] in
    let query = "{ float(x: $x) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "float", `Float 42.0
      ]
    ])

let%test_unit "variable coercion: int to ID" =
    let variables = ["x", `Int 42] in
    let query = "{ id(x: $x) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "id", `String "42"
      ]
    ])

let%test_unit "variable coercion: string to ID" =
    let variables = ["x", `String "42"] in
    let query = "{ id(x: $x) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "id", `String "42"
      ]
    ])

let%test_unit "default variable" =
    let query = "query has_defaults($x : Int! = 42) { int(x: $x) }" in
    test_query [] query (`Assoc [
      "data", `Assoc [
        "int", `Int 42
      ]
    ])
let%test_unit "variable overrides default variable" =
    let variables = ["x", `Int 43] in
    let query = "query has_defaults($x : Int! = 42) { int(x: $x) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "int", `Int 43
      ]
    ])
