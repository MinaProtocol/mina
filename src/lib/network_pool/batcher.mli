open Core_kernel
open Async_kernel
open Network_peer

module Snark_pool : sig
  type proof_envelope =
    (Ledger_proof.t One_or_two.t * Mina_base.Sok_message.t) Envelope.Incoming.t
  [@@deriving sexp]

  type t [@@deriving sexp]

  val create : Verifier.t -> t

  val verify : t -> proof_envelope -> bool Deferred.Or_error.t
end

type ('initial, 'partially_validated, 'result) t

val create :
     ?how_to_add:[ `Insert | `Enqueue_back ]
  -> ?logger:Logger.t
  -> ?compare_init:('init -> 'init -> int)
  -> ?weight:('init -> int)
  -> ?max_weight_per_call:int
  -> (   [ `Init of 'init | `Partially_validated of 'partially_validated ] list
      -> [ `Valid of 'result
         | `Potentially_invalid of 'partially_validated
         | Verifier.invalid ]
         list
         Deferred.Or_error.t)
  -> ('init, 'partially_validated, 'result) t

val verify :
     ('input, 'partial, 'result) t
  -> 'input
  -> ('result, Verifier.invalid) Result.t Deferred.Or_error.t

val compare_envelope : _ Envelope.Incoming.t -> _ Envelope.Incoming.t -> int

module Transaction_pool : sig
  open Mina_base

  type t [@@deriving sexp]

  val create : Verifier.t -> t

  val verify :
       t
    -> User_command.Verifiable.t list Envelope.Incoming.t
    -> (User_command.Valid.t list, Verifier.invalid) Result.t
       Deferred.Or_error.t
end
