open Core_kernel
open Async_kernel
open Network_peer

type ('proof, 'result) t [@@deriving sexp]

module Outcome : sig
  type ('proof, 'result) t = {valid: 'result list; invalid: 'proof list}
  [@@deriving sexp]
end

val create
  (* The comparison function for proofs is to group things so that
  things which are more likely to jointly fail are grouped together.
  In practice, we sort by sender. *) :
     ?compare_proof:('a -> 'a -> int)
  -> ('a list -> ('result, unit) Result.t Deferred.Or_error.t)
  -> ('a, 'result) t

val verify :
     ('proof, 'result) t
  -> 'proof list
  -> ('proof, 'result) Outcome.t Deferred.Or_error.t

module Snark_pool : sig
  type proof_envelope =
    (Ledger_proof.t One_or_two.t * Coda_base.Sok_message.t) Envelope.Incoming.t
  [@@deriving sexp]

  module Work_key : sig
    type t =
      (Transaction_snark.Statement.t One_or_two.t * Coda_base.Sok_message.t)
      Envelope.Incoming.t
    [@@deriving sexp, compare]

    include Comparable.S with type t := t
  end

  type nonrec t = (proof_envelope, unit) t [@@deriving sexp]

  val create : Verifier.t -> t

  val verify :
       t
    -> proof_envelope list
    -> [`Invalid of Work_key.Set.t] Deferred.Or_error.t
end

module Transaction_pool : sig
  open Coda_base

  type nonrec t =
    ( Command_transaction.Verifiable.t list Envelope.Incoming.t
    , Command_transaction.Valid.t list )
    t
  [@@deriving sexp]

  val create : Verifier.t -> t

  val verify :
       t
    -> Command_transaction.Verifiable.t list Envelope.Incoming.t list
    -> ( Command_transaction.Verifiable.t list Envelope.Incoming.t
       , Command_transaction.Valid.t list )
       Outcome.t
       Deferred.Or_error.t
end
