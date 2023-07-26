(* TODO: check if this is needed *)
open Core_kernel
open Mina_base
open Mina_state

[%%versioned:
module Stable : sig
  module V2 : sig
    type t [@@deriving sexp, yojson]
  end
end]

val create : state:Protocol_state.Value.t -> proof:Proof.t -> t

val state : t -> Protocol_state.Value.t

val proof : t -> Proof.t
