(* structured_events.ml *)

open Core_kernel

type t = ..

type id = string [@@deriving eq, compare, hash, yojson, sexp]

let id_of_string s = s

type repr =
  { log: t -> (string * id * (string * Yojson.Safe.json) list) option
  ; parse: id -> (string * Yojson.Safe.json) list -> t option }

module Registry = struct
  module T = struct
    type t = id [@@deriving sexp, hash, compare]
  end

  include Hashable.Make (T)

  let repr_table = Table.create ()

  let reprs = ref []

  let register_constructor id repr =
    (* for looking up parsers *)
    ( match Table.add repr_table ~key:id ~data:repr with
    | `Ok ->
        ()
    | `Duplicate ->
        failwith "register_constructor: Duplicate structured event" ) ;
    (* for looking up loggers *)
    reprs := repr :: !reprs

  let find_parser id = Table.find_exn repr_table id
end

let parse_exn id json_pairs =
  let repr = Registry.find_parser id in
  match repr.parse id json_pairs with
  | Some t ->
      t
  | None ->
      failwith "parse_exn: could not parse input"

let log t =
  let result = List.find_map !Registry.reprs ~f:(fun repr -> repr.log t) in
  match result with
  | Some data ->
      data
  | None ->
      failwith "log: did not find matching logger"

[%%define_locally
Registry.(register_constructor)]
