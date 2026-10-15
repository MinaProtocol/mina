open Core

module Field = struct
  type t = Int of int | Float of float | String of string | Bool of bool
end

type t =
  { measurement : string
  ; tags : (string * string) list
  ; fields : (string * Field.t) list
  ; timestamp : Time_ns.t
  }

let create ?(timestamp = Time_ns.now ()) ?(tags = []) ~measurement fields =
  { measurement; tags; fields; timestamp }

let escape ~chars s =
  let buf = Buffer.create (String.length s) in
  String.iter s ~f:(fun c ->
      if List.mem chars c ~equal:Char.equal then Buffer.add_char buf '\\' ;
      Buffer.add_char buf c ) ;
  Buffer.contents buf

(* measurement: commas and spaces; tag keys, tag values and field keys: also
   equals signs; string field values: double quotes and backslashes *)
let escape_measurement = escape ~chars:[ ','; ' ' ]

let escape_key = escape ~chars:[ ','; '='; ' ' ]

let field_value : Field.t -> string option = function
  | Int i ->
      Some (sprintf "%di" i)
  | Float f when Float.is_finite f ->
      Some (sprintf "%.15g" f)
  | Float _ ->
      None
  | String s ->
      Some (sprintf "\"%s\"" (escape ~chars:[ '"'; '\\' ] s))
  | Bool b ->
      Some (Bool.to_string b)

let to_line { measurement; tags; fields; timestamp } =
  let tags =
    List.filter_map tags ~f:(fun (key, value) ->
        if String.is_empty value then None
        else Some (sprintf ",%s=%s" (escape_key key) (escape_key value)) )
  in
  let fields =
    List.filter_map fields ~f:(fun (key, value) ->
        Option.map (field_value value) ~f:(sprintf "%s=%s" (escape_key key)) )
  in
  if List.is_empty fields then
    failwithf "InfluxDB point %s has no field to write" measurement () ;
  sprintf "%s%s %s %d"
    (escape_measurement measurement)
    (String.concat tags)
    (String.concat ~sep:"," fields)
    (Time_ns.to_int_ns_since_epoch timestamp)

let write_file path points =
  Out_channel.write_lines path (List.map points ~f:to_line)
