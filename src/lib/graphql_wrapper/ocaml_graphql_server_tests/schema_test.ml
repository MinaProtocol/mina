let test_query = Test_common.test_query Test_schema.schema ()

let query_test () =
  let query = "{ users { id } }" in
  test_query query
    (`Assoc
      [ ( "data"
        , `Assoc
            [ ( "users"
              , `List [ `Assoc [ ("id", `Int 1) ]; `Assoc [ ("id", `Int 2) ] ]
              )
            ] )
      ] )

let mutation_test () =
  let query =
    "mutation { add_user(name: \"Charlie\", role: \"user\") { name } }"
  in
  test_query query
    (`Assoc
      [ ( "data"
        , `Assoc
            [ ( "add_user"
              , `List
                  [ `Assoc [ ("name", `String "Alice") ]
                  ; `Assoc [ ("name", `String "Bob") ]
                  ; `Assoc [ ("name", `String "Charlie") ]
                  ] )
            ] )
      ] )

let typename_test () =
  let query = "{ __typename }" in
  test_query query
    (`Assoc [ ("data", `Assoc [ ("__typename", `String "query") ]) ])

let select_operation_no_operations_test () =
  let query = "fragment x on y { z }" in
  test_query query
    (`Assoc
      [ ( "errors"
        , `List [ `Assoc [ ("message", `String "No operation found") ] ] )
      ] )

let select_operation_one_operation_no_operation_name_test () =
  let query = "query a { a: __typename }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("a", `String "query") ]) ])

let select_operation_one_operation_matching_operation_name_test () =
  let query = "query a { a: __typename }" in
  test_query query ~operation_name:"a"
    (`Assoc [ ("data", `Assoc [ ("a", `String "query") ]) ])

let select_operation_one_operation_missing_operation_name_test () =
  let query = "query a { a: __typename }" in
  test_query query ~operation_name:"b"
    (`Assoc
      [ ( "errors"
        , `List [ `Assoc [ ("message", `String "Operation not found") ] ] )
      ] )

let select_operation_multiple_operations_no_operation_name_test () =
  let query = "query a { a: __typename } query b { b: __typename }" in
  test_query query
    (`Assoc
      [ ( "errors"
        , `List [ `Assoc [ ("message", `String "Operation name required") ] ] )
      ] )

let select_operation_multiple_operations_matching_operation_name_test () =
  let query = "query a { a: __typename } query b { b: __typename }" in
  test_query query ~operation_name:"b"
    (`Assoc [ ("data", `Assoc [ ("b", `String "query") ]) ])

let select_operation_multiple_operations_missing_operation_name_test () =
  let query = "query a { a: __typename } query b { b: __typename }" in
  test_query query ~operation_name:"c"
    (`Assoc
      [ ( "errors"
        , `List [ `Assoc [ ("message", `String "Operation not found") ] ] )
      ] )

let undefined_field_on_query_root_test () =
  let query = "{ foo { bar } }" in
  test_query query
    (`Assoc
      [ ( "errors"
        , `List
            [ `Assoc
                [ ( "message"
                  , `String "Field 'foo' is not defined on type 'query'" )
                ]
            ] )
      ] )

let undefined_field_on_object_type_test () =
  let query = "{ users { id foo } }" in
  test_query query
    (`Assoc
      [ ( "errors"
        , `List
            [ `Assoc
                [ ( "message"
                  , `String "Field 'foo' is not defined on type 'user'" )
                ]
            ] )
      ] )

let fragments_cannot_form_cycles_test () =
  let query =
    "\n\
    \      fragment F1 on Foo {\n\
    \        ... on Bar {\n\
    \          baz {\n\
    \            ... F2\n\
    \          }\n\
    \        }\n\
    \      }\n\n\
    \      fragment F2 on Qux {\n\
    \        ... F1\n\
    \      }\n\n\
    \      {\n\
    \        ... F1\n\
    \      }\n\
    \    "
  in
  test_query query
    (`Assoc
      [ ( "errors"
        , `List
            [ `Assoc [ ("message", `String "Fragment cycle detected: F1, F2") ]
            ] )
      ] )

let fragments_combine_nested_fields_test () =
  let query =
    "\n\
    \      query Q {\n\
    \        users {\n\
    \          role\n\
    \        }\n\
    \        ...F1\n\
    \      }\n\
    \      fragment F1 on query {\n\
    \        users {\n\
    \          name\n\
    \        }\n\
    \      }\n\
    \    "
  in
  test_query query
    (`Assoc
      [ ( "data"
        , `Assoc
            [ ( "users"
              , `List
                  [ `Assoc
                      [ ("role", `String "admin"); ("name", `String "Alice") ]
                  ; `Assoc [ ("role", `String "user"); ("name", `String "Bob") ]
                  ; `Assoc
                      [ ("role", `String "user"); ("name", `String "Charlie") ]
                  ] )
            ] )
      ] )

