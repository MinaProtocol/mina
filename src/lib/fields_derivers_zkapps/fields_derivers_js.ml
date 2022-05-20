open Core_kernel
open Fieldslib

module Js_layout = struct
  module Input = struct
    type 'a t =
      < js_layout : [> `Assoc of (string * Yojson.Safe.t) list ] ref ; .. >
      as
      'a
  end

  module Accumulator = struct
    type field = { key : string; value : Yojson.Safe.t; docs : Yojson.Safe.t }

    let to_yojson ({ key; value; docs } : field) : Yojson.Safe.t =
      `Assoc [ ("key", `String key); ("value", value); ("docs", docs) ]

    type 'a t = < js_layout_accumulator : field option list ref ; .. > as 'a
      constraint 'a t = 'a Input.t
  end

  let docs (s : Fields_derivers.Annotations.Fields.T.t) : Yojson.Safe.t =
    match s.doc with Some t -> `String t | None -> `Null

  let add_field ~t_fields_annots t_field field (acc : _ Accumulator.t) :
      _ * _ Accumulator.t =
    let annotations =
      Fields_derivers.Annotations.Fields.of_annots t_fields_annots
        (Field.name field)
    in
    let rest = !(acc#js_layout_accumulator) in
    let key =
      Option.value annotations.name
        ~default:(Fields_derivers.name_under_to_camel field)
    in
    let value = !(t_field#js_layout) in
    let new_field =
      if annotations.skip || !(t_field#skip) then None
      else Some Accumulator.{ key; value; docs = docs annotations }
    in
    acc#js_layout_accumulator := new_field :: rest ;
    ((fun _ -> failwith "Unused"), acc)

  let finish name ~t_toplevel_annots (_creator, obj) =
    let annotations =
      Fields_derivers.Annotations.Top.of_annots ~name t_toplevel_annots
    in
    let js_layout_accumulator = !(obj#js_layout_accumulator) in
    obj#js_layout :=
      `Assoc
        [ ("type", `String "object")
        ; ("name", `String annotations.name)
        ; ( "docs"
          , match annotations.doc with Some s -> `String s | None -> `Null )
        ; ( "layout"
          , `List
              ( List.filter_map js_layout_accumulator
                  ~f:(Option.map ~f:Accumulator.to_yojson)
              |> List.rev ) )
        ] ;
    obj

  type leaf_type =
    | String
    | Number
    | Null
    | Field
    | Bool
    | UInt32
    | UInt64
    | PublicKey
    | Custom of string

  let leaf_type_to_string = function
    | String ->
        "string"
    | Number ->
        "number"
    | Null ->
        "null"
    | Field ->
        "Field"
    | Bool ->
        "Bool"
    | UInt32 ->
        "UInt32"
    | UInt64 ->
        "UInt64"
    | PublicKey ->
        "PublicKey"
    | Custom s ->
        s

  let leaf_type (s : leaf_type) =
    `Assoc [ ("type", `String (leaf_type_to_string s)) ]

  let skip obj =
    obj#skip := true ;
    obj#js_layout := leaf_type Null ;
    obj

  let int obj =
    obj#js_layout := leaf_type Number ;
    obj

  let string obj =
    obj#js_layout := leaf_type String ;
    obj

  let bool obj =
    obj#js_layout := leaf_type Bool ;
    obj

  let list x obj : _ Input.t =
    let inner = !(x#js_layout) in
    obj#js_layout := `Assoc [ ("type", `String "array"); ("inner", inner) ] ;
    obj

  let option x obj ~(js_type : [ `Implicit | `Flagged_option | `Or_undefined ])
      : _ Input.t =
    let inner = !(x#js_layout) in
    let js_type =
      match js_type with
      | `Implicit ->
          "implicit"
      | `Flagged_option ->
          "flaggedOption"
      | `Or_undefined ->
          "orUndefined"
    in
    obj#js_layout :=
      `Assoc
        [ ("type", `String "option")
        ; ("optionType", `String js_type)
        ; ("inner", inner)
        ] ;
    obj

  let wrapped x obj =
    obj#js_layout := !(x#js_layout) ;
    obj

  let with_checked ~name (x : _ Input.t) (obj : _ Input.t) =
    match !(obj#js_layout) with
    | `Assoc layout ->
        obj#js_layout :=
          `Assoc
            ( layout
            @ [ ("checkedType", !(x#js_layout))
              ; ("checkedTypeName", `String name)
              ] ) ;
        obj
    | _ ->
        failwith "impossible"
end
