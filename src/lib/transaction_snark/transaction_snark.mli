open Core
open Coda_base
open Snark_params

val reduce_fee_excesses :
     Token_id.t * Currency.Amount.Signed.t
  -> Token_id.t * Currency.Amount.Signed.t
  -> Token_id.t * Currency.Amount.Signed.t
  -> Token_id.t * Currency.Amount.Signed.t
  -> ( (Token_id.t * Currency.Amount.Signed.t)
     * (Token_id.t * Currency.Amount.Signed.t) )
     Or_error.t

(** For debugging. Logs to stderr the inputs to the top hash. *)
val with_top_hash_logging : (unit -> 'a) -> 'a

module Proof_type : sig
  module Stable : sig
    module V1 : sig
      type t = [`Base | `Merge] [@@deriving bin_io, sexp, yojson]
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp, yojson]
end

module Pending_coinbase_stack_state : sig
  module Stable : sig
    module V1 : sig
      type t =
        { source: Pending_coinbase.Stack_versioned.Stable.V1.t
        ; target: Pending_coinbase.Stack_versioned.Stable.V1.t }
      [@@deriving bin_io, compare, eq, fields, hash, sexp, version, yojson]
    end

    module Latest = V1
  end

  type t = Stable.Latest.t =
    {source: Pending_coinbase.Stack.t; target: Pending_coinbase.Stack.t}
  [@@deriving sexp, hash, compare, eq]
end

module Statement : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t =
        { source: Coda_base.Frozen_ledger_hash.Stable.V1.t
        ; target: Coda_base.Frozen_ledger_hash.Stable.V1.t
        ; supply_increase: Currency.Amount.Stable.V1.t
        ; pending_coinbase_stack_state: Pending_coinbase_stack_state.t
        ; fee_token_l: Coda_base.Token_id.Stable.V1.t
        ; fee_excess_l:
            ( Currency.Fee.Stable.V1.t
            , Sgn.Stable.V1.t )
            Currency.Signed_poly.Stable.V1.t
        ; fee_token_r: Coda_base.Token_id.Stable.V1.t
        ; fee_excess_r:
            ( Currency.Fee.Stable.V1.t
            , Sgn.Stable.V1.t )
            Currency.Signed_poly.Stable.V1.t
        ; proof_type: Proof_type.Stable.V1.t }
      [@@deriving compare, equal, hash, sexp, yojson]
    end
  end]

  type t = Stable.Latest.t =
    { source: Coda_base.Frozen_ledger_hash.t
    ; target: Coda_base.Frozen_ledger_hash.t
    ; supply_increase: Currency.Amount.t
    ; pending_coinbase_stack_state: Pending_coinbase_stack_state.t
    ; fee_token_l: Coda_base.Token_id.t
    ; fee_excess_l: Currency.Fee.Signed.t
    ; fee_token_r: Coda_base.Token_id.t
    ; fee_excess_r: Currency.Fee.Signed.t
    ; proof_type: Proof_type.t }
  [@@deriving compare, equal, hash, sexp, yojson]

  val gen : t Quickcheck.Generator.t

  val merge : t -> t -> t Or_error.t

  include Hashable.S_binable with type t := t

  include Comparable.S with type t := t
end

[%%versioned:
module Stable : sig
  module V1 : sig
    type t [@@deriving compare, sexp, to_yojson]
  end
end]

type t = Stable.Latest.t [@@deriving sexp, to_yojson]

val create :
     source:Frozen_ledger_hash.t
  -> target:Frozen_ledger_hash.t
  -> proof_type:Proof_type.t
  -> supply_increase:Currency.Amount.t
  -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
  -> fee_token_l:Token_id.t
  -> fee_excess_l:Currency.Amount.Signed.t
  -> fee_token_r:Token_id.t
  -> fee_excess_r:Currency.Amount.Signed.t
  -> sok_digest:Sok_message.Digest.t
  -> proof:Tock.Proof.t
  -> t

val proof : t -> Tock.Proof.t

val statement : t -> Statement.t

val sok_digest : t -> Sok_message.Digest.t

module Keys : sig
  module Proving : sig
    type t =
      { base: Tick.Proving_key.t
      ; wrap: Tock.Proving_key.t
      ; merge: Tick.Proving_key.t }

    val dummy : t

    module Location : Stringable.S

    val load : Location.t -> (t * Md5.t) Async.Deferred.t
  end

  module Verification : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type t =
          { base: Tick.Verification_key.t
          ; wrap: Tock.Verification_key.t
          ; merge: Tick.Verification_key.t }
      end
    end]

    type t = Stable.Latest.t =
      { base: Tick.Verification_key.t
      ; wrap: Tock.Verification_key.t
      ; merge: Tick.Verification_key.t }

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

  val cached :
       unit
    -> (Location.t * Verification.t * Checksum.t)
       Cached.Deferred_with_track_generated.t
end

module Verification : sig
  module type S = sig
    val verify : t -> message:Sok_message.t -> bool

    val verify_against_digest : t -> bool

    val verify_complete_merge :
         Sok_message.Digest.Checked.t
      -> Frozen_ledger_hash.var
      -> Frozen_ledger_hash.var
      -> Pending_coinbase.Stack.var
      -> Pending_coinbase.Stack.var
      -> Currency.Amount.var
      -> (Tock.Proof.t, 's) Tick.As_prover.t
      -> (Tick.Boolean.var, 's) Tick.Checked.t
  end

  module Make (K : sig
    val keys : Keys.Verification.t
  end) : S
end

val check_transaction :
     ?preeval:bool
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> sok_message:Sok_message.t
  -> source:Frozen_ledger_hash.t
  -> target:Frozen_ledger_hash.t
  -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
  -> Transaction.t Transaction_protocol_state.t
  -> Tick.Handler.t
  -> unit

val check_user_command :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> sok_message:Sok_message.t
  -> source:Frozen_ledger_hash.t
  -> target:Frozen_ledger_hash.t
  -> Pending_coinbase.Stack.t
  -> User_command.With_valid_signature.t Transaction_protocol_state.t
  -> Tick.Handler.t
  -> unit

val generate_transaction_witness :
     ?preeval:bool
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> sok_message:Sok_message.t
  -> source:Frozen_ledger_hash.t
  -> target:Frozen_ledger_hash.t
  -> Pending_coinbase_stack_state.t
  -> Transaction.t Transaction_protocol_state.t
  -> Tick.Handler.t
  -> unit

module type S = sig
  include Verification.S

  val of_transaction :
       ?preeval:bool
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> sok_digest:Sok_message.Digest.t
    -> source:Frozen_ledger_hash.t
    -> target:Frozen_ledger_hash.t
    -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
    -> Transaction.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t

  val of_user_command :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> sok_digest:Sok_message.Digest.t
    -> source:Frozen_ledger_hash.t
    -> target:Frozen_ledger_hash.t
    -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
    -> User_command.With_valid_signature.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t

  val of_fee_transfer :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> sok_digest:Sok_message.Digest.t
    -> source:Frozen_ledger_hash.t
    -> target:Frozen_ledger_hash.t
    -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
    -> Fee_transfer.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t

  val merge : t -> t -> sok_digest:Sok_message.Digest.t -> t Or_error.t
end

module Make (K : sig
  val keys : Keys.t
end) : S

val constraint_system_digests : unit -> (string * Md5.t) list
