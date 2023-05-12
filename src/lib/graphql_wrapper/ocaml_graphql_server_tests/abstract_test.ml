open Graphql
module Schema = Graphql_wrapper.Make (Schema)

type cat = { name : string; kittens : int }

type dog = { name : string; puppies : int }

let meow : cat = { name = "Meow"; kittens = 1 }

let fido : dog = { name = "Fido"; puppies = 2 }

let cat =
  Schema.(
    obj "Cat" ~fields:(fun _ ->
        [ field "name" ~typ:(non_null string)
            ~args:Arg.[]
            ~resolve:(fun _ (cat : cat) -> cat.name)
        ; field "kittens" ~typ:(non_null int)
            ~args:Arg.[]
            ~resolve:(fun _ (cat : cat) -> cat.kittens)
        ] ))

let dog =
  Schema.(
    obj "Dog" ~fields:(fun _ ->
        [ field "name" ~typ:(non_null string)
            ~args:Arg.[]
            ~resolve:(fun _ (dog : dog) -> dog.name)
        ; field "puppies" ~typ:(non_null int)
            ~args:Arg.[]
            ~resolve:(fun _ (dog : dog) -> dog.puppies)
        ] ))

let pet : (unit, [ `pet ]) Schema.abstract_typ = Schema.union "Pet"

let cat_as_pet = Schema.add_type pet cat

let dog_as_pet = Schema.add_type pet dog

let named : (unit, [ `named ]) Schema.abstract_typ =
  Schema.(
    interface "Named" ~fields:(fun _ ->
        [ abstract_field "name" ~typ:(non_null string) ~args:Arg.[] ] ))

let cat_as_named = Schema.add_type named cat

let dog_as_named = Schema.add_type named dog

let pet_type =
  Schema.(
    Arg.enum "pet_type"
      ~values:[ enum_value "CAT" ~value:`Cat; enum_value "DOG" ~value:`Dog ])

let schema =
  Schema.(
    schema
      [ field "pet" ~typ:(non_null pet)
          ~args:Arg.[ arg "type" ~typ:(non_null pet_type) ]
          ~resolve:(fun _ () pet_type ->
            match pet_type with
            | `Cat ->
                cat_as_pet meow
            | `Dog ->
                dog_as_pet fido )
      ; field "pets"
          ~typ:(non_null (list (non_null pet)))
          ~args:Arg.[]
          ~resolve:(fun _ () -> [ cat_as_pet meow; dog_as_pet fido ])
      ; field "named_objects"
          ~typ:(non_null (list (non_null named)))
          ~args:Arg.[]
          ~resolve:(fun _ () -> [ cat_as_named meow; dog_as_named fido ])
      ])

let test_query = Test_common.test_query schema ()

let%test_unit "dog as pet" =
  let query = "{ pet(type: \"DOG\") { ... on Dog { name puppies } } }" in
  test_query query
    (`Assoc
      [ ( "data"
        , `Assoc
            [ ("pet", `Assoc [ ("name", `String "Fido"); ("puppies", `Int 2) ])
            ] )
      ] )

let%test_unit "cat as pet" =
  let query = "{ pet(type: \"CAT\") { ... on Cat { name kittens } } }" in
  test_query query
    (`Assoc
      [ ( "data"
        , `Assoc
            [ ("pet", `Assoc [ ("name", `String "Meow"); ("kittens", `Int 1) ])
            ] )
      ] )

let%test_unit "pets" =
  let query =
    "{ pets { ... on Dog { name puppies } ... on Cat { name kittens } } }"
  in
  test_query query
    (`Assoc
      [ ( "data"
        , `Assoc
            [ ( "pets"
              , `List
                  [ `Assoc [ ("name", `String "Meow"); ("kittens", `Int 1) ]
                  ; `Assoc [ ("name", `String "Fido"); ("puppies", `Int 2) ]
                  ] )
            ] )
      ] )

let%test_unit "named_objects" =
  let query =
    "{ named_objects { name ... on Dog { puppies } ... on Cat { kittens } } }"
  in
  test_query query
    (`Assoc
      [ ( "data"
        , `Assoc
            [ ( "named_objects"
              , `List
                  [ `Assoc [ ("name", `String "Meow"); ("kittens", `Int 1) ]
                  ; `Assoc [ ("name", `String "Fido"); ("puppies", `Int 2) ]
                  ] )
            ] )
      ] )

