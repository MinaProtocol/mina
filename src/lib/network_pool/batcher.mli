open Core_kernel
open Async_kernel
open Network_peer

module Snark_pool : sig
  type proof_envelope =
    (Ledger_proof.t One_or_two.t * Coda_base.Sok_message.t) Envelope.Incoming.t
  [@@deriving sexp]

  type t [@@deriving sexp]

  val create : Verifier.t -> t

  val verify :
       t
    -> proof_envelope
    -> bool Deferred.Or_error.t
end

module Transaction_pool : sig
  open Coda_base

  type t
  [@@deriving sexp]

  val create : Verifier.t -> t

  val verify :
       t
    -> Command_transaction.Verifiable.t list Envelope.Incoming.t
      -> (Command_transaction.Valid.t list, unit) Result.t
       Deferred.Or_error.t
end
