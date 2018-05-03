open Nanobit_base
open Snark_params

module Proof_type : sig
  type t = Base | Merge
  [@@deriving bin_io]
end

module Transition : sig
  type t =
    | Transaction of Transaction.With_valid_signature.t
    | Fee_transfer of Fee_transfer.t
  [@@deriving bin_io, sexp]
end

type t
[@@deriving bin_io]

val create
  :  source:Ledger_hash.t
  -> target:Ledger_hash.t
  -> proof_type:Proof_type.t
  -> fee_excess:Currency.Amount.Signed.t
  -> proof:Tock.Proof.t
  -> t

val proof : t -> Tock.Proof.t

module Keys : sig
  type t
  [@@deriving bin_io]

  val dummy :  unit -> t

  val create : unit -> t
end

val check_transition
  :  Ledger_hash.t
  -> Ledger_hash.t
  -> Transition.t
  -> Tick.Handler.t
  -> unit

val check_transaction
  :  Ledger_hash.t
  -> Ledger_hash.t
  -> Transaction.With_valid_signature.t
  -> Tick.Handler.t
  -> unit

module type S = sig
  val verify : t -> bool

  val of_transition
    :  Ledger_hash.t
    -> Ledger_hash.t
    -> Transition.t
    -> Tick.Handler.t
    -> t

  val of_transaction
    :  Ledger_hash.t
    -> Ledger_hash.t
    -> Transaction.With_valid_signature.t
    -> Tick.Handler.t
    -> t

  val of_fee_transfer
    :  Ledger_hash.t
    -> Ledger_hash.t
    -> Fee_transfer.t
    -> Tick.Handler.t
    -> t

  val merge : t -> t -> t

  val verify_complete_merge
    : Ledger_hash.var
    -> Ledger_hash.var
    -> (Tock.Proof.t, 's) Tick.As_prover.t
    -> (Tick.Boolean.var, 's) Tick.Checked.t
end

val handle_with_ledger : Ledger.t -> Tick.Handler.t

module Make (K : sig val keys : Keys.t end) : S
