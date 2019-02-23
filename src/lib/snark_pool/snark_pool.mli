open Core_kernel

module Priced_proof : sig
  type ('proof, 'fee) t = {proof: 'proof; fee: 'fee}
  [@@deriving bin_io, sexp, fields]
end

module type S = sig
  type work

  type proof

  type fee

  type t [@@deriving bin_io]

  type transition_frontier

  val create :
       parent_log:Logger.t
    -> frontier_broadcast_pipe:transition_frontier option
                               Pipe_lib.Broadcast_pipe.Reader.t
    -> t

  val add_snark :
       t
    -> work:work
    -> proof:proof
    -> fee:fee
    -> [`Rebroadcast | `Don't_rebroadcast]

  val request_proof : t -> work -> (proof, fee) Priced_proof.t option
end

module Make (Proof : sig
  type t [@@deriving bin_io]
end) (Fee : sig
  type t [@@deriving sexp, bin_io]

  include Comparable.S with type t := t
end) (Work : sig
  type t [@@deriving sexp, bin_io]

  include Hashable.S_binable with type t := t
end) (Transition_frontier : sig
  type t

  module Extensions :
    Protocols.Coda_transition_frontier.Transition_frontier_extensions_intf
    with module Work = Work

  val extension_pipes : t -> Extensions.Readers.t
end) :
  S with type work := Work.t and type proof := Proof.t and type fee := Fee.t
