open Core_kernel
open Pipe_lib

module Priced_proof : sig
  type ('proof, 'fee) t = {proof: 'proof; fee: 'fee}
  [@@deriving bin_io, sexp, fields]
end

module type Transition_frontier_intf = sig
  type t

  module Extensions :
    Protocols.Coda_transition_frontier.Transition_frontier_extensions_intf

  val extension_pipes : t -> Extensions.readers
end

module type S = sig
  type work

  type proof

  type fee

  type transition_frontier

  type t [@@deriving bin_io]

  val create :
       parent_log:Logger.t
    -> frontier_broadcast_pipe:transition_frontier Option.t
                               Broadcast_pipe.Reader.t
    -> t

  val add_snark :
       t
    -> work:work
    -> proof:proof
    -> fee:fee
    -> [`Rebroadcast | `Don't_rebroadcast]

  val request_proof : t -> work -> (proof, fee) Priced_proof.t option

  val listen_to_frontier_broadcast_pipe :
    transition_frontier option Broadcast_pipe.Reader.t -> t -> unit
end

module Make (Proof : sig
  type t [@@deriving bin_io]
end) (Fee : sig
  type t [@@deriving sexp, bin_io]

  include Comparable.S with type t := t
end) (Work : sig
  type t [@@deriving sexp, bin_io]

  include Hashable.S_binable with type t := t
end)
(Transition_frontier : Transition_frontier_intf
                       with module Extensions.Work = Work) :
  S
  with type work := Work.t
   and type proof := Proof.t
   and type fee := Fee.t
   and type transition_frontier := Transition_frontier.t
