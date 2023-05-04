open Core_kernel

module Annotations = struct
  module Utils = struct
    let find xs key =
      List.find ~f:(fun (k', _) -> String.equal key k') xs |> Option.map ~f:snd

    let find_string xs key =
      find xs key |> Option.join |> Option.map ~f:(fun s -> String.strip s)

    let find_bool xs key =
      find xs key
      |> Option.map ~f:(fun _ -> true)
      |> Option.value ~default:false
  end

  module Top = struct
    (** Top comment *)
    type t = { name : string; doc : string option }
    [@@deriving annot, sexp, compare, equal]

    open Utils

    let of_annots ~name t_toplevel_annots =
      let xs = t_toplevel_annots () in
      { name; doc = find_string xs "ocaml.doc" }

    let%test_unit "top annots parse" =
      let t = of_annots ~name:"Top" t_toplevel_annots in
      [%test_eq: t] t { name = "Top"; doc = Some "Top comment" }
  end

  module Fields = struct
    module T = struct
      type t =
        { name : string option
        ; doc : string option [@name "document"]
        ; skip : bool [@skip]
        ; deprecated : string option [@depr "foo"]  (** this is deprecated *)
        }
      [@@deriving annot, sexp, compare, equal]
    end

    type t = string -> T.t

    open Utils

    let of_annots t_fields_annots field =
      let xs = t_fields_annots field in
      let s = find_string xs in
      let b = find_bool xs in
      { T.name = s "name"
      ; doc = s "ocaml.doc"
      ; skip = b "skip"
      ; deprecated = s "depr"
      }

    let%test_unit "field annots parse" =
      let annots = of_annots T.t_fields_annots in
      [%test_eq: T.t] (annots "doc")
        { name = Some "document"; doc = None; skip = false; deprecated = None } ;
      [%test_eq: T.t] (annots "skip")
        { name = None; doc = None; skip = true; deprecated = None } ;
      [%test_eq: T.t] (annots "deprecated")
        { name = None
        ; doc = Some "this is deprecated"
        ; skip = false
        ; deprecated = Some "foo"
        }
  end
end

(** Rewrites underscore_case to camelCase. Note: Keeps leading underscores. *)
let under_to_camel s =
  (* take all the underscores *)
  let prefix_us =
    String.take_while s ~f:(function '_' -> true | _ -> false)
  in
  (* remove them from the original *)
  let rest = String.substr_replace_first ~pattern:prefix_us ~with_:"" s in
  let ws = String.split rest ~on:'_' in
  let result =
    match ws with
    | [] ->
        ""
    | w :: ws ->
        (* capitalize each word separated by underscores *)
        w :: (ws |> List.map ~f:String.capitalize) |> String.concat ?sep:None
  in
  (* add the leading underscoes back *)
  String.concat [ prefix_us; result ]

let%test_unit "under_to_camel works as expected" =
  let open Core_kernel in
  [%test_eq: string] "fooHello" (under_to_camel "foo_hello") ;
  [%test_eq: string] "fooHello" (under_to_camel "foo_hello___") ;
  [%test_eq: string] "_fooHello" (under_to_camel "_foo_hello__")

(** Like Field.name but rewrites underscore_case to camelCase. *)
let name_under_to_camel f = Fieldslib.Field.name f |> under_to_camel

let introspection_query_raw =
  {graphql|
  query IntrospectionQuery {
    __schema {
      queryType { name }
      mutationType { name }
      subscriptionType { name }
      types {
        ...FullType
      }
      directives {
        name
        description
        locations
        args {
          ...InputValue
        }
      }
    }
  }
  fragment FullType on __Type {
    kind
    name
    description
    fields(includeDeprecated: true) {
      name
      description
      args {
        ...InputValue
      }
      type {
        ...TypeRef
      }
      isDeprecated
      deprecationReason
    }
    inputFields {
      ...InputValue
    }
    interfaces {
      ...TypeRef
    }
    enumValues(includeDeprecated: true) {
      name
      description
      isDeprecated
      deprecationReason
    }
    possibleTypes {
      ...TypeRef
    }
  }
  fragment InputValue on __InputValue {
    name
    description
    type { ...TypeRef }
    defaultValue
  }
  fragment TypeRef on __Type {
    kind
    name
    ofType {
      kind
      name
      ofType {
        kind
        name
        ofType {
          kind
          name
          ofType {
            kind
            name
            ofType {
              kind
              name
              ofType {
                kind
                name
                ofType {
                  kind
                  name
                }
              }
            }
          }
        }
      }
    }
  }
  |graphql}
