(* yojson_prims.ml *)

open Core_kernel
open Yojson.Safe

(* yojson conversions for (some) built-in OCaml types *)

let int_to_yojson n : json = `Int n

let int_of_yojson (json : json) : (int, string) Result.t =
  match json with `Int n -> Ok n | _ -> Error "int_of_yojson: expected `Int"

let float_to_yojson f : json = `Float f

let float_of_yojson (json : json) : (float, string) Result.t =
  match json with
  | `Float f ->
      Ok f
  | _ ->
      Error "float_of_yojson: expected `Float"

let string_to_yojson s : json = `String s

let string_of_yojson (json : json) : (string, string) Result.t =
  match json with
  | `String s ->
      Ok s
  | _ ->
      Error "string_of_yojson: expected `String"

let bool_to_yojson b : json = `Bool b

let bool_of_yojson (json : json) : (bool, string) Result.t =
  match json with
  | `Bool b ->
      Ok b
  | _ ->
      Error "bool_of_yojson: expected `Bool"

let unit_to_yojson () : json = `Null

let unit_of_yojson (json : json) : (unit, string) Result.t =
  match json with
  | `Null ->
      Ok ()
  | _ ->
      Error "unit_of_yojson: expected `Null"
