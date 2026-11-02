open Core

module Field = struct
  type t = Int of int | Float of float
end

type t =
  { measurement : string
  ; tags : (string * string) list
  ; fields : (string * Field.t) list
  ; timestamp : Time_ns.t
  }

let invalid fmt =
  ksprintf (fun msg -> invalid_arg ("InfluxDB point: " ^ msg)) fmt

let check_name what name =
  let allowed c =
    Char.is_alphanum c || List.mem [ '_'; '.'; '-' ] c ~equal:Char.equal
  in
  if
    String.is_empty name
    || String.is_prefix name ~prefix:"_"
    || not (String.for_all name ~f:allowed)
  then invalid "invalid %s %S" what name

let check_unique what keys =
  Option.iter (List.find_a_dup keys ~compare:String.compare) ~f:(fun key ->
      invalid "%s %S given twice" what key )

let create ?(timestamp = Time_ns.now ()) ?(tags = []) ~measurement fields =
  check_name "measurement" measurement ;
  List.iter tags ~f:(fun (key, value) ->
      check_name "tag key" key ;
      if String.is_empty value || String.mem value '\n' then
        invalid "tag %s has an empty or multi-line value" key ) ;
  check_unique "tag" (List.map tags ~f:fst) ;
  if List.is_empty fields then invalid "%s has no field" measurement ;
  List.iter fields ~f:(fun (key, value) ->
      check_name "field key" key ;
      match (value : Field.t) with
      | Float f when not (Float.is_finite f) ->
          invalid "field %s is not finite" key
      | Int _ | Float _ ->
          () ) ;
  check_unique "field" (List.map fields ~f:fst) ;
  { measurement; tags; fields; timestamp }

(* tag values: commas, equals signs and spaces are escaped *)
let escape_tag_value value =
  String.concat_map value ~f:(function
    | (',' | '=' | ' ') as c ->
        sprintf "\\%c" c
    | c ->
        String.of_char c )

let field_value : Field.t -> string = function
  | Int i ->
      sprintf "%di" i
  | Float f ->
      sprintf "%.15g" f

let to_line { measurement; tags; fields; timestamp } =
  sprintf "%s%s %s %d" measurement
    (String.concat
       (List.map tags ~f:(fun (key, value) ->
            sprintf ",%s=%s" key (escape_tag_value value) ) ) )
    (String.concat ~sep:","
       (List.map fields ~f:(fun (key, value) ->
            sprintf "%s=%s" key (field_value value) ) ) )
    (Time_ns.to_int_ns_since_epoch timestamp)

let write_file path points =
  Out_channel.write_lines path (List.map points ~f:to_line)
