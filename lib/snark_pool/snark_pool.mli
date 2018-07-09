open Protocols
open Core_kernel
open Async_kernel
open Coda_pow

module type S = sig
  type work

  type proof

  type fee

  type priced_proof

  type t

  val create_pool : unit -> t

  val add_snark : t -> work:work -> proof:proof -> fee:fee -> unit

  val request_proof : t -> work -> priced_proof option

  val add_unsolved_work : t -> work -> unit

  (* TODO: Include my_fee as a paramter for request work and 
          return work that has a fee less than my_fee if the 
          returned work does not have any unsolved work *)

  val request_work : t -> work option

  val gen :
       proof Quickcheck.Generator.t
    -> fee Quickcheck.Generator.t
    -> work Quickcheck.Generator.t
    -> t Quickcheck.Generator.t
end

module Make (Proof : sig
  type t [@@deriving bin_io]

  include Proof_intf with type t := t
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
