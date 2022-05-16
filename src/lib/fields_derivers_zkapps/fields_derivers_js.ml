open Core_kernel
open Fieldslib

module Js_layout = struct
  module Input = struct
    type 'a t = < js_layout : Yojson.Safe.t ref ; .. > as 'a
  end

  module Accumulator = struct
    type field = { key : string; value : Yojson.Safe.t; docs : Yojson.Safe.t }

    let to_yojson ({ key; value; docs } : field) : Yojson.Safe.t =
      `Assoc [ ("key", `String key); ("value", value); ("docs", docs) ]

    type 'a t = < js_layout_accumulator : field option list ref ; .. > as 'a
      constraint 'a t = 'a Input.t
  end

  let leaftype (s : string) : Yojson.Safe.t = `Assoc [ ("type", `String s) ]

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

  let skip obj =
    obj#skip := true ;
    obj#js_layout := leaftype "null" ;
    obj

  let int obj =
    obj#js_layout := leaftype "number" ;
    obj

  let string obj =
    obj#js_layout := leaftype "string" ;
    obj

  let bool obj =
    obj#js_layout := leaftype "Bool" ;
    obj

  let list x obj : _ Input.t =
    let inner = !(x#js_layout) in
    obj#js_layout := `Assoc [ ("type", `String "array"); ("inner", inner) ] ;
    obj

  let option x obj : _ Input.t =
    let inner = !(x#js_layout) in
    (* print_endline ("option: " ^ (inner |> Yojson.Safe.to_string)) ; *)
    obj#js_layout :=
      `Assoc [ ("type", `String "orundefined"); ("inner", inner) ] ;
    obj

  let wrapped x obj =
    obj#js_layout := !(x#js_layout) ;
    obj
end
