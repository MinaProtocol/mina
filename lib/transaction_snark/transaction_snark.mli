open Core
open Nanobit_base
open Snark_params

module Proof_type : sig
  type t = [`Merge | `Base] [@@deriving bin_io, sexp]
end

module Transition : sig
  type t =
    | Transaction of Transaction.With_valid_signature.t
    | Fee_transfer of Fee_transfer.t
  [@@deriving bin_io, sexp]
end

module Statement : sig
  type t =
    { source: Nanobit_base.Ledger_hash.Stable.V1.t
    ; target: Nanobit_base.Ledger_hash.Stable.V1.t
    ; fee_excess: Currency.Fee.Signed.Stable.V1.t
    ; proof_type: Proof_type.t }
  [@@deriving sexp, bin_io, hash, compare]

  val gen : t Quickcheck.Generator.t

  include Hashable.S_binable with type t := t
end

type t [@@deriving bin_io, sexp]

val create :
     source:Ledger_hash.t
  -> target:Ledger_hash.t
  -> proof_type:Proof_type.t
  -> fee_excess:Currency.Amount.Signed.t
  -> proof:Tock.Proof.t
  -> t

val proof : t -> Tock.Proof.t

val statement : t -> Statement.t

module Keys : sig
  module Proving : sig
    type t =
      { base: Tick.Proving_key.t
      ; wrap: Tock.Proving_key.t
      ; merge: Tick.Proving_key.t }
    [@@deriving bin_io]

    val dummy : t

    module Location : Stringable.S

    val load : Location.t -> (t * Md5.t) Async.Deferred.t
  end

  module Verification : sig
    type t =
      { base: Tick.Verification_key.t
      ; wrap: Tock.Verification_key.t
      ; merge: Tick.Verification_key.t }
    [@@deriving bin_io]

    val dummy : t

    module Location : Stringable.S

    val load : Location.t -> (t * Md5.t) Async.Deferred.t
  end

  module Location : sig
    type t =
      {proving: Proving.Location.t; verification: Verification.Location.t}

    include Stringable.S with type t := t
  end

  module Checksum : sig
    type t = {proving: Md5.t; verification: Md5.t}
  end

  type t = {proving: Proving.t; verification: Verification.t}

  val create : unit -> t

  val cached : unit -> (Location.t * t * Checksum.t) Async.Deferred.t
end

module Verification : sig
  module type S = sig
    val verify : t -> bool

    val verify_complete_merge :
         Ledger_hash.var
      -> Ledger_hash.var
      -> (Tock.Proof.t, 's) Tick.As_prover.t
      -> (Tick.Boolean.var, 's) Tick.Checked.t
  end

  module Make (K : sig
    val keys : Keys.Verification.t
  end) :
    S
end

val check_transition :
  Ledger_hash.t -> Ledger_hash.t -> Transition.t -> Tick.Handler.t -> unit

val check_transaction :
     Ledger_hash.t
  -> Ledger_hash.t
  -> Transaction.With_valid_signature.t
  -> Tick.Handler.t
  -> unit

module type S = sig
  include Verification.S

  val of_transition :
    Ledger_hash.t -> Ledger_hash.t -> Transition.t -> Tick.Handler.t -> t

  val of_transaction :
       Ledger_hash.t
    -> Ledger_hash.t
    -> Transaction.With_valid_signature.t
    -> Tick.Handler.t
    -> t

  val of_fee_transfer :
    Ledger_hash.t -> Ledger_hash.t -> Fee_transfer.t -> Tick.Handler.t -> t

  val merge : t -> t -> t Or_error.t
end

val handle_with_ledger : Ledger.t -> Tick.Handler.t

module Make (K : sig
  val keys : Keys.t
end) :
  S
