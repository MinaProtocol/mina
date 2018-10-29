open Core
open Ctypes
open Foreign

type t = unit ptr

let typ = ptr void

let func_name s = sprintf "camlsnark_string_%s" s

let to_char_pointer : t -> char ptr =
  foreign (func_name "to_char_pointer") (typ @-> returning (ptr char))

let length : t -> int = foreign (func_name "length") (typ @-> returning int)

let delete : t -> unit = foreign (func_name "delete") (typ @-> returning void)

let to_string (s : t) : string =
  let ptr = to_char_pointer s in
  Ctypes.string_from_ptr ptr ~length:(length s)

let of_string_stub : string -> int -> t =
  foreign (func_name "of_char_pointer") (string @-> int @-> returning typ)

let of_char_pointer_don't_delete : char ptr -> int -> t =
  foreign (func_name "of_char_pointer") (ptr char @-> int @-> returning typ)

let of_string_don't_delete (s : string) : t =
  let length = String.length s in
  of_string_stub s length
