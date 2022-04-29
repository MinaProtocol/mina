open Mina_base
open Snark_params

val genesis_constants : Genesis_constants.t

val proof_level : Genesis_constants.Proof_level.t

val consensus_constants : Consensus.Constants.t

val constraint_constants : Genesis_constants.Constraint_constants.t

(* For tests, monkey patch ledger and sparse ledger to freeze their
   ledger_hashes.
   The nominal type prevents using this in non-test code. *)
module Ledger : module type of Mina_ledger.Ledger

module Sparse_ledger : module type of Mina_ledger.Sparse_ledger

val ledger_depth : Ledger.index

module T : Transaction_snark.S

val genesis_state_body : Transaction_protocol_state.Block_data.t

val genesis_state_view : Zkapp_precondition.Protocol_state.View.t

val genesis_state_body_hash : State_hash.t

val init_stack : Pending_coinbase.Stack_versioned.t

val pending_coinbase_state_stack :
     state_body_hash:State_hash.t
  -> Transaction_snark.Pending_coinbase_stack_state.t

val apply_parties : Ledger.t -> Parties.t list -> Sparse_ledger.t

val dummy_rule :
     (Zkapp_statement.Checked.t, 'a, 'b, 'c) Pickles.Tag.t
  -> ( Zkapp_statement.Checked.t * (Zkapp_statement.Checked.t * unit)
     , 'a * ('a * unit)
     , 'b * ('b * unit)
     , 'c * ('c * unit)
     , 'd
     , 'e )
     Pickles.Inductive_rule.t

(** Generates base and merge snarks of all the party segments

    Raises if either the snark generation or application fails
*)
val check_parties_with_merges_exn :
     ?expected_failure:Mina_base.Transaction_status.Failure.t
  -> ?state_body:Transaction_protocol_state.Block_data.t
  -> Ledger.t
  -> Parties.t list
  -> unit Async.Deferred.t

(** Verification key of a trivial smart contract *)
val trivial_snapp :
  ( [> `VK of (Side_loaded_verification_key.t, Tick.Field.t) With_hash.t ]
  * [> `Prover of
       ( unit
       , unit
       , unit
       , Zkapp_statement.t
       , (Pickles_types.Nat.N2.n, Pickles_types.Nat.N2.n) Pickles.Proof.t
         Async.Deferred.t )
       Pickles.Prover.t ] )
  Lazy.t

val gen_snapp_ledger :
  (Mina_transaction_logic.For_tests.Test_spec.t * Signature_lib.Keypair.t)
  Base_quickcheck.Generator.t

val test_snapp_update :
     ?expected_failure:Mina_base.Transaction_status.Failure.t
  -> ?state_body:Transaction_protocol_state.Block_data.t
  -> ?snapp_permissions:Permissions.t
  -> vk:(Side_loaded_verification_key.t, Tick.Field.t) With_hash.t
  -> snapp_prover:
       ( unit
       , unit
       , unit
       , Zkapp_statement.t
       , (Pickles_types.Nat.N2.n, Pickles_types.Nat.N2.n) Pickles.Proof.t
         Async.Deferred.t )
       Pickles.Prover.t
  -> Transaction_snark.For_tests.Spec.t
  -> init_ledger:Mina_transaction_logic.For_tests.Init_ledger.t
  -> snapp_pk:Account.key
  -> unit

val permissions_from_update :
     Party.Update.t
  -> auth:Permissions.Auth_required.t
  -> Permissions.Auth_required.t Permissions.Poly.t

val pending_coinbase_stack_target :
     Mina_transaction.Transaction.Valid.t
  -> State_hash.t
  -> Pending_coinbase.Stack.t
  -> Pending_coinbase.Stack.t

module Wallet : sig
  type t = { private_key : Signature_lib.Private_key.t; account : Account.t }

  val random_wallets : ?n:int -> unit -> t array

  val user_command_with_wallet :
       t array
    -> sender:int
    -> receiver:int
    -> int
    -> Currency.Fee.t
    -> Mina_numbers.Account_nonce.t
    -> Signed_command_memo.t
    -> Signed_command.With_valid_signature.t

  val user_command :
       fee_payer:t
    -> source_pk:Signature_lib.Public_key.Compressed.t
    -> receiver_pk:Signature_lib.Public_key.Compressed.t
    -> int
    -> Currency.Fee.t
    -> Mina_numbers.Account_nonce.t
    -> Mina_base.Signed_command_memo.t
    -> Mina_base.Signed_command.With_valid_signature.t
end

val check_balance : Account_id.t -> int -> Ledger.t -> unit
