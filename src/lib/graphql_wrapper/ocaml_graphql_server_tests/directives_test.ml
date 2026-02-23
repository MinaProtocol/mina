let test_query = Test_common.test_query Test_schema.schema ()

let skip_directive_test () =
  let query = "{ users { id @skip(if: true) name } }" in
  test_query query
    (`Assoc
      [ ( "data"
        , `Assoc
            [ ( "users"
              , `List
                  [ `Assoc [ ("name", `String "Alice") ]
                  ; `Assoc [ ("name", `String "Bob") ]
                  ] )
            ] )
      ] )

let include_directive_test () =
  let query = "{ users { id @include(if: false) name } }" in
  test_query query
    (`Assoc
      [ ( "data"
        , `Assoc
            [ ( "users"
              , `List
                  [ `Assoc [ ("name", `String "Alice") ]
                  ; `Assoc [ ("name", `String "Bob") ]
                  ] )
            ] )
      ] )

(*
 * Per the link below, the field "must be queried only if the @skip
 * condition is false and the @include condition is true".
 * http://facebook.github.io/graphql/June2018/#sec--include
 *)
let both_skip_and_include_directives_field_not_queried_test () =
  let query = "{ users { role @skip(if: true) @include(if: true) name } }" in
  test_query query
    (`Assoc
      [ ( "data"
        , `Assoc
            [ ( "users"
              , `List
                  [ `Assoc [ ("name", `String "Alice") ]
                  ; `Assoc [ ("name", `String "Bob") ]
                  ] )
            ] )
      ] )

let both_skip_and_include_directives_field_is_queried_test () =
  let query = "{ users { name role @skip(if: false) @include(if: true) } }" in
  test_query query
    (`Assoc
      [ ( "data"
        , `Assoc
            [ ( "users"
              , `List
                  [ `Assoc
                      [ ("name", `String "Alice"); ("role", `String "admin") ]
                  ; `Assoc [ ("name", `String "Bob"); ("role", `String "user") ]
                  ] )
            ] )
      ] )

let wrong_type_for_argument_test () =
  let query = "{ users { name role @skip(if: 42) } }" in
  test_query query
    (`Assoc
      [ ( "errors"
        , `List
            [ `Assoc
                [ ( "message"
                  , `String
                      "Argument `if` of type `Boolean` expected on directive \
                       `skip`, found 42." )
                ]
            ] )
      ; ("data", `Null)
      ] )

(* http://facebook.github.io/graphql/June2018/#example-77377 *)
let directives_and_inline_fragment_test () =
  let query = "{ users { name ... @include(if: false) { id }  } }" in
  test_query query
    (`Assoc
      [ ( "data"
        , `Assoc
            [ ( "users"
              , `List
                  [ `Assoc [ ("name", `String "Alice") ]
                  ; `Assoc [ ("name", `String "Bob") ]
                  ] )
            ] )
      ] )

(* Run tests *)
let () =
  Alcotest.run "GraphQL Directives Tests"
    [ ( "directive operations"
      , [ Alcotest.test_case "skip directive" `Quick skip_directive_test
        ; Alcotest.test_case "include directive" `Quick include_directive_test
        ; Alcotest.test_case
            "both skip and include directives, field not queried" `Quick
            both_skip_and_include_directives_field_not_queried_test
        ; Alcotest.test_case
            "both skip and include directives, field is queried" `Quick
            both_skip_and_include_directives_field_is_queried_test
        ; Alcotest.test_case "wrong type for argument" `Quick
            wrong_type_for_argument_test
        ; Alcotest.test_case "directives + inline fragment" `Quick
            directives_and_inline_fragment_test
        ] )
    ]
