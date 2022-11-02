open Graphql
module Schema = Graphql_wrapper.Make (Schema)

let test_query schema query = Test_common.test_query schema () query

let%test_unit "__schema: not deprecated" =
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

let%test_unit "__schema: default deprecation" =
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

let%test_unit "__schema: deprecated-without-reason" =
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

let%test_unit "__schema: deprecated with reason" =
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

let%test_unit "__schema: deduplicates argument types" =
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

let%test_unit "__type" =
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
