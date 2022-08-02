open Core
open Async
open Graphql_async
module Schema = Graphql_wrapper.Make (Schema)

(** Convert a GraphQL constant to the equivalent json representation.
    We can't coerce this directly because of the presence of the [`Enum]
    constructor, so we have to recurse over the structure replacing all of the
    [`Enum]s with [`String]s.
*)
let rec to_yojson (json : Graphql_parser.const_value) : Yojson.Safe.t =
  match json with
  | `Assoc fields ->
      `Assoc (List.map fields ~f:(fun (name, json) -> (name, to_yojson json)))
  | `Bool b ->
      `Bool b
  | `Enum s ->
      `String s
  | `Float f ->
      `Float f
  | `Int i ->
      `Int i
  | `List l ->
      `List (List.map ~f:to_yojson l)
  | `Null ->
      `Null
  | `String s ->
      `String s

let result_of_exn f v ~error = try Ok (f v) with _ -> Error error

let result_of_or_error ?error v =
  Result.map_error v ~f:(fun internal_error ->
      let str_error = Error.to_string_hum internal_error in
      match error with
      | None ->
          str_error
      | Some error ->
          sprintf "%s (%s)" error str_error )

let result_field_no_inputs ~resolve =
  Schema.io_field ~resolve:(fun resolve_info src ->
      Deferred.return @@ resolve resolve_info src )

(* one input *)
let result_field ~resolve =
  Schema.io_field ~resolve:(fun resolve_info src inputs ->
      Deferred.return @@ resolve resolve_info src inputs )

(* two inputs *)
let result_field2 ~resolve =
  Schema.io_field ~resolve:(fun resolve_info src input1 input2 ->
      Deferred.return @@ resolve resolve_info src input1 input2 )
