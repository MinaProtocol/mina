(* fork_id.ml -- representation of fork IDs *)

open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Core_kernel.String.Stable.V1.t [@@deriving sexp]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t [@@deriving sexp]

let is_hex_char = function
  | '0' .. '9' ->
      true
  | 'a' .. 'f' ->
      true
  | _ ->
      false

let required_length = 5

let create s =
  let len = String.length s in
  if not (Int.equal len required_length) then
    failwith
      (sprintf "Fork_id.create: string must have length %d" required_length) ;
  let s_lowercase = String.lowercase s in
  if
    not
      (String.fold s_lowercase ~init:true ~f:(fun accum c ->
           accum && is_hex_char c ))
  then
    failwith
      "Fork_id.create: input string must contain only hexadecimal digits" ;
  s_lowercase

let to_string = Fn.id

let empty = create (String.make required_length '0')