let introspection_query_test () =
  let query =
    "\n\
    \      query IntrospectionQuery {\n\
    \        __schema {\n\
    \          queryType { name }\n\
    \          mutationType { name }\n\
    \          subscriptionType { name }\n\
    \          types {\n\
    \            ...FullType\n\
    \          }\n\
    \          directives {\n\
    \            name\n\
    \            description\n\
    \            locations\n\
    \            args {\n\
    \              ...InputValue\n\
    \            }\n\
    \          }\n\
    \        }\n\
    \      }\n\n\
    \      fragment FullType on __Type {\n\
    \        kind\n\
    \        name\n\
    \        description\n\
    \        fields(includeDeprecated: true) {\n\
    \          name\n\
    \          description\n\
    \          args {\n\
    \            ...InputValue\n\
    \          }\n\
    \          type {\n\
    \            ...TypeRef\n\
    \          }\n\
    \          isDeprecated\n\
    \          deprecationReason\n\
    \        }\n\
    \        inputFields {\n\
    \          ...InputValue\n\
    \        }\n\
    \        interfaces {\n\
    \          ...TypeRef\n\
    \        }\n\
    \        enumValues(includeDeprecated: true) {\n\
    \          name\n\
    \          description\n\
    \          isDeprecated\n\
    \          deprecationReason\n\
    \        }\n\
    \        possibleTypes {\n\
    \          ...TypeRef\n\
    \        }\n\
    \      }\n\n\
    \      fragment InputValue on __InputValue {\n\
    \        name\n\
    \        description\n\
    \        type { ...TypeRef }\n\
    \        defaultValue\n\
    \      }\n\n\
    \      fragment TypeRef on __Type {\n\
    \        kind\n\
    \        name\n\
    \        ofType {\n\
    \          kind\n\
    \          name\n\
    \          ofType {\n\
    \            kind\n\
    \            name\n\
    \            ofType {\n\
    \              kind\n\
    \              name\n\
    \              ofType {\n\
    \                kind\n\
    \                name\n\
    \                ofType {\n\
    \                  kind\n\
    \                  name\n\
    \                  ofType {\n\
    \                    kind\n\
    \                    name\n\
    \                    ofType {\n\
    \                      kind\n\
    \                      name\n\
    \                    }\n\
    \                  }\n\
    \                }\n\
    \              }\n\
    \            }\n\
    \          }\n\
    \        }\n\
    \      }\n\
    \    "
  in
  match Graphql_parser.parse query with
  | Error err ->
      Alcotest.fail err
  | Ok doc -> (
      match Graphql.Schema.execute Test_schema.schema () doc with
      | Ok _ ->
          ()
      | Error err ->
          Alcotest.fail (Yojson.Basic.pretty_to_string err) )

let subscription_test () =
  let query = "subscription { subscribe_to_user { id name } }" in
  test_query query
    (`List
      [ `Assoc
          [ ( "data"
            , `Assoc
                [ ( "subscribe_to_user"
                  , `Assoc [ ("id", `Int 1); ("name", `String "Alice") ] )
                ] )
          ]
      ] )

let subscription_returns_an_error_test () =
  let query = "subscription { subscribe_to_user(error: true) { id name } }" in
  test_query query
    (`Assoc
      [ ( "errors"
        , `List
            [ `Assoc
                [ ("message", `String "stream error")
                ; ("path", `List [ `String "subscribe_to_user" ])
                ]
            ] )
      ; ("data", `Null)
      ] )

let subscriptions_exn_inside_the_stream_test () =
  let query = "subscription { subscribe_to_user(raise: true) { id name } }" in
  test_query query (`String "caught stream exn")

let subscription_returns_more_than_one_value_test () =
  let query = "subscription { subscribe_to_user(first: 2) { id name } }" in
  test_query query
    (`List
      [ `Assoc
          [ ( "data"
            , `Assoc
                [ ( "subscribe_to_user"
                  , `Assoc [ ("id", `Int 1); ("name", `String "Alice") ] )
                ] )
          ]
      ; `Assoc
          [ ( "data"
            , `Assoc
                [ ( "subscribe_to_user"
                  , `Assoc [ ("id", `Int 2); ("name", `String "Bob") ] )
                ] )
          ]
      ] )

(* Run tests *)
let () =
  Alcotest.run "GraphQL Schema Tests"
    [ ( "schema operations"
      , [ Alcotest.test_case "query" `Quick query_test
        ; Alcotest.test_case "mutation" `Quick mutation_test
        ; Alcotest.test_case "__typename" `Quick typename_test
        ; Alcotest.test_case "select operation (no operations)" `Quick
            select_operation_no_operations_test
        ; Alcotest.test_case
            "select operation (one operation, no operation name)" `Quick
            select_operation_one_operation_no_operation_name_test
        ; Alcotest.test_case
            "select operation (one operation, matching operation name)" `Quick
            select_operation_one_operation_matching_operation_name_test
        ; Alcotest.test_case
            "select operation (one operation, missing operation name)" `Quick
            select_operation_one_operation_missing_operation_name_test
        ; Alcotest.test_case
            "select operation (multiple operations, no operation name)" `Quick
            select_operation_multiple_operations_no_operation_name_test
        ; Alcotest.test_case
            "select operation (multiple operations, matching operation name)"
            `Quick
            select_operation_multiple_operations_matching_operation_name_test
        ; Alcotest.test_case
            "select operation (multiple operations, missing operation name)"
            `Quick
            select_operation_multiple_operations_missing_operation_name_test
        ; Alcotest.test_case "undefined field on query root" `Quick
            undefined_field_on_query_root_test
        ; Alcotest.test_case "undefined field on object type" `Quick
            undefined_field_on_object_type_test
        ; Alcotest.test_case "fragments cannot form cycles" `Quick
            fragments_cannot_form_cycles_test
        ; Alcotest.test_case "fragments combine nested fields" `Quick
            fragments_combine_nested_fields_test
        ; Alcotest.test_case "introspection query should be accepted" `Quick
            introspection_query_test
        ; Alcotest.test_case "subscription" `Quick subscription_test
        ; Alcotest.test_case "subscription returns an error" `Quick
            subscription_returns_an_error_test
        ; Alcotest.test_case "subscriptions: exn inside the stream" `Quick
            subscriptions_exn_inside_the_stream_test
        ; Alcotest.test_case "subscription returns more than one value" `Quick
            subscription_returns_more_than_one_value_test
        ] )
    ]
