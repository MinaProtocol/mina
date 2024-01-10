(* chain_status.ml *)

open Core_kernel

type t = Canonical | Orphaned | Pending
[@@deriving yojson, equal, bin_io_unversioned]

let to_string = function
  | Canonical ->
      "canonical"
  | Orphaned ->
      "orphaned"
  | Pending ->
      "pending"

let of_string = function
  | "canonical" ->
      Canonical
  | "orphaned" ->
      Orphaned
  | "pending" ->
      Pending
  | s ->
      failwithf "Chain_status.of_string: invalid string = %s" s ()
