(** Transaction SNARK circuits.

    This code is called in:
    - [src/lib/prover/prover.ml] - block production
    - [src/lib/verifier/verifier.ml] - proof verification
    - [src/lib/snark_worker/prod.ml] - SNARK work generation
    - [src/lib/genesis_proof/genesis_proof.ml] - genesis proof

    The transaction SNARK has 5 circuits:

    - {b transaction-merge}: Combines two transaction proofs into one. Used to
      parallelize proof generation by merging sub-proofs in a tree structure.
      This circuit is used for all transaction types, including zkApp commands.

    - {b transaction-base}: Proves a single non-zkApp transaction (payments,
      stake delegations, coinbase, fee transfers). This is the leaf circuit
      that processes individual transactions.

    - {b zkapp-opt_signed-opt_signed}: Proves a zkApp command with two account
      updates that may have optional signatures. Handles the most complex case
      with multiple authorization modes.

    - {b zkapp-opt_signed}: Proves a zkApp command with one account update that
      may have an optional signature.

    - {b zkapp-proved}: Proves a zkApp command where authorization comes from a
      side-loaded proof (the zkApp's own proof).

    Constraint counts vary by profile due to different configuration parameters
    (e.g., ledger depth).

    Note: These values are measured with proof_level=Full, which generates the
    actual constraint system used in production. See {!Genesis_constants.Proof_level}
    for details on proof levels.

    {b Dev profile:}
    {v
    | Circuit                     | Constraints | Public Input | Auxiliary Input |
    |-----------------------------|-------------|--------------|-----------------|
    | transaction-merge           | 632         | 300          | 1,895           |
    | transaction-base            | 12,875      | 300          | 37,502          |
    | zkapp-opt_signed-opt_signed | 14,537      | 300          | 56,588          |
    | zkapp-opt_signed            | 8,026       | 300          | 32,166          |
    | zkapp-proved                | 4,249       | 300          | 30,732          |
    v}

    {b Devnet profile:}
    {v
    | Circuit                     | Constraints | Public Input | Auxiliary Input |
    |-----------------------------|-------------|--------------|-----------------|
    | transaction-merge           | 632         | 300          | 1,895           |
    | transaction-base            | 15,357      | 300          | 63,806          |
    | zkapp-opt_signed-opt_signed | 16,206      | 300          | 74,242          |
    | zkapp-opt_signed            | 8,883       | 300          | 41,170          |
    | zkapp-proved                | 5,106       | 300          | 39,736          |
    v}

    {b Lightnet profile:}
    {v
    | Circuit                     | Constraints | Public Input | Auxiliary Input |
    |-----------------------------|-------------|--------------|-----------------|
    | transaction-merge           | 632         | 300          | 1,895           |
    | transaction-base            | 15,357      | 300          | 63,806          |
    | zkapp-opt_signed-opt_signed | 16,206      | 300          | 74,242          |
    | zkapp-opt_signed            | 8,883       | 300          | 41,170          |
    | zkapp-proved                | 5,106       | 300          | 39,736          |
    v}

    {b Mainnet profile:}
    {v
    | Circuit                     | Constraints | Public Input | Auxiliary Input |
    |-----------------------------|-------------|--------------|-----------------|
    | transaction-merge           | 632         | 300          | 1,895           |
    | transaction-base            | 15,357      | 300          | 63,806          |
    | zkapp-opt_signed-opt_signed | 16,206      | 300          | 74,242          |
    | zkapp-opt_signed            | 8,883       | 300          | 41,170          |
    | zkapp-proved                | 5,106       | 300          | 39,736          |
    v}

    If these values change, update the tables above and the expected values in
    [test/constraint_count/test_constraint_count.ml]. *)

module type Full = sig
  open Core
  open Mina_base
  open Mina_transaction
  open Snark_params
  open Currency
  module Transaction_validator = Transaction_validator

  (** For debugging. Logs to stderr the inputs to the top hash. *)
  val with_top_hash_logging : (unit -> 'a) -> 'a

  module Pending_coinbase_stack_state =
    Mina_state.Snarked_ledger_state.Pending_coinbase_stack_state

  module Statement = Mina_state.Snarked_ledger_state

  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t [@@deriving compare, equal, sexp, yojson, hash]
    end
  end]

  module Serializable_type : sig
    type raw_serializable := Stable.Latest.t

    [%%versioned:
    module Stable : sig
      module V2 : sig
        type t
      end
    end]

    val create :
         statement:Statement.With_sok.t
      -> proof:Proof_cache_tag.Serializable_type.Stable.Latest.t
      -> t

    val statement : t -> Statement.t

    val to_raw_serializable : t -> raw_serializable
  end

  val create : statement:Statement.With_sok.t -> proof:Mina_base.Proof.t -> t

  val proof : t -> Mina_base.Proof.t

  val statement : t -> Statement.t

  val statement_with_sok : t -> Statement.With_sok.t

  val sok_digest : t -> Sok_message.Digest.t

  open Pickles_types

  type tag =
    ( Statement.With_sok.var
    , Statement.With_sok.t
    , Nat.N2.n
    , Nat.N5.n )
    Pickles.Tag.t

  val verify :
       key:Pickles.Verification_key.t
    -> (t * Sok_message.t) list
    -> unit Or_error.t Async.Deferred.t

  module Verification : sig
    module type S = sig
      val tag : tag

      val verify : (t * Sok_message.t) list -> unit Or_error.t Async.Deferred.t

      val id : Pickles.Verification_key.Id.t Async.Deferred.t Lazy.t

      val verification_key : Pickles.Verification_key.t Async.Deferred.t Lazy.t

      val verify_against_digest : t -> unit Or_error.t Async.Deferred.t

      val constraint_system_digests : (string * Md5_lib.t) list Lazy.t
    end
  end

  val check_transaction :
       signature_kind:Mina_signature_kind.t
    -> ?preeval:bool
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> sok_message:Sok_message.t
    -> source_first_pass_ledger:Frozen_ledger_hash.t
    -> target_first_pass_ledger:Frozen_ledger_hash.t
    -> init_stack:Pending_coinbase.Stack.t
    -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
    -> supply_increase:Amount.Signed.t
    -> Transaction.Valid.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> unit

  val check_user_command :
       signature_kind:Mina_signature_kind.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> sok_message:Sok_message.t
    -> source_first_pass_ledger:Frozen_ledger_hash.t
    -> target_first_pass_ledger:Frozen_ledger_hash.t
    -> init_stack:Pending_coinbase.Stack.t
    -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
    -> supply_increase:Amount.Signed.t
    -> Signed_command.With_valid_signature.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> unit

  val generate_transaction_witness :
       signature_kind:Mina_signature_kind.t
    -> ?preeval:bool
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> sok_message:Sok_message.t
    -> source_first_pass_ledger:Frozen_ledger_hash.t
    -> target_first_pass_ledger:Frozen_ledger_hash.t
    -> init_stack:Pending_coinbase.Stack.t
    -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
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

    val signature_kind : Mina_signature_kind.t

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
       signature_kind:Mina_signature_kind.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> global_slot:Mina_numbers.Global_slot_since_genesis.t
    -> state_body:Transaction_protocol_state.Block_data.t
    -> fee_excess:Currency.Amount.Signed.t
    -> ( [ `Pending_coinbase_init_stack of Pending_coinbase.Stack.t ]
       * [ `Pending_coinbase_of_statement of Pending_coinbase_stack_state.t ]
       * [ `Ledger of Mina_ledger.Ledger.t
         | `Sparse_ledger of Mina_ledger.Sparse_ledger.t ]
       * [ `Ledger of Mina_ledger.Ledger.t
         | `Sparse_ledger of Mina_ledger.Sparse_ledger.t ]
       * [ `Connecting_ledger_hash of Ledger_hash.t ]
       * Zkapp_command.t )
       list
    -> ( Zkapp_command_segment.Witness.t
       * Zkapp_command_segment.Basic.t
       * Statement.With_sok.t )
       list

  module Make (Inputs : sig
    val signature_kind : Mina_signature_kind.t

    val constraint_constants : Genesis_constants.Constraint_constants.t

    val proof_level : Genesis_constants.Proof_level.t
  end) : S

  val constraint_system_digests :
       signature_kind:Mina_signature_kind.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> unit
    -> (string * Md5.t) list

  (** Return the constraint system for the transaction-merge circuit. *)
  val merge_constraint_system : unit -> Tick.R1CS_constraint_system.t

  (** Return the constraint system for the transaction-base circuit. *)
  val base_constraint_system :
       signature_kind:Mina_signature_kind.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> Tick.R1CS_constraint_system.t

  (** Return the constraint system for the zkapp-opt_signed-opt_signed circuit. *)
  val zkapp_opt_signed_opt_signed_constraint_system :
       signature_kind:Mina_signature_kind.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> Tick.R1CS_constraint_system.t

  (** Return the constraint system for the zkapp-opt_signed circuit. *)
  val zkapp_opt_signed_constraint_system :
       signature_kind:Mina_signature_kind.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> Tick.R1CS_constraint_system.t

  (** Return the constraint system for the zkapp-proved circuit. *)
  val zkapp_proved_constraint_system :
       signature_kind:Mina_signature_kind.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> Tick.R1CS_constraint_system.t

  (* Every circuit must have at least 1 of each type of constraint.
     This function can be used to add the missing constraints *)
  val dummy_constraints : unit -> unit Tick.Checked.t

  module Base : sig
    val check_timing :
         balance_check:(Tick.Boolean.var -> unit Tick.Checked.t)
      -> timed_balance_check:(Tick.Boolean.var -> unit Tick.Checked.t)
      -> account:
           ( 'b
           , 'd
           , 'e
           , Currency.Balance.var
           , 'f
           , 'g
           , 'h
           , 'i
           , ( Tick.Boolean.var
             , Mina_numbers.Global_slot_since_genesis.Checked.var
             , Mina_numbers.Global_slot_span.Checked.var
             , Currency.Balance.var
             , Currency.Amount.var )
             Account_timing.As_record.t
           , 'j
           , 'k )
           Account.Poly.t
      -> txn_amount:Currency.Amount.var option
      -> txn_global_slot:Mina_numbers.Global_slot_since_genesis.Checked.var
      -> ( [> `Min_balance of Currency.Balance.var ]
         * ( Tick.Boolean.var
           , Mina_numbers.Global_slot_since_genesis.Checked.var
           , Mina_numbers.Global_slot_span.Checked.var
           , Currency.Balance.var
           , Currency.Amount.var )
           Account_timing.As_record.t )
         Tick.Checked.t

    module Zkapp_command_snark : sig
      val main :
           signature_kind:Mina_signature_kind.t
        -> ?witness:Zkapp_command_segment.Witness.t
        -> Zkapp_command_segment.Spec.t
        -> constraint_constants:Genesis_constants.Constraint_constants.t
        -> Statement.With_sok.var
        -> Zkapp_statement.Checked.t option
           * [> `Must_verify of Tick.Boolean.var ]
    end
  end

  module For_tests : sig
    module Deploy_snapp_spec : sig
      type t =
        { fee : Currency.Fee.t
        ; sender : Signature_lib.Keypair.t * Mina_base.Account.Nonce.t
        ; fee_payer :
            (Signature_lib.Keypair.t * Mina_base.Account.Nonce.t) option
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
      -> ?permissions:Permissions.t
      -> constraint_constants:Genesis_constants.Constraint_constants.t
      -> signature_kind:Mina_signature_kind.t
      -> Deploy_snapp_spec.t
      -> Zkapp_command.t Async.Deferred.t

    module Single_account_update_spec : sig
      type t =
        { fee : Currency.Fee.t
        ; fee_payer : Signature_lib.Keypair.t * Mina_base.Account.Nonce.t
        ; zkapp_account_keypair : Signature_lib.Keypair.t
        ; memo : Signed_command_memo.t
        ; update : Account_update.Update.t
        ; actions :
            Tick.Field.t Mina_stdlib.Bounded_types.ArrayN4000.Stable.V1.t list
        ; events :
            Tick.Field.t Mina_stdlib.Bounded_types.ArrayN4000.Stable.V1.t list
        ; call_data : Tick.Field.t
        }
    end

    val single_account_update :
         ?zkapp_prover_and_vk:
           ( unit
           , unit
           , unit
           , Zkapp_statement.t
           , (unit * unit * Nat.N2.n Pickles.Proof.t) Async.Deferred.t )
           Pickles.Prover.t
           * ( Pickles.Side_loaded.Verification_key.t
             , Snark_params.Tick.Field.t )
             With_hash.t
             Async.Deferred.t
      -> constraint_constants:Genesis_constants.Constraint_constants.t
      -> signature_kind:Mina_signature_kind.t
      -> Single_account_update_spec.t
      -> Zkapp_command.t Async.Deferred.t

    module Update_states_spec : sig
      type t =
        { fee : Currency.Fee.t
        ; sender : Signature_lib.Keypair.t * Mina_base.Account.Nonce.t
        ; fee_payer :
            (Signature_lib.Keypair.t * Mina_base.Account.Nonce.t) option
        ; receivers : (Signature_lib.Keypair.t * Currency.Amount.t) list
        ; amount : Currency.Amount.t
        ; zkapp_account_keypairs : Signature_lib.Keypair.t list
        ; memo : Signed_command_memo.t
        ; new_zkapp_account : bool
        ; snapp_update : Account_update.Update.t
              (* Authorization for the update being performed *)
        ; current_auth : Permissions.Auth_required.t
        ; actions :
            Tick.Field.t Mina_stdlib.Bounded_types.ArrayN4000.Stable.V1.t list
        ; events :
            Tick.Field.t Mina_stdlib.Bounded_types.ArrayN4000.Stable.V1.t list
        ; call_data : Tick.Field.t
        ; preconditions : Account_update.Preconditions.t option
        }
      [@@deriving sexp]
    end

    val update_states :
         ?receiver_auth:Control.Tag.t
      -> ?zkapp_prover_and_vk:
           ( unit
           , unit
           , unit
           , Zkapp_statement.t
           , (unit * unit * Nat.N2.n Pickles.Proof.t) Async.Deferred.t )
           Pickles.Prover.t
           * ( Pickles.Side_loaded.Verification_key.t
             , Snark_params.Tick.Field.t )
             With_hash.t
             Async.Deferred.t
      -> ?empty_sender:bool
      -> constraint_constants:Genesis_constants.Constraint_constants.t
      -> Update_states_spec.t
      -> Zkapp_command.t Async.Deferred.t

    val create_trivial_predicate_snapp :
         ?protocol_state_predicate:Zkapp_precondition.Protocol_state.t
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
         ?unique_id:int
      -> unit
      -> [> `VK of
            (Side_loaded_verification_key.t, Tick.Field.t) With_hash.t
            Async.Deferred.t ]
         * [> `Prover of
              ( unit
              , unit
              , unit
              , Zkapp_statement.t
              , (unit * unit * Nat.N2.n Pickles.Proof.t) Async.Deferred.t )
              Pickles.Prover.t ]

    module Signature_transfers_spec : sig
      type t =
        { fee : Currency.Fee.t
        ; sender : Signature_lib.Keypair.t * Mina_base.Account.Nonce.t
        ; fee_payer :
            (Signature_lib.Keypair.t * Mina_base.Account.Nonce.t) option
        ; receivers :
            ( ( Signature_lib.Keypair.t
              , Signature_lib.Public_key.Compressed.t )
              Either.t
            * Currency.Amount.t )
            list
        ; amount : Currency.Amount.t
        ; zkapp_account_keypairs : Signature_lib.Keypair.t list
        ; memo : Signed_command_memo.t
        ; new_zkapp_account : bool
        ; snapp_update : Account_update.Update.t
              (* Authorization for the update being performed *)
        ; actions :
            Tick.Field.t Mina_stdlib.Bounded_types.ArrayN4000.Stable.V1.t list
        ; events :
            Tick.Field.t Mina_stdlib.Bounded_types.ArrayN4000.Stable.V1.t list
        ; transfer_parties_get_actions_events : bool
        ; call_data : Tick.Field.t
        ; preconditions : Account_update.Preconditions.t option
        }
      [@@deriving sexp]
    end

    val signature_transfers :
         ?receiver_auth:Control.Tag.t
      -> constraint_constants:Genesis_constants.Constraint_constants.t
      -> Signature_transfers_spec.t
      -> Zkapp_command.t

    module Multiple_transfers_spec : sig
      type t =
        { fee : Currency.Fee.t
        ; sender : Signature_lib.Keypair.t * Mina_base.Account.Nonce.t
        ; fee_payer :
            (Signature_lib.Keypair.t * Mina_base.Account.Nonce.t) option
        ; receivers :
            (Signature_lib.Public_key.Compressed.t * Currency.Amount.t) list
        ; amount : Currency.Amount.t
        ; zkapp_account_keypairs : Signature_lib.Keypair.t list
        ; memo : Signed_command_memo.t
        ; new_zkapp_account : bool
        ; snapp_update : Account_update.Update.t
              (* Authorization for the update being performed *)
        ; actions :
            Tick.Field.t Mina_stdlib.Bounded_types.ArrayN4000.Stable.V1.t list
        ; events :
            Tick.Field.t Mina_stdlib.Bounded_types.ArrayN4000.Stable.V1.t list
        ; call_data : Tick.Field.t
        ; preconditions : Account_update.Preconditions.t option
        }
      [@@deriving sexp]
    end

    val multiple_transfers :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> Multiple_transfers_spec.t
      -> Zkapp_command.t

    val set_proof_cache : Pickles.Proof_cache.t -> unit
  end
end
