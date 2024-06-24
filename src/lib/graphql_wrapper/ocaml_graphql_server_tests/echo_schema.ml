open Graphql
module Schema = Graphql_wrapper.Make (Schema)

let echo : 'a. unit Schema.resolve_info -> unit -> 'a -> 'a = fun _ _ x -> x

let echo_field name field_typ arg_typ =
  Schema.(
    field name ~typ:field_typ ~args:Arg.[ arg "x" ~typ:arg_typ ] ~resolve:echo)

type colors = Red | Green | Blue

let color_enum_values =
  Schema.
    [ enum_value "RED" ~value:Red
    ; enum_value "GREEN" ~value:Green
    ; enum_value "BLUE" ~value:Blue
    ]

let color_enum = Schema.enum "color" ~values:color_enum_values

let color_enum_arg = Schema.Arg.enum "color" ~values:color_enum_values

let person_arg =
  Schema.Arg.(
    obj "person"
      ~fields:
        [ arg "title" ~typ:string
        ; arg "first_name" ~typ:(non_null string)
        ; arg "last_name" ~typ:(non_null string)
        ]
      ~coerce:(fun title first last -> (title, first, last))
      ~split:(fun f (title, first, last) -> f title first last))

let schema =
  Schema.(
    schema
      [ echo_field "string" string Arg.string
      ; echo_field "float" float Arg.float
      ; echo_field "int" int Arg.int
      ; echo_field "bool" bool Arg.bool
      ; echo_field "enum" color_enum color_enum_arg
      ; echo_field "id" guid Arg.guid
      ; echo_field "bool_list" (list bool) Arg.(list bool)
      ; field "input_obj" ~typ:(non_null string)
          ~args:Arg.[ arg "x" ~typ:(non_null person_arg) ]
          ~resolve:(fun _ () (_, first, last) -> first ^ " " ^ last)
      ; field "sum_defaults" ~typ:int
          ~args:
            Arg.
              [ arg' "x" ~typ:string ~default:"42"
              ; arg' "y" ~typ:int ~default:3
              ]
          ~resolve:(fun _ () x y ->
            try Some (int_of_string x + y) with _ -> None )
      ])
