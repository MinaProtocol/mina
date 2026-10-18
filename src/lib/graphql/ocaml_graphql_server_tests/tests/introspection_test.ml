open Graphql
module Schema = Graphql_wrapper.Make (Schema)

let test_query schema query = Test_common.test_query schema () query

let schema_not_deprecated_test () =
  let schema =
    Schema.(
      schema
        [ field "not-deprecated" ~deprecated:NotDeprecated ~typ:string
            ~args:Arg.[]
            ~resolve:(fun _ _ -> Some "")
        ])
  in
  let query =
    "{ __schema { queryType { fields { isDeprecated deprecationReason } } } }"
  in
  test_query schema query
    (`Assoc
      [ ( "data"
        , `Assoc
            [ ( "__schema"
              , `Assoc
                  [ ( "queryType"
                    , `Assoc
                        [ ( "fields"
                          , `List
                              [ `Assoc
                                  [ ("isDeprecated", `Bool false)
                                  ; ("deprecationReason", `Null)
                                  ]
                              ] )
                        ] )
                  ] )
            ] )
      ] )

let schema_default_deprecation_test () =
  let schema =
    Schema.(
      schema
        [ field "default" ~typ:string ~args:Arg.[] ~resolve:(fun _ _ -> Some "")
        ])
  in
  let query =
    "{ __schema { queryType { fields { isDeprecated deprecationReason } } } }"
  in
  test_query schema query
    (`Assoc
      [ ( "data"
        , `Assoc
            [ ( "__schema"
              , `Assoc
                  [ ( "queryType"
                    , `Assoc
                        [ ( "fields"
                          , `List
                              [ `Assoc
                                  [ ("isDeprecated", `Bool false)
                                  ; ("deprecationReason", `Null)
                                  ]
                              ] )
                        ] )
                  ] )
            ] )
      ] )

let schema_deprecated_without_reason_test () =
  let schema =
    Schema.(
      schema
        [ field "deprecated-without-reason" ~deprecated:(Deprecated None)
            ~typ:string
            ~args:Arg.[]
            ~resolve:(fun _ _ -> Some "")
        ])
  in
  let query =
    "{ __schema { queryType { fields { isDeprecated deprecationReason } } } }"
  in
  test_query schema query
    (`Assoc
      [ ( "data"
        , `Assoc
            [ ( "__schema"
              , `Assoc
                  [ ( "queryType"
                    , `Assoc
                        [ ( "fields"
                          , `List
                              [ `Assoc
                                  [ ("isDeprecated", `Bool true)
                                  ; ("deprecationReason", `Null)
                                  ]
                              ] )
                        ] )
                  ] )
            ] )
      ] )

let schema_deprecated_with_reason_test () =
  let schema =
    Schema.(
      schema
        [ field "deprecated-with-reason"
            ~deprecated:(Deprecated (Some "deprecation reason")) ~typ:string
            ~args:Arg.[]
            ~resolve:(fun _ _ -> Some "")
        ])
  in
  let query =
    "{ __schema { queryType { fields { isDeprecated deprecationReason } } } }"
  in
  test_query schema query
    (`Assoc
      [ ( "data"
        , `Assoc
            [ ( "__schema"
              , `Assoc
                  [ ( "queryType"
                    , `Assoc
                        [ ( "fields"
                          , `List
                              [ `Assoc
                                  [ ("isDeprecated", `Bool true)
                                  ; ( "deprecationReason"
                                    , `String "deprecation reason" )
                                  ]
                              ] )
                        ] )
                  ] )
            ] )
      ] )

let schema_deduplicates_argument_types_test () =
  let schema =
    Schema.(
      schema
        [ field "sum" ~typ:(non_null int)
            ~args:
              Arg.[ arg "x" ~typ:(non_null int); arg "y" ~typ:(non_null int) ]
            ~resolve:(fun _ _ x y -> x + y)
        ])
  in
  let query = "{ __schema { types { name } } }" in
  test_query schema query
    (`Assoc
      [ ( "data"
        , `Assoc
            [ ( "__schema"
              , `Assoc
                  [ ( "types"
                    , `List
                        [ `Assoc [ ("name", `String "Int") ]
                        ; `Assoc [ ("name", `String "query") ]
                        ] )
                  ] )
            ] )
      ] )

let type_test () =
  let query =
    {|
        {
          role_type: __type(name: "role") {
            name
          }
          user_type: __type(name: "user") {
            name
          }
        }
      |}
  in
  test_query Test_schema.schema query
    (`Assoc
      [ ( "data"
        , `Assoc
            [ ("role_type", `Assoc [ ("name", `String "role") ])
            ; ("user_type", `Assoc [ ("name", `String "user") ])
            ] )
      ] )

let () =
  Alcotest.run "GraphQL Introspection Tests"
    [ ( "introspection operations"
      , [ Alcotest.test_case "__schema: not deprecated" `Quick
            schema_not_deprecated_test
        ; Alcotest.test_case "__schema: default deprecation" `Quick
            schema_default_deprecation_test
        ; Alcotest.test_case "__schema: deprecated-without-reason" `Quick
            schema_deprecated_without_reason_test
        ; Alcotest.test_case "__schema: deprecated with reason" `Quick
            schema_deprecated_with_reason_test
        ; Alcotest.test_case "__schema: deduplicates argument types" `Quick
            schema_deduplicates_argument_types_test
        ; Alcotest.test_case "__type" `Quick type_test
        ] )
    ]
