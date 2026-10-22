(* TODO: check if this is needed *)
open Core_kernel
open Mina_base
open Mina_state

[%%versioned:
module Stable : sig
  module V4 : sig
    type t [@@deriving sexp, yojson]
  end

  module V3 : sig
    type t [@@deriving sexp, yojson]

    val to_latest : t -> V4.t
  end
end]

val create : state:Protocol_state.Value.t -> proof:Proof.t -> t

val state : t -> Protocol_state.Value.t

val proof : t -> Proof.t
