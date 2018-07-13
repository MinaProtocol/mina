open Protocols
open Core_kernel
open Async_kernel
open Coda_pow

module Priced_proof : sig
  type ('proof, 'fee) t = {proof: 'proof; fee: 'fee}
  [@@deriving bin_io, sexp, fields]
end

module type S = sig
  type work

  type proof

  type fee

  type t
  [@@deriving bin_io]

  val create_pool : unit -> t

  val add_snark :
       t
    -> work:work
    -> proof:proof
    -> fee:fee
    -> [`Rebroadcast | `Don't_rebroadcast]

  val request_proof : t -> work -> (proof, fee) Priced_proof.t option

  val add_unsolved_work : t -> work -> [`Rebroadcast | `Don't_rebroadcast]

  (* TODO: Include my_fee as a paramter for request work and 
          return work that has a fee less than my_fee if the 
          returned work does not have any unsolved work *)

  val request_work : t -> work option
end

module Make (Proof : sig
  type t [@@deriving bin_io]
end) (Fee : sig
  type t [@@deriving sexp, bin_io]

  val gen : t Quickcheck.Generator.t

  include Comparable.S with type t := t
end) (Work : sig
  type t [@@deriving sexp, bin_io]

  val gen : t Quickcheck.Generator.t

  include Hashable.S_binable with type t := t
end) :
  S with type work := Work.t and type proof := Proof.t and type fee := Fee.t
