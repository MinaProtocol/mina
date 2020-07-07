open Core
open Coda_base
open Snark_params

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
  module Init_stack : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type t = Base of Pending_coinbase.Stack_versioned.Stable.V1.t | Merge
        [@@deriving sexp, hash, compare, eq, yojson]
      end
    end]

    type t = Stable.Latest.t = Base of Pending_coinbase.Stack.t | Merge
    [@@deriving sexp, hash, compare, yojson]
  end

  module Poly : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type 'pending_coinbase t =
          {source: 'pending_coinbase; target: 'pending_coinbase}
        [@@deriving compare, eq, fields, hash, sexp, yojson]

        val to_latest :
             ('pending_coinbase -> 'pending_coinbase')
          -> 'pending_coinbase t
          -> 'pending_coinbase' t
      end
    end]

    type 'pending_coinbase t = 'pending_coinbase Stable.Latest.t =
      {source: 'pending_coinbase; target: 'pending_coinbase}
    [@@deriving compare, eq, fields, hash, sexp, yojson]

    val typ :
         ('pending_coinbase_var, 'pending_coinbase) Tick.Typ.t
      -> ('pending_coinbase_var t, 'pending_coinbase t) Tick.Typ.t
  end

  type 'pending_coinbase poly = 'pending_coinbase Poly.t =
    {source: 'pending_coinbase; target: 'pending_coinbase}
  [@@deriving sexp, hash, compare, eq, fields, yojson]

  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = Pending_coinbase.Stack_versioned.Stable.V1.t Poly.Stable.V1.t
      [@@deriving compare, eq, hash, sexp, yojson]
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, hash, compare, eq, yojson]

  type var = Pending_coinbase.Stack.var Poly.t

  open Tick

  val typ : (var, t) Typ.t

  val to_input : t -> (Field.t, bool) Random_oracle.Input.t

  val var_to_input : var -> (Field.Var.t, Boolean.var) Random_oracle.Input.t
end

