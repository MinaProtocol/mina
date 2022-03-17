open Mina_base
open Snark_params

val genesis_constants : Genesis_constants.t

val proof_level : Genesis_constants.Proof_level.t

val consensus_constants : Consensus.Constants.t

(* For tests, monkey patch ledger and sparse ledger to freeze their 
   ledger_hashes.
   The nominal type prevents using this in non-test code. *)
module Ledger : module type of Mina_ledger.Ledger

module Sparse_ledger : module type of Mina_ledger.Sparse_ledger

val ledger_depth : Ledger.index

module T : Transaction_snark.S

val state_body : Transaction_protocol_state.Block_data.t

val init_stack : Pending_coinbase.Stack_versioned.t

val apply_parties : Ledger.t -> Parties.t list -> unit * unit

val dummy_rule :
     (Snapp_statement.Checked.t, 'a, 'b, 'c) Pickles.Tag.t
  -> ( Snapp_statement.Checked.t * (Snapp_statement.Checked.t * unit)
     , 'a * ('a * unit)
     , 'b * ('b * unit)
     , 'c * ('c * unit)
     , 'd
     , 'e )
     Pickles.Inductive_rule.t

(** Generates base and merge snarks of all the party segments*)
val apply_parties_with_merges :
  Ledger.t -> Parties.t list -> unit Async.Deferred.t

(** Verification key of a trivial smart contract *)
val trivial_snapp :
  ( [> `VK of (Side_loaded_verification_key.t, Tick.Field.t) With_hash.t ]
  * [> `Prover of
       ( unit
       , unit
       , unit
       , Snapp_statement.t
       , (Pickles_types.Nat.N2.n, Pickles_types.Nat.N2.n) Pickles.Proof.t
         Async.Deferred.t )
       Pickles.Prover.t ] )
  Lazy.t

val gen_snapp_ledger :
  (Transaction_logic.For_tests.Test_spec.t * Signature_lib.Keypair.t)
  Base_quickcheck.Generator.t

val test_snapp_update :
     ?snapp_permissions:Permissions.t
  -> vk:(Side_loaded_verification_key.t, Tick.Field.t) With_hash.t
  -> snapp_prover:
       ( unit
       , unit
       , unit
       , Snapp_statement.t
       , (Pickles_types.Nat.N2.n, Pickles_types.Nat.N2.n) Pickles.Proof.t
         Async.Deferred.t )
       Pickles.Prover.t
  -> Transaction_snark.For_tests.Spec.t
  -> init_ledger:Transaction_logic.For_tests.Init_ledger.t
  -> snapp_pk:Account.key
  -> unit

val permissions_from_update :
     Party.Update.t
  -> auth:Permissions.Auth_required.t
  -> Permissions.Auth_required.t Permissions.Poly.t
