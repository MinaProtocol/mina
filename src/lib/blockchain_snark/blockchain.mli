(* TODO: check if this is needed *)
open Core_kernel
open Coda_base
open Coda_state

module Stable : sig
  module V1 : sig
    type t = {state: Protocol_state.Value.t; proof: Proof.Stable.V1.t}
    [@@deriving bin_io, fields, sexp, version]
  end

  module Latest = V1
end

type t = Stable.Latest.t =
  {state: Protocol_state.Value.t; proof: Proof.Stable.V1.t}
[@@deriving fields, sexp]

val create : state:Protocol_state.Value.t -> proof:Proof.Stable.V1.t -> t
