open Core
open Mina_base
open Mina_transaction
open Snark_params
open Mina_state
open Currency
module Transaction_validator = Transaction_validator

(** For debugging. Logs to stderr the inputs to the top hash. *)
val with_top_hash_logging : (unit -> 'a) -> 'a

module Pending_coinbase_stack_state : sig
  module Init_stack : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type t = Base of Pending_coinbase.Stack_versioned.Stable.V1.t | Merge
        [@@deriving sexp, hash, compare, equal, yojson]
      end
    end]
  end

  module Poly : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type 'pending_coinbase t =
          { source : 'pending_coinbase; target : 'pending_coinbase }
        [@@deriving compare, equal, fields, hash, sexp, yojson]

        val to_latest :
             ('pending_coinbase -> 'pending_coinbase')
          -> 'pending_coinbase t
          -> 'pending_coinbase' t
      end
    end]

    val typ :
         ('pending_coinbase_var, 'pending_coinbase) Tick.Typ.t
      -> ('pending_coinbase_var t, 'pending_coinbase t) Tick.Typ.t
  end

  type 'pending_coinbase poly = 'pending_coinbase Poly.t =
    { source : 'pending_coinbase; target : 'pending_coinbase }
  [@@deriving sexp, hash, compare, equal, fields, yojson]

  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = Pending_coinbase.Stack_versioned.Stable.V1.t Poly.Stable.V1.t
      [@@deriving compare, equal, hash, sexp, yojson]
    end
  end]

  type var = Pending_coinbase.Stack.var Poly.t

  open Tick

  val typ : (var, t) Typ.t

  val to_input : t -> Field.t Random_oracle.Input.Chunked.t

  val var_to_input : var -> Field.Var.t Random_oracle.Input.Chunked.t
end

