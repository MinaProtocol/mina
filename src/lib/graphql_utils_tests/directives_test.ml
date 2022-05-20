let test_query = Test_common.test_query Test_schema.schema ()

let suite = [
  ("skip directive", `Quick, fun () ->
    let query = "{ users { id @skip(if: true) name } }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "users", `List [
          `Assoc [
            "name", `String "Alice"
          ];
          `Assoc [
            "name", `String "Bob"
          ];
          `Assoc [
            "name", `String "Charlie"
          ]
        ]
      ]
    ])
  );
  ("include directive", `Quick, fun () ->
    let query = "{ users { id @include(if: false) name } }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "users", `List [
          `Assoc [
            "name", `String "Alice"
          ];
          `Assoc [
            "name", `String "Bob"
          ];
          `Assoc [
            "name", `String "Charlie"
          ]
        ]
      ]
    ])
  );
  (*
   * Per the link below, the field "must be queried only if the @skip
   * condition is false and the @include condition is true".
   * http://facebook.github.io/graphql/June2018/#sec--include
   *)
  ("both skip and include directives, field not queried", `Quick, fun () ->
    let query = "{ users { role @skip(if: true) @include(if: true) name } }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "users", `List [
          `Assoc [
            "name", `String "Alice"
          ];
          `Assoc [
            "name", `String "Bob"
          ];
          `Assoc [
            "name", `String "Charlie"
          ]
        ]
      ]
    ])
  );
  ("both skip and include directives, field is queried", `Quick, fun () ->
    let query = "{ users { name role @skip(if: false) @include(if: true) } }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "users", `List [
          `Assoc [
            "name", `String "Alice";
            "role", `String "admin"
          ];
          `Assoc [
            "name", `String "Bob";
            "role", `String "user"
          ];
          `Assoc [
            "name", `String "Charlie";
            "role", `String "user"
          ]
        ]
      ]
    ])
  );
  ("wrong type for argument", `Quick, fun () ->
    let query = "{ users { name role @skip(if: 42) } }" in
    test_query query (`Assoc [
      "errors", `List [
        `Assoc [ "message", `String "Argument `if` of type `Boolean` expected on directive `skip`, found 42." ]
      ];
      "data", `Null;
    ])
  );
  (* http://facebook.github.io/graphql/June2018/#example-77377 *)
  ("directives + inline fragment", `Quick, fun () ->
    let query = "{ users { name ... @include(if: false) { id }  } }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "users", `List [
          `Assoc [
            "name", `String "Alice"
          ];
          `Assoc [
            "name", `String "Bob"
          ];
          `Assoc [
            "name", `String "Charlie"
          ]
        ]
      ]
    ])
  )
]

