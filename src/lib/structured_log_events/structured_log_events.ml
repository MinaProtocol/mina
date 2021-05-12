open Core_kernel

type t = ..

type id = string [@@deriving eq, yojson, sexp]

let id_of_string s = s

type repr =
  { id: id
  ; event_name: string
  ; arguments: String.Set.t
  ; log: t -> (string * (string * Yojson.Safe.t) list) option
  ; parse: (string * Yojson.Safe.t) list -> t option }

module Registry = struct
  let reprs : repr list ref = ref []

  let register_constructor repr = reprs := repr :: !reprs
end

let parse_exn id json_pairs =
  let result =
    List.find_map !Registry.reprs ~f:(fun repr ->
        if equal_id id repr.id then
          let json_pairs =
            (* Remove additional metadata that may have been added to the log
               message.
            *)
            List.filter json_pairs ~f:(fun (field_name, _) ->
                Set.mem repr.arguments field_name )
          in
          repr.parse json_pairs
        else None )
  in
  match result with
  | Some data ->
      data
  | None ->
      failwithf "parse_exn: did not find matching parser for id %s" id ()

let log t =
  let result =
    List.find_map !Registry.reprs ~f:(fun repr ->
        Option.map (repr.log t) ~f:(fun (msg, fields) -> (msg, repr.id, fields))
    )
  in
  match result with
  | Some data ->
      data
  | None ->
      (* NOTE: We suppress these warnings here, because the deprecation began
         in 4.08.0 but we still want to support 4.07.1.
      *)
      failwithf "log: did not find matching logger for %s"
        ((Obj.extension_name [@ocaml.warning "-3"]) ((Obj.extension_constructor [@ocaml.warning "-3"]) t))
        ()

let register_constructor = Registry.register_constructor

let dump_registered_events () =
  List.map !Registry.reprs ~f:(fun {event_name; id; arguments; _} ->
      (event_name, id, Set.to_list arguments) )
