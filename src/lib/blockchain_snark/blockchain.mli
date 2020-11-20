(* TODO: check if this is needed *)
open Core_kernel
open Coda_base
open Coda_state

[%%versioned:
module Stable : sig
  module V1 : sig
    type t [@@deriving sexp, yojson]
  end
end]

val create : state:Protocol_state.Value.t -> proof:Proof.Stable.V1.t -> t

val state : t -> Protocol_state.Value.t

val proof : t -> Proof.t