module Statement : sig
  module Poly : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type ( 'ledger_hash
             , 'amount
             , 'pending_coinbase
             , 'fee_excess
             , 'token_id
             , 'proof_type
             , 'sok_digest )
             t =
          { source: 'ledger_hash
          ; target: 'ledger_hash
          ; supply_increase: 'amount
          ; pending_coinbase_stack_state: 'pending_coinbase
          ; fee_excess: 'fee_excess
          ; next_available_token_before: 'token_id
          ; next_available_token_after: 'token_id
          ; proof_type: 'proof_type
          ; sok_digest: 'sok_digest }
        [@@deriving compare, equal, hash, sexp, yojson]

        val to_latest :
             ('ledger_hash -> 'ledger_hash')
          -> ('amount -> 'amount')
          -> ('pending_coinbase -> 'pending_coinbase')
          -> ('fee_excess -> 'fee_excess')
          -> ('token_id -> 'token_id')
          -> ('proof_type -> 'proof_type')
          -> ('sok_digest -> 'sok_digest')
          -> ( 'ledger_hash
             , 'amount
             , 'pending_coinbase
             , 'fee_excess
             , 'token_id
             , 'proof_type
             , 'sok_digest )
             t
          -> ( 'ledger_hash'
             , 'amount'
             , 'pending_coinbase'
             , 'fee_excess'
             , 'token_id'
             , 'proof_type'
             , 'sok_digest' )
             t
      end
    end]

    type ( 'ledger_hash
         , 'amount
         , 'pending_coinbase
         , 'fee_excess
         , 'token_id
         , 'proof_type
         , 'sok_digest )
         t =
          ( 'ledger_hash
          , 'amount
          , 'pending_coinbase
          , 'fee_excess
          , 'token_id
          , 'proof_type
          , 'sok_digest )
          Stable.Latest.t =
      { source: 'ledger_hash
      ; target: 'ledger_hash
      ; supply_increase: 'amount
      ; pending_coinbase_stack_state: 'pending_coinbase
      ; fee_excess: 'fee_excess
      ; next_available_token_before: 'token_id
      ; next_available_token_after: 'token_id
      ; proof_type: 'proof_type
      ; sok_digest: 'sok_digest }
    [@@deriving compare, equal, hash, sexp, yojson]
  end

  type ( 'ledger_hash
       , 'amount
       , 'pending_coinbase
       , 'fee_excess
       , 'token_id
       , 'proof_type
       , 'sok_digest )
       poly =
        ( 'ledger_hash
        , 'amount
        , 'pending_coinbase
        , 'fee_excess
        , 'token_id
        , 'proof_type
        , 'sok_digest )
        Poly.t =
    { source: 'ledger_hash
    ; target: 'ledger_hash
    ; supply_increase: 'amount
    ; pending_coinbase_stack_state: 'pending_coinbase
    ; fee_excess: 'fee_excess
    ; next_available_token_before: 'token_id
    ; next_available_token_after: 'token_id
    ; proof_type: 'proof_type
    ; sok_digest: 'sok_digest }
  [@@deriving compare, equal, hash, sexp, yojson]

  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t =
        ( Frozen_ledger_hash.Stable.V1.t
        , Currency.Amount.Stable.V1.t
        , Pending_coinbase_stack_state.Stable.V1.t
        , Fee_excess.Stable.V1.t
        , Token_id.Stable.V1.t
        , Proof_type.Stable.V1.t
        , unit )
        Poly.Stable.V1.t
      [@@deriving compare, equal, hash, sexp, yojson]
    end
  end]

  type t =
    ( Frozen_ledger_hash.t
    , Currency.Amount.t
    , Pending_coinbase_stack_state.t
    , Fee_excess.t
    , Token_id.t
    , Proof_type.t
    , unit )
    Poly.t
  [@@deriving sexp, hash, compare, yojson]

  module With_sok : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type t =
          ( Frozen_ledger_hash.Stable.V1.t
          , Currency.Amount.Stable.V1.t
          , Pending_coinbase_stack_state.Stable.V1.t
          , Fee_excess.Stable.V1.t
          , Token_id.Stable.V1.t
          , unit
          , Sok_message.Digest.Stable.V1.t )
          Poly.Stable.V1.t
        [@@deriving compare, equal, hash, sexp, yojson]
      end
    end]

    type t =
      ( Frozen_ledger_hash.t
      , Currency.Amount.t
      , Pending_coinbase_stack_state.t
      , Fee_excess.t
      , Token_id.t
      , unit
      , Sok_message.Digest.t )
      Poly.t
    [@@deriving sexp, hash, compare, yojson]

    type var =
      ( Frozen_ledger_hash.var
      , Currency.Amount.var
      , Pending_coinbase_stack_state.var
      , Fee_excess.var
      , Token_id.var
      , unit
      , Sok_message.Digest.Checked.t )
      Poly.Stable.V1.t

    open Tick

    val typ : (var, t) Typ.t

    val to_input : t -> (Field.t, bool) Random_oracle.Input.t

    val to_field_elements : t -> Field.t array

    module Checked : sig
      val to_input :
        var -> ((Field.Var.t, Boolean.var) Random_oracle.Input.t, _) Checked.t

      val to_field_elements : var -> (Field.Var.t array, _) Checked.t
    end
  end

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
  -> fee_excess:Fee_excess.t
  -> next_available_token_before:Token_id.t
  -> next_available_token_after:Token_id.t
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
    val verify : (t * Sok_message.t) list -> bool

    val verify_against_digest : t -> bool

    val verify_complete_merge :
         Sok_message.Digest.Checked.t
      -> Frozen_ledger_hash.var
      -> Frozen_ledger_hash.var
      -> Pending_coinbase.Stack.var
      -> Pending_coinbase.Stack.var
      -> Currency.Amount.var
      -> Token_id.var
      -> Token_id.var
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
  -> init_stack:Pending_coinbase.Stack.t
  -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
  -> next_available_token_before:Token_id.t
  -> next_available_token_after:Token_id.t
  -> Transaction.t Transaction_protocol_state.t
  -> Tick.Handler.t
  -> unit

val check_user_command :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> sok_message:Sok_message.t
  -> source:Frozen_ledger_hash.t
  -> target:Frozen_ledger_hash.t
  -> init_stack:Pending_coinbase.Stack.t
  -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
  -> next_available_token_before:Token_id.t
  -> next_available_token_after:Token_id.t
  -> User_command.With_valid_signature.t Transaction_protocol_state.t
  -> Tick.Handler.t
  -> unit

val generate_transaction_witness :
     ?preeval:bool
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> sok_message:Sok_message.t
  -> source:Frozen_ledger_hash.t
  -> target:Frozen_ledger_hash.t
  -> init_stack:Pending_coinbase.Stack.t
  -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
  -> next_available_token_before:Token_id.t
  -> next_available_token_after:Token_id.t
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
    -> init_stack:Pending_coinbase.Stack.t
    -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
    -> next_available_token_before:Token_id.t
    -> next_available_token_after:Token_id.t
    -> Transaction.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t

  val of_user_command :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> sok_digest:Sok_message.Digest.t
    -> source:Frozen_ledger_hash.t
    -> target:Frozen_ledger_hash.t
    -> init_stack:Pending_coinbase.Stack.t
    -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
    -> next_available_token_before:Token_id.t
    -> next_available_token_after:Token_id.t
    -> User_command.With_valid_signature.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t

  val of_fee_transfer :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> sok_digest:Sok_message.Digest.t
    -> source:Frozen_ledger_hash.t
    -> target:Frozen_ledger_hash.t
    -> init_stack:Pending_coinbase.Stack.t
    -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
    -> next_available_token_before:Token_id.t
    -> next_available_token_after:Token_id.t
    -> Fee_transfer.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t

  val merge : t -> t -> sok_digest:Sok_message.Digest.t -> t Or_error.t
end

module Make (K : sig
  val keys : Keys.t
end) : S

val constraint_system_digests : unit -> (string * Md5.t) list
