(** This module defines how a block header refers to the body of its block.
    At the moment, this is merely a hash of the body. But in an upcoming
    hard fork, we will be updating this to reference to point to the root
    "Bitswap block" CID along with a signature attesting to ownership over
    this association (for punishment and manipuluation prevention). This will
    allow us to upgrade block gossip to happen over Bitswap in a future
    soft fork release. *)

open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    (* type t = State_body_hash.Stable.V1.t *)
    type t = unit [@@deriving compare, sexp, yojson]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t

[%%define_locally
Stable.V1.(compare, t_of_sexp, sexp_of_t, of_yojson, to_yojson)]

let of_body = Fn.const ()

(* let of_body = Body.hash *)
