let test_query = Test_common.test_query Test_schema.schema ()

let%test_unit "query" =
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

let%test_unit "mutation" =
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

let%test_unit "__typename" =
  let query = "{ __typename }" in
  test_query query
    (`Assoc [ ("data", `Assoc [ ("__typename", `String "query") ]) ])

let%test_unit "select operation (no operations)" =
  let query = "fragment x on y { z }" in
  test_query query
    (`Assoc
      [ ( "errors"
        , `List [ `Assoc [ ("message", `String "No operation found") ] ] )
      ] )

let%test_unit "select operation (one operation, no operation name)" =
  let query = "query a { a: __typename }" in
  test_query query (`Assoc [ ("data", `Assoc [ ("a", `String "query") ]) ])

let%test_unit "select operation (one operation, matching operation name)" =
  let query = "query a { a: __typename }" in
  test_query query ~operation_name:"a"
    (`Assoc [ ("data", `Assoc [ ("a", `String "query") ]) ])

let%test_unit "select operation (one operation, missing operation name)" =
  let query = "query a { a: __typename }" in
  test_query query ~operation_name:"b"
    (`Assoc
      [ ( "errors"
        , `List [ `Assoc [ ("message", `String "Operation not found") ] ] )
      ] )

let%test_unit "select operation (multiple operations, no operation name)" =
  let query = "query a { a: __typename } query b { b: __typename }" in
  test_query query
    (`Assoc
      [ ( "errors"
        , `List [ `Assoc [ ("message", `String "Operation name required") ] ] )
      ] )

let%test_unit "select operation (multiple operations, matching operation name)"
    =
  let query = "query a { a: __typename } query b { b: __typename }" in
  test_query query ~operation_name:"b"
    (`Assoc [ ("data", `Assoc [ ("b", `String "query") ]) ])

let%test_unit "select operation (multiple operations, missing operation name)" =
  let query = "query a { a: __typename } query b { b: __typename }" in
  test_query query ~operation_name:"c"
    (`Assoc
      [ ( "errors"
        , `List [ `Assoc [ ("message", `String "Operation not found") ] ] )
      ] )

let%test_unit "undefined field on query root" =
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

let%test_unit "undefined field on object type" =
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

let%test_unit "fragments cannot form cycles" =
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

let%test_unit "fragments combine nested fields" =
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

let%test "introspection query should be accepted" =
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
      failwith err
  | Ok doc -> (
      match Graphql.Schema.execute Test_schema.schema () doc with
      | Ok _ ->
          true
      | Error err ->
          failwith (Yojson.Basic.pretty_to_string err) )

let%test_unit "subscription" =
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

let%test_unit "subscription returns an error" =
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

let%test_unit "subscriptions: exn inside the stream" =
  let query = "subscription { subscribe_to_user(raise: true) { id name } }" in
  test_query query (`String "caught stream exn")

let%test_unit "subscription returns more than one value" =
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