module Statement : sig
  module Poly : sig
    [%%versioned:
    module Stable : sig
      module V2 : sig
        type ( 'ledger_hash
             , 'amount
             , 'pending_coinbase
             , 'fee_excess
             , 'sok_digest
             , 'local_state )
             t =
          { source :
              ( 'ledger_hash
              , 'pending_coinbase
              , 'local_state )
              Registers.Stable.V1.t
          ; target :
              ( 'ledger_hash
              , 'pending_coinbase
              , 'local_state )
              Registers.Stable.V1.t
          ; supply_increase : 'amount
          ; fee_excess : 'fee_excess
          ; sok_digest : 'sok_digest
          }
        [@@deriving compare, equal, hash, sexp, yojson, hlist]
      end
    end]

    val with_empty_local_state :
         supply_increase:'amount
      -> fee_excess:'fee_excess
      -> sok_digest:'sok_digest
      -> source:'ledger_hash
      -> target:'ledger_hash
      -> pending_coinbase_stack_state:
           'pending_coinbase Pending_coinbase_stack_state.poly
      -> ( 'ledger_hash
         , 'amount
         , 'pending_coinbase
         , 'fee_excess
         , 'sok_digest
         , Mina_transaction_logic.Zkapp_command_logic.Local_state.Value.t )
         t
  end

  type ( 'ledger_hash
       , 'amount
       , 'pending_coinbase
       , 'fee_excess
       , 'sok_digest
       , 'local_state )
       poly =
        ( 'ledger_hash
        , 'amount
        , 'pending_coinbase
        , 'fee_excess
        , 'sok_digest
        , 'local_state )
        Poly.t =
    { source : ('ledger_hash, 'pending_coinbase, 'local_state) Registers.t
    ; target : ('ledger_hash, 'pending_coinbase, 'local_state) Registers.t
    ; supply_increase : 'amount
    ; fee_excess : 'fee_excess
    ; sok_digest : 'sok_digest
    }
  [@@deriving compare, equal, hash, sexp, yojson]

  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t =
        ( Frozen_ledger_hash.Stable.V1.t
        , (Amount.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t
        , Pending_coinbase.Stack_versioned.Stable.V1.t
        , Fee_excess.Stable.V1.t
        , unit
        , Local_state.Stable.V1.t )
        Poly.Stable.V2.t
      [@@deriving compare, equal, hash, sexp, yojson]
    end
  end]

  module With_sok : sig
    [%%versioned:
    module Stable : sig
      module V2 : sig
        type t =
          ( Frozen_ledger_hash.Stable.V1.t
          , (Amount.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t
          , Pending_coinbase.Stack_versioned.Stable.V1.t
          , Fee_excess.Stable.V1.t
          , Sok_message.Digest.Stable.V1.t
          , Local_state.Stable.V1.t )
          Poly.Stable.V2.t
        [@@deriving compare, equal, hash, sexp, yojson]
      end
    end]

    type var =
      ( Frozen_ledger_hash.var
      , Amount.Signed.var
      , Pending_coinbase.Stack.var
      , Fee_excess.var
      , Sok_message.Digest.Checked.t
      , Local_state.Checked.t )
      Poly.t

    open Tick

    val typ : (var, t) Typ.t

    val to_input : t -> Field.t Random_oracle.Input.Chunked.t

    val to_field_elements : t -> Field.t array

    module Checked : sig
      type t = var

      val to_input : var -> Field.Var.t Random_oracle.Input.Chunked.t Checked.t

      (* This is actually a checked function. *)
      val to_field_elements : var -> Field.Var.t array
    end
  end

  val gen : t Quickcheck.Generator.t

  val merge : t -> t -> t Or_error.t

  include Hashable.S_binable with type t := t

  include Comparable.S with type t := t
end

[%%versioned:
module Stable : sig
  module V2 : sig
    type t [@@deriving compare, equal, sexp, yojson, hash]
  end
end]

val create : statement:Statement.With_sok.t -> proof:Mina_base.Proof.t -> t

val proof : t -> Mina_base.Proof.t

val statement : t -> Statement.t

val sok_digest : t -> Sok_message.Digest.t

open Pickles_types

type tag =
  ( Statement.With_sok.Checked.t
  , Statement.With_sok.t
  , Nat.N2.n
  , Nat.N5.n )
  Pickles.Tag.t

val verify :
     (t * Sok_message.t) list
  -> key:Pickles.Verification_key.t
  -> bool Async.Deferred.t

module Verification : sig
  module type S = sig
    val tag : tag

    val verify : (t * Sok_message.t) list -> bool Async.Deferred.t

    val id : Pickles.Verification_key.Id.t Lazy.t

    val verification_key : Pickles.Verification_key.t Lazy.t

    val verify_against_digest : t -> bool Async.Deferred.t

    val constraint_system_digests : (string * Md5_lib.t) list Lazy.t
  end
end

val check_transaction :
     ?preeval:bool
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> sok_message:Sok_message.t
  -> source:Frozen_ledger_hash.t
  -> target:Frozen_ledger_hash.t
  -> init_stack:Pending_coinbase.Stack.t
  -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
  -> zkapp_account1:Zkapp_account.t option
  -> zkapp_account2:Zkapp_account.t option
  -> supply_increase:Amount.Signed.t
  -> Transaction.Valid.t Transaction_protocol_state.t
  -> Tick.Handler.t
  -> unit

val check_user_command :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> sok_message:Sok_message.t
  -> source:Frozen_ledger_hash.t
  -> target:Frozen_ledger_hash.t
  -> init_stack:Pending_coinbase.Stack.t
  -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
  -> supply_increase:Amount.Signed.t
  -> Signed_command.With_valid_signature.t Transaction_protocol_state.t
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
  -> zkapp_account1:Zkapp_account.t option
  -> zkapp_account2:Zkapp_account.t option
  -> supply_increase:Amount.Signed.t
  -> Transaction.Valid.t Transaction_protocol_state.t
  -> Tick.Handler.t
  -> unit

module Zkapp_command_segment : sig
  module Spec : sig
    type single =
      { auth_type : Control.Tag.t
      ; is_start : [ `Yes | `No | `Compute_in_circuit ]
      }

    type t = single list
  end

  module Witness = Transaction_witness.Zkapp_command_segment_witness

  module Basic : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type t = Opt_signed_opt_signed | Opt_signed | Proved
        [@@deriving sexp, yojson]
      end
    end]

    val to_single_list : t -> Spec.single list
  end
end

module type S = sig
  include Verification.S

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val cache_handle : Pickles.Cache_handle.t

  val of_non_zkapp_command_transaction :
       statement:Statement.With_sok.t
    -> init_stack:Pending_coinbase.Stack.t
    -> Transaction.Valid.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t Async.Deferred.t

  val of_user_command :
       statement:Statement.With_sok.t
    -> init_stack:Pending_coinbase.Stack.t
    -> Signed_command.With_valid_signature.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t Async.Deferred.t

  val of_fee_transfer :
       statement:Statement.With_sok.t
    -> init_stack:Pending_coinbase.Stack.t
    -> Fee_transfer.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t Async.Deferred.t

  val of_zkapp_command_segment_exn :
       statement:Statement.With_sok.t
    -> witness:Zkapp_command_segment.Witness.t
    -> spec:Zkapp_command_segment.Basic.t
    -> t Async.Deferred.t

  val merge :
    t -> t -> sok_digest:Sok_message.Digest.t -> t Async.Deferred.Or_error.t
end

type local_state =
  ( Stack_frame.value
  , Stack_frame.value list
  , Token_id.t
  , Currency.Amount.Signed.t
  , Mina_ledger.Sparse_ledger.t
  , bool
  , Zkapp_command.Transaction_commitment.t
  , Mina_numbers.Index.t
  , Transaction_status.Failure.Collection.t )
  Mina_transaction_logic.Zkapp_command_logic.Local_state.t

type global_state = Mina_ledger.Sparse_ledger.Global_state.t

(** Represents before/after pairs of states, corresponding to zkapp_command in a list of zkapp_command transactions.
 *)
module Zkapp_command_intermediate_state : sig
  type state = { global : global_state; local : local_state }

  type t =
    { kind : [ `Same | `New | `Two_new ]
    ; spec : Zkapp_command_segment.Basic.t
    ; state_before : state
    ; state_after : state
    }
end

(** [group_by_zkapp_command_rev zkapp_commands stmtss] identifies before/after pairs of
    statements, corresponding to zkapp_command in [zkapp_commands] which minimize the
    number of snark proofs needed to prove all of the zkapp_command.

    This function is intended to take the zkapp_command from multiple transactions as
    its input, which may be converted from a [Zkapp_command.t list] using
    [List.map ~f:Zkapp_command.zkapp_command]. The [stmtss] argument should be a list of
    the same length, with 1 more state than the number of zkapp_command for each
    transaction.

    For example, two transactions made up of zkapp_command [[p1; p2; p3]] and
    [[p4; p5]] should have the statements [[[s0; s1; s2; s3]; [s3; s4; s5]]],
    where each [s_n] is the state after applying [p_n] on top of [s_{n-1}], and
    where [s0] is the initial state before any of the transactions have been
    applied.

    Each pair is also identified with one of [`Same], [`New], or [`Two_new],
    indicating that the next one ([`New]) or next two ([`Two_new]) [Zkapp_command.t]s
    will need to be passed as part of the snark witness while applying that
    pair.
*)
val group_by_zkapp_command_rev :
     Account_update.t list list
  -> (global_state * local_state) list list
  -> Zkapp_command_intermediate_state.t list

(** [zkapp_command_witnesses_exn ledger zkapp_commands] generates the zkapp_command segment witnesses
    and corresponding statements needed to prove the application of each
    zkapp_command transaction in [zkapp_commands] on top of ledger. If multiple zkapp_command are
    given, they are applied in order and grouped together to minimise the
    number of transaction proofs that would be required.
    There must be at least one zkapp_command transaction in [zkapp_command].

    The returned value is a list of tuples, each corresponding to a single
    proof for some parts of some zkapp_command transactions, comprising:
    * the witness information for the segment, to be passed to the prover
    * the segment kind, identifying the type of proof that will be generated
    * the proof statement, describing the transition between the states before
      and after the segment
    * the list of calculated 'snapp statements', corresponding to the expected
      public input of any snapp zkapp_command in the current segment.

    WARNING: This function calls the transaction logic internally, and thus may
    raise an exception if the transaction logic would also do so. This function
    should only be used on zkapp_command that are already known to pass transaction
    logic without an exception.
*)
val zkapp_command_witnesses_exn :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> state_body:Transaction_protocol_state.Block_data.t
  -> fee_excess:Currency.Amount.Signed.t
  -> [ `Ledger of Mina_ledger.Ledger.t
     | `Sparse_ledger of Mina_ledger.Sparse_ledger.t ]
  -> ( [ `Pending_coinbase_init_stack of Pending_coinbase.Stack.t ]
     * [ `Pending_coinbase_of_statement of Pending_coinbase_stack_state.t ]
     * Zkapp_command.t )
     list
  -> ( Zkapp_command_segment.Witness.t
     * Zkapp_command_segment.Basic.t
     * Statement.With_sok.t )
     list
     * Mina_ledger.Sparse_ledger.t

module Make (Inputs : sig
  val constraint_constants : Genesis_constants.Constraint_constants.t

  val proof_level : Genesis_constants.Proof_level.t
end) : S
[@@warning "-67"]

val constraint_system_digests :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> unit
  -> (string * Md5.t) list

(* Every circuit must have at least 1 of each type of constraint.
   This function can be used to add the missing constraints *)
val dummy_constraints : unit -> unit Tick.Checked.t

module Base : sig
  val check_timing :
       balance_check:(Tick.Boolean.var -> unit Tick.Checked.t)
    -> timed_balance_check:(Tick.Boolean.var -> unit Tick.Checked.t)
    -> account:
         ( 'b
         , 'c
         , 'd
         , 'e
         , Currency.Balance.var
         , 'f
         , 'g
         , 'h
         , 'i
         , ( Tick.Boolean.var
           , Mina_numbers.Global_slot.Checked.var
           , Currency.Balance.var
           , Currency.Amount.var )
           Account_timing.As_record.t
         , 'j
         , 'k
         , 'l )
         Account.Poly.t
    -> txn_amount:Currency.Amount.var option
    -> txn_global_slot:Mina_numbers.Global_slot.Checked.var
    -> ( [> `Min_balance of Currency.Balance.var ]
       * ( Tick.Boolean.var
         , Mina_numbers.Global_slot.Checked.var
         , Currency.Balance.var
         , Currency.Amount.var )
         Account_timing.As_record.t )
       Tick.Checked.t

  module Zkapp_command_snark : sig
    val main :
         ?witness:Zkapp_command_segment.Witness.t
      -> Zkapp_command_segment.Spec.t
      -> constraint_constants:Genesis_constants.Constraint_constants.t
      -> Statement.With_sok.var
      -> Zkapp_statement.Checked.t option
  end
end

module For_tests : sig
  module Deploy_snapp_spec : sig
    type t =
      { fee : Currency.Fee.t
      ; sender : Signature_lib.Keypair.t * Mina_base.Account.Nonce.t
      ; fee_payer : (Signature_lib.Keypair.t * Mina_base.Account.Nonce.t) option
      ; amount : Currency.Amount.t
      ; zkapp_account_keypairs : Signature_lib.Keypair.t list
      ; memo : Signed_command_memo.t
      ; new_zkapp_account : bool
      ; snapp_update : Account_update.Update.t
            (* Authorization for the update being performed *)
      ; preconditions : Account_update.Preconditions.t option
      ; authorization_kind : Account_update.Authorization_kind.t
      }
    [@@deriving sexp]
  end

  val deploy_snapp :
       ?no_auth:bool
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> Deploy_snapp_spec.t
    -> Zkapp_command.t

  module Update_states_spec : sig
    type t =
      { fee : Currency.Fee.t
      ; sender : Signature_lib.Keypair.t * Mina_base.Account.Nonce.t
      ; fee_payer : (Signature_lib.Keypair.t * Mina_base.Account.Nonce.t) option
      ; receivers :
          (Signature_lib.Public_key.Compressed.t * Currency.Amount.t) list
      ; amount : Currency.Amount.t
      ; zkapp_account_keypairs : Signature_lib.Keypair.t list
      ; memo : Signed_command_memo.t
      ; new_zkapp_account : bool
      ; snapp_update : Account_update.Update.t
            (* Authorization for the update being performed *)
      ; current_auth : Permissions.Auth_required.t
      ; sequence_events : Tick.Field.t array list
      ; events : Tick.Field.t array list
      ; call_data : Tick.Field.t
      ; preconditions : Account_update.Preconditions.t option
      }
    [@@deriving sexp]
  end

  val update_states :
       ?zkapp_prover:
         ( unit
         , unit
         , unit
         , Zkapp_statement.t
         , (unit * unit * (Nat.N2.n, Nat.N2.n) Pickles.Proof.t) Async.Deferred.t
         )
         Pickles.Prover.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> Update_states_spec.t
    -> Zkapp_command.t Async.Deferred.t

  val create_trivial_predicate_snapp :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> ?protocol_state_predicate:Zkapp_precondition.Protocol_state.t
    -> snapp_kp:Signature_lib.Keypair.t
    -> Mina_transaction_logic.For_tests.Transaction_spec.t
    -> Mina_ledger.Ledger.t
    -> Zkapp_command.t Async.Deferred.t

  val trivial_zkapp_account :
       ?permissions:Permissions.t
    -> vk:(Side_loaded_verification_key.t, Tick.Field.t) With_hash.t
    -> Account.key
    -> Account.t

  val create_trivial_zkapp_account :
       ?permissions:Permissions.t
    -> vk:(Side_loaded_verification_key.t, Tick.Field.t) With_hash.t
    -> ledger:Mina_ledger.Ledger.t
    -> Account.key
    -> unit

  val create_trivial_snapp :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> unit
    -> [> `VK of (Side_loaded_verification_key.t, Tick.Field.t) With_hash.t ]
       * [> `Prover of
            ( unit
            , unit
            , unit
            , Zkapp_statement.t
            , (unit * unit * (Nat.N2.n, Nat.N2.n) Pickles.Proof.t)
              Async.Deferred.t )
            Pickles.Prover.t ]

  module Multiple_transfers_spec : sig
    type t =
      { fee : Currency.Fee.t
      ; sender : Signature_lib.Keypair.t * Mina_base.Account.Nonce.t
      ; fee_payer : (Signature_lib.Keypair.t * Mina_base.Account.Nonce.t) option
      ; receivers :
          (Signature_lib.Public_key.Compressed.t * Currency.Amount.t) list
      ; amount : Currency.Amount.t
      ; zkapp_account_keypairs : Signature_lib.Keypair.t list
      ; memo : Signed_command_memo.t
      ; new_zkapp_account : bool
      ; snapp_update : Account_update.Update.t
            (* Authorization for the update being performed *)
      ; sequence_events : Tick.Field.t array list
      ; events : Tick.Field.t array list
      ; call_data : Tick.Field.t
      ; preconditions : Account_update.Preconditions.t option
      }
    [@@deriving sexp]
  end

  val multiple_transfers : Multiple_transfers_spec.t -> Zkapp_command.t
end
