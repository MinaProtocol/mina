(* structured_events.ml *)

open Core_kernel

type t = ..

type id = string [@@deriving eq, yojson, sexp]

let id_of_string s = s

type repr =
  { log: t -> (string * id * (string * Yojson.Safe.json) list) option
  ; parse: id -> (string * Yojson.Safe.json) list -> t option }

module Registry = struct
  let reprs = ref []

  let register_constructor repr = reprs := repr :: !reprs
end

let parse_exn id json_pairs =
  let result =
    List.find_map !Registry.reprs ~f:(fun repr -> repr.parse id json_pairs)
  in
  match result with
  | Some data ->
      data
  | None ->
      failwith "parse_exn: did not find matching parser"

let log t =
  let result = List.find_map !Registry.reprs ~f:(fun repr -> repr.log t) in
  match result with
  | Some data ->
      data
  | None ->
      failwith "log: did not find matching logger"

let register_constructor = Registry.register_constructor
