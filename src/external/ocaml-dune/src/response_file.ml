open Stdune

type t =
  | Not_supported
  | Zero_terminated_strings of string

let registry = Hashtbl.create 128

let get ~prog =
  Option.value (Hashtbl.find registry prog) ~default:Not_supported

let set ~prog t =
  Hashtbl.add registry prog t
