(* chain_status.ml *)

open Core_kernel

type t = Canonical | Orphaned
[@@deriving yojson, equal, bin_io_unversioned]

let to_string = function
  | Canonical -> "canonical"
  | Orphaned -> "orphaned"

let of_string = function
  | "canonical" -> Canonical
  | "orphaned" -> Orphaned
  | s ->
    failwithf "Chain_status.of_string: invalid string = %s" s ()
