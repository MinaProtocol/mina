let test_query variables = Test_common.test_query Echo_schema.schema () ~variables

let suite : (string * [>`Quick] * (unit -> unit)) list = [
  ("string variable", `Quick, fun () ->
    let variables = ["x", `String "foo bar baz"] in
    let query = "{ string(x: $x) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "string", `String "foo bar baz"
      ]
    ])
  );
  ("float variable", `Quick, fun () ->
    let variables = ["x", `Float 42.5] in
    let query = "{ float(x: $x) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "float", `Float 42.5
      ]
    ])
  );
  ("int variable", `Quick, fun () ->
    let variables = ["x", `Int 42] in
    let query = "{ int(x: $x) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "int", `Int 42
      ]
    ])
  );
  ("bool variable", `Quick, fun () ->
    let variables = ["x", `Bool false] in
    let query = "{ bool(x: $x) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "bool", `Bool false
      ]
    ])
  );
  ("enum variable", `Quick, fun () ->
    let variables = ["x", `Enum "RED"] in
    let query = "{ enum(x: $x) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "enum", `String "RED"
      ]
    ])
  );
  ("list variable", `Quick, fun () ->
    let variables = ["x", `List [`Bool true; `Bool false]] in
    let query = "{ bool_list(x: [false, true]) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "bool_list", `List [
          `Bool false; `Bool true
        ]
      ]
    ])
  );
  ("input object variable", `Quick, fun () ->
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
  );
  ("null for optional variable", `Quick, fun () ->
    test_query ["x", `Null]"{ string(x: $x) }" (`Assoc [
      "data", `Assoc [
        "string", `Null
      ]
    ])
  );
  ("null for required variable", `Quick, fun () ->
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
  );
  ("variable coercion: single value to list", `Quick, fun () ->
    let variables = ["x", `Bool false] in
    let query = "{ bool_list(x: $x) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "bool_list", `List [
          `Bool false
        ]
      ]
    ])
  );
  ("variable coercion: int to float", `Quick, fun () ->
    let variables = ["x", `Int 42] in
    let query = "{ float(x: $x) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "float", `Float 42.0
      ]
    ])
  );
  ("variable coercion: int to ID", `Quick, fun () ->
    let variables = ["x", `Int 42] in
    let query = "{ id(x: $x) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "id", `String "42"
      ]
    ])
  );
  ("variable coercion: string to ID", `Quick, fun () ->
    let variables = ["x", `String "42"] in
    let query = "{ id(x: $x) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "id", `String "42"
      ]
    ])
  );
  (* ("default variable", `Quick, fun () -> *)
  (*   let query = "query has_defaults($x : Int! = 42) { int(x: $x) }" in *)
  (*   test_query [] query (`Assoc [ *)
  (*     "data", `Assoc [ *)
  (*       "int", `Int 42 *)
  (*     ] *)
  (*   ]) *)
  (* ); *)
  ("variable overrides default variable", `Quick, fun () ->
    let variables = ["x", `Int 43] in
    let query = "query has_defaults($x : Int! = 42) { int(x: $x) }" in
    test_query variables query (`Assoc [
      "data", `Assoc [
        "int", `Int 43
      ]
    ])
  );
]