let%test_unit "nested fragments with union and interface" =
  let query =
    "fragment NamedFragment on Named { ... on Dog { name } ... on Cat { name } \
     } fragment PetFragment on Pet { ... NamedFragment ... on Dog { puppies } \
     ... on Cat { kittens } } { pets { ... PetFragment } }"
  in
  test_query query
    (`Assoc
      [ ( "data"
        , `Assoc
            [ ( "pets"
              , `List
                  [ `Assoc [ ("name", `String "Meow"); ("kittens", `Int 1) ]
                  ; `Assoc [ ("name", `String "Fido"); ("puppies", `Int 2) ]
                  ] )
            ] )
      ] )

let%test_unit "introspection" =
  let query =
    "{ __schema { types { name kind possibleTypes { name kind } interfaces { \
     name kind } } } }"
  in
  test_query query
    (`Assoc
      [ ( "data"
        , `Assoc
            [ ( "__schema"
              , `Assoc
                  [ ( "types"
                    , `List
                        [ `Assoc
                            [ ("name", `String "Named")
                            ; ("kind", `String "INTERFACE")
                            ; ( "possibleTypes"
                              , `List
                                  [ `Assoc
                                      [ ("name", `String "Dog")
                                      ; ("kind", `String "OBJECT")
                                      ]
                                  ; `Assoc
                                      [ ("name", `String "Cat")
                                      ; ("kind", `String "OBJECT")
                                      ]
                                  ] )
                            ; ("interfaces", `Null)
                            ]
                        ; `Assoc
                            [ ("name", `String "pet_type")
                            ; ("kind", `String "ENUM")
                            ; ("possibleTypes", `Null)
                            ; ("interfaces", `Null)
                            ]
                        ; `Assoc
                            [ ("name", `String "Cat")
                            ; ("kind", `String "OBJECT")
                            ; ("possibleTypes", `Null)
                            ; ( "interfaces"
                              , `List
                                  [ `Assoc
                                      [ ("name", `String "Named")
                                      ; ("kind", `String "INTERFACE")
                                      ]
                                  ] )
                            ]
                        ; `Assoc
                            [ ("name", `String "Int")
                            ; ("kind", `String "SCALAR")
                            ; ("possibleTypes", `Null)
                            ; ("interfaces", `Null)
                            ]
                        ; `Assoc
                            [ ("name", `String "String")
                            ; ("kind", `String "SCALAR")
                            ; ("possibleTypes", `Null)
                            ; ("interfaces", `Null)
                            ]
                        ; `Assoc
                            [ ("name", `String "Dog")
                            ; ("kind", `String "OBJECT")
                            ; ("possibleTypes", `Null)
                            ; ( "interfaces"
                              , `List
                                  [ `Assoc
                                      [ ("name", `String "Named")
                                      ; ("kind", `String "INTERFACE")
                                      ]
                                  ] )
                            ]
                        ; `Assoc
                            [ ("name", `String "Pet")
                            ; ("kind", `String "UNION")
                            ; ( "possibleTypes"
                              , `List
                                  [ `Assoc
                                      [ ("name", `String "Dog")
                                      ; ("kind", `String "OBJECT")
                                      ]
                                  ; `Assoc
                                      [ ("name", `String "Cat")
                                      ; ("kind", `String "OBJECT")
                                      ]
                                  ] )
                            ; ("interfaces", `Null)
                            ]
                        ; `Assoc
                            [ ("name", `String "query")
                            ; ("kind", `String "OBJECT")
                            ; ("possibleTypes", `Null)
                            ; ("interfaces", `List [])
                            ]
                        ] )
                  ] )
            ] )
      ] )
