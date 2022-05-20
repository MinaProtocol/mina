let test_query = Test_common.test_query Echo_schema.schema ()

let suite : (string * [>`Quick] * (unit -> unit)) list = [
  ("string argument", `Quick, fun () ->
    let query = "{ string(x: \"foo bar baz\") }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "string", `String "foo bar baz"
      ]
    ])
  );
  ("float argument", `Quick, fun () ->
    let query = "{ float(x: 42.5) }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "float", `Float 42.5
      ]
    ])
  );
  ("int argument", `Quick, fun () ->
    let query = "{ int(x: 42) }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "int", `Int 42
      ]
    ])
  );
  ("bool argument", `Quick, fun () ->
    let query = "{ bool(x: false) }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "bool", `Bool false
      ]
    ])
  );
  ("enum argument", `Quick, fun () ->
    let query = "{ enum(x: RED) }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "enum", `String "RED"
      ]
    ])
  );
  ("list argument", `Quick, fun () ->
    let query = "{ bool_list(x: [false, true]) }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "bool_list", `List [`Bool false; `Bool true]
      ]
    ])
  );
  ("input object argument", `Quick, fun () ->
    let query = "{ input_obj(x: {title: \"Mr\", first_name: \"John\", last_name: \"Doe\"}) }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "input_obj", `String "John Doe"
      ]
    ])
  );
  ("null for optional argument", `Quick, fun () ->
    let query = "{ string(x: null) }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "string", `Null
      ]
    ])
  );
  ("null for required argument", `Quick, fun () ->
    let query = "{ input_obj(x: null) }" in
    test_query query (`Assoc [
      "errors", `List [
        `Assoc [
          "message", `String "Argument `x` of type `person!` expected on field `input_obj`, found null."
        ]
      ];
      "data", `Null;
    ])
  );
  ("missing optional argument", `Quick, fun () ->
    let query = "{ string }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "string", `Null
      ]
    ])
  );
  ("missing required argument", `Quick, fun () ->
    let query = "{ input_obj }" in
    test_query query (`Assoc [
      "errors", `List [
        `Assoc [
          "message", `String "Argument `x` of type `person!` expected on field `input_obj`, but not provided."
        ]
      ];
      "data", `Null;
    ])
  );
  ("input coercion: single value to list", `Quick, fun () ->
    let query = "{ bool_list(x: false) }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "bool_list", `List [
          `Bool false
        ]
      ]
    ])
  );
  ("input coercion: int to float", `Quick, fun () ->
    let query = "{ float(x: 42) }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "float", `Float 42.0
      ]
    ])
  );
  ("input coercion: int to ID", `Quick, fun () ->
    let query = "{ id(x: 42) }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "id", `String "42"
      ]
    ])
  );
  ("input coercion: string to ID", `Quick, fun () ->
    let query = "{ id(x: \"42\") }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "id", `String "42"
      ]
    ])
  );
  ("default arguments", `Quick, fun () ->
    let query = "{ sum_defaults }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "sum_defaults", `Int 45
      ]
    ])
  )
]
