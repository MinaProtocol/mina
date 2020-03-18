(* fork_id.ml -- representation of fork IDs *)

open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Core_kernel.String.Stable.V1.t [@@deriving sexp, eq]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t [@@deriving sexp, eq]

(* only allow lower-case a .. f *)
let is_hex_char = function
  | '0' .. '9' ->
      true
  | 'a' .. 'f' ->
      true
  | _ ->
      false

let is_hex_string s =
  String.fold s ~init:true ~f:(fun accum c -> accum && is_hex_char c)

let required_length = 5

let (current_fork_id : t option ref) = ref None

let (next_fork_id_opt : t option ref) = ref None

let set_current fork_id = current_fork_id := Some fork_id

let set_next_opt fork_id_opt = next_fork_id_opt := fork_id_opt

let empty = String.make required_length '0'

(* we set current fork id on daemon startup, so we should not see errors
   due to current_fork_id = None in get_current_fork_id and create
 *)
let get_current () = Option.value_exn !current_fork_id

let get_next_opt () = !next_fork_id_opt

let create_exn s =
  let len = String.length s in
  if not (Int.equal len required_length) then
    failwith
      (sprintf "Fork_id.create: string must have length %d" required_length) ;
  let s_lowercase = String.lowercase s in
  if not @@ is_hex_string s_lowercase then
    failwith
      "Fork_id.create: input string must contain only hexadecimal digits" ;
  s_lowercase

let create_opt s =
  let len = String.length s in
  if not (Int.equal len required_length) then None
  else
    let s_lowercase = String.lowercase s in
    if not @@ is_hex_string s_lowercase then None else Some s_lowercase

let to_string = Fn.id

(* when an external transition is deserialized, might contain
   some arbitrary string
*)
let is_valid t =
  Int.equal (String.length t) required_length
  && String.fold t ~init:true ~f:(fun accum c -> accum && is_hex_char c)
