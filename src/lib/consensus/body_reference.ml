(* This module defines how a block header refers to the body of its block.
    At the moment, this is merely a hash of the body. But in an upcoming
    hard fork, we will be updating this to reference to point to the root
    "Bitswap block" CID along with a signature attesting to ownership over
    this association (for punishment and manipuluation prevention). This will
    allow us to upgrade block gossip to happen over Bitswap in a future
    soft fork release. *)

open Core_kernel
open Snark_params.Tick
open Fold_lib
open Mina_base_util

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Blake2.Stable.V1.t [@@deriving sexp, yojson, hash, equal, compare]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t

[%%define_locally Stable.Latest.(t_of_sexp, sexp_of_t, to_yojson, of_yojson)]

type var = Boolean.var list

let fold t = Fold.string_bits (Blake2.to_raw_string t)

let var_of_t t : var = List.map (Fold.to_list @@ fold t) ~f:Boolean.var_of_value

let to_input t =
  let open Random_oracle.Input.Chunked in
  Array.reduce_exn ~f:append
    (Array.of_list_map
       (Fold.to_list (fold t))
       ~f:(fun b -> packed (field_of_bool b, 1)) )

let var_to_input (t : var) =
  let open Random_oracle.Input.Chunked in
  Array.reduce_exn ~f:append
    (Array.of_list_map t ~f:(fun b -> packed ((b :> Field.Var.t), 1)))

let typ : (var, t) Typ.t =
  Typ.transport
    (Typ.list ~length:256 Boolean.typ)
    ~there:(Fn.compose Fold.to_list fold)
    ~back:
      (Fn.compose Blake2.of_raw_string
         (Fn.compose Fold.bool_t_to_string Fold.of_list) )

let to_hex = Blake2.to_hex
