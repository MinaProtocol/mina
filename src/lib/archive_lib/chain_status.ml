(* chain_status.ml *)

open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Canonical | Orphaned | Pending [@@deriving yojson, equal]

    let to_latest = Fn.id
  end
end]

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
