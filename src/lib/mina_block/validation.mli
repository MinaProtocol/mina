open Async_kernel
open Core_kernel
open Mina_base
open Mina_state

(* TODO: this may be re-done with the new body header split *)

(* By redefining a type alias in this module, and then rewriting that type alias in
   the signature of the type module before it is included, we effectively obscure the
   underlying type definition from external code (since the type module is not directly
   exported from this library). It is important to hide this specific type externally,
   as otherwise external code using the library could just freely manipulate the
   validation state without using this library as intended. *)
include module type of Validation_types

module type CONTEXT = sig
  val logger : Logger.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t
end

val validation :
  ('a, 'b, 'c, 'd, 'e, 'f, 'g) with_block -> ('a, 'b, 'c, 'd, 'e, 'f, 'g) t

val header_with_hash : _ with_header -> Header.with_hash

val block_with_hash : _ with_block -> Block.with_hash

val block : _ with_block -> Block.t

val header : _ with_header -> Header.t

val to_header :
     ('a, 'b, 'c, 'd, 'e, 'f, 'g) with_block
  -> ('a, 'b, 'c, 'd, 'e, 'f, 'g) with_header

val wrap : Block.with_hash -> fully_invalid_with_block

val wrap_header : Header.with_hash -> fully_invalid_with_header

val validate_time_received :
     precomputed_values:Precomputed_values.t
  -> time_received:Block_time.t
  -> ( [ `Time_received ] * unit Truth.false_t
     , 'a
     , 'b
     , 'c
     , 'd
     , 'e
     , 'f )
     with_header
  -> ( ( [ `Time_received ] * unit Truth.true_t
       , 'a
       , 'b
       , 'c
       , 'd
       , 'e
       , 'f )
       with_header
     , [> `Invalid_time_received of [ `Too_early | `Too_late of int64 ] ] )
     Result.t

val skip_time_received_validation :
     [ `This_block_was_not_received_via_gossip ]
  -> ( [ `Time_received ] * unit Truth.false_t
     , 'a
     , 'b
     , 'c
     , 'd
     , 'e
     , 'f )
     with_block
  -> ([ `Time_received ] * unit Truth.true_t, 'a, 'b, 'c, 'd, 'e, 'f) with_block

val validate_genesis_protocol_state :
     genesis_state_hash:State_hash.t
  -> ( 'a
     , [ `Genesis_state ] * unit Truth.false_t
     , 'b
     , 'c
     , 'd
     , 'e
     , 'f )
     with_header
  -> ( ( 'a
       , [ `Genesis_state ] * unit Truth.true_t
       , 'b
       , 'c
       , 'd
       , 'e
       , 'f )
       with_header
     , [> `Invalid_genesis_protocol_state ] )
     Result.t

val skip_genesis_protocol_state_validation :
     [ `This_block_was_generated_internally ]
  -> ( 'a
     , [ `Genesis_state ] * unit Truth.false_t
     , 'b
     , 'c
     , 'd
     , 'e
     , 'f )
     with_block
  -> ('a, [ `Genesis_state ] * unit Truth.true_t, 'b, 'c, 'd, 'e, 'f) with_block

val reset_genesis_protocol_state_validation :
     ('a, [ `Genesis_state ] * unit Truth.true_t, 'b, 'c, 'd, 'e, 'f) with_block
  -> ( 'a
     , [ `Genesis_state ] * unit Truth.false_t
     , 'b
     , 'c
     , 'd
     , 'e
     , 'f )
     with_block

val validate_proofs :
     verifier:Verifier.t
  -> genesis_state_hash:State_hash.t
  -> ('a, 'b, [ `Proof ] * unit Truth.false_t, 'c, 'd, 'e, 'f) with_header list
  -> ( ('a, 'b, [ `Proof ] * unit Truth.true_t, 'c, 'd, 'e, 'f) with_header list
     , [> `Invalid_proof | `Verifier_error of Error.t ] )
     Deferred.Result.t

val validate_single_proof :
     verifier:Verifier.t
  -> genesis_state_hash:State_hash.t
  -> ('a, 'b, [ `Proof ] * unit Truth.false_t, 'c, 'd, 'e, 'f) with_header
  -> ( ('a, 'b, [ `Proof ] * unit Truth.true_t, 'c, 'd, 'e, 'f) with_header
     , [> `Invalid_proof | `Verifier_error of Error.t ] )
     Deferred.Result.t

val skip_proof_validation :
     [ `This_block_was_generated_internally ]
  -> ('a, 'b, [ `Proof ] * unit Truth.false_t, 'c, 'd, 'e, 'f) with_block
  -> ('a, 'b, [ `Proof ] * unit Truth.true_t, 'c, 'd, 'e, 'f) with_block

val extract_delta_block_chain_witness :
     ( 'a
     , 'b
     , 'c
     , [ `Delta_block_chain ] * State_hash.t Non_empty_list.t Truth.true_t
     , 'd
     , 'e
     , 'f )
     t
  -> State_hash.t Non_empty_list.t

val validate_delta_block_chain :
     ( 'a
     , 'b
     , 'c
     , [ `Delta_block_chain ] * State_hash.t Non_empty_list.t Truth.false_t
     , 'd
     , 'e
     , 'f )
     with_header
  -> ( ( 'a
       , 'b
       , 'c
       , [ `Delta_block_chain ] * State_hash.t Non_empty_list.t Truth.true_t
       , 'd
       , 'e
       , 'f )
       with_header
     , [> `Invalid_delta_block_chain_proof ] )
     Result.t

val skip_delta_block_chain_validation :
     [ `This_block_was_not_received_via_gossip ]
  -> ( 'a
     , 'b
     , 'c
     , [ `Delta_block_chain ] * State_hash.t Non_empty_list.t Truth.false_t
     , 'd
     , 'e
     , 'f )
     with_block
  -> ( 'a
     , 'b
     , 'c
     , [ `Delta_block_chain ] * State_hash.t Non_empty_list.t Truth.true_t
     , 'd
     , 'e
     , 'f )
     with_block

val validate_frontier_dependencies :
     to_header:('a -> Header.t)
  -> context:(module CONTEXT)
  -> root_block:Block.with_hash
  -> is_block_in_frontier:(Frozen_ledger_hash.t -> bool)
  -> ('a, State_hash.State_hashes.t) With_hash.t
     * ( 'b
       , 'c
       , 'd
       , 'e
       , [ `Frontier_dependencies ] * unit Truth.false_t
       , 'f
       , 'g )
       t
  -> ( ('a, State_hash.State_hashes.t) With_hash.t
       * ( 'b
         , 'c
         , 'd
         , 'e
         , [ `Frontier_dependencies ] * unit Truth.true_t
         , 'f
         , 'g )
         t
     , [> `Already_in_frontier
       | `Not_selected_over_frontier_root
       | `Parent_missing_from_frontier ] )
     Result.t

val skip_frontier_dependencies_validation :
     [ `This_block_belongs_to_a_detached_subtree
     | `This_block_was_loaded_from_persistence ]
  -> ( 'a
     , 'b
     , 'c
     , 'd
     , [ `Frontier_dependencies ] * unit Truth.false_t
     , 'e
     , 'f )
     with_block
  -> ( 'a
     , 'b
     , 'c
     , 'd
     , [ `Frontier_dependencies ] * unit Truth.true_t
     , 'e
     , 'f )
     with_block

val reset_frontier_dependencies_validation :
     'g
     * ( 'a
       , 'b
       , 'c
       , 'd
       , [ `Frontier_dependencies ] * unit Truth.true_t
       , 'e
       , 'f )
       t
  -> 'g
     * ( 'a
       , 'b
       , 'c
       , 'd
       , [ `Frontier_dependencies ] * unit Truth.false_t
       , 'e
       , 'f )
       t

val validate_staged_ledger_diff :
     ?skip_staged_ledger_verification:[ `All | `Proofs ]
  -> logger:Logger.t
  -> precomputed_values:Genesis_proof.t
  -> verifier:Verifier.t
  -> parent_staged_ledger:Staged_ledger.t
  -> parent_protocol_state:Protocol_state.Value.t
  -> ( 'a
     , 'b
     , 'c
     , 'd
     , 'e
     , [ `Staged_ledger_diff ] * unit Truth.false_t
     , 'f )
     with_block
  -> ( [ `Just_emitted_a_proof of bool ]
       * [ `Block_with_validation of
           ( 'a
           , 'b
           , 'c
           , 'd
           , 'e
           , [ `Staged_ledger_diff ] * unit Truth.true_t
           , 'f )
           with_block ]
       * [ `Staged_ledger of Staged_ledger.t ]
     , [> `Staged_ledger_application_failed of
          Staged_ledger.Staged_ledger_error.t
       | `Invalid_body_reference
       | `Invalid_staged_ledger_diff of
         [ `Incorrect_target_staged_ledger_hash
         | `Incorrect_target_snarked_ledger_hash ]
         list ] )
     Deferred.Result.t

val validate_staged_ledger_hash :
     [ `Staged_ledger_already_materialized of Staged_ledger_hash.t ]
  -> ( 'a
     , 'b
     , 'c
     , 'd
     , 'e
     , [ `Staged_ledger_diff ] * unit Truth.false_t
     , 'f )
     with_block
  -> ( ( 'a
       , 'b
       , 'c
       , 'd
       , 'e
       , [ `Staged_ledger_diff ] * unit Truth.true_t
       , 'f )
       with_block
     , [> `Staged_ledger_hash_mismatch ] )
     Result.t

val skip_staged_ledger_diff_validation :
     [ `This_block_has_a_trusted_staged_ledger ]
  -> ( 'a
     , 'b
     , 'c
     , 'd
     , 'e
     , [ `Staged_ledger_diff ] * unit Truth.false_t
     , 'f )
     with_block
  -> ( 'a
     , 'b
     , 'c
     , 'd
     , 'e
     , [ `Staged_ledger_diff ] * unit Truth.true_t
     , 'f )
     with_block

val reset_staged_ledger_diff_validation :
     'g * ('a, 'b, 'c, 'd, 'e, [ `Staged_ledger_diff ] * unit Truth.true_t, 'f) t
  -> 'g
     * ('a, 'b, 'c, 'd, 'e, [ `Staged_ledger_diff ] * unit Truth.false_t, 'f) t

val validate_protocol_versions :
     ( 'a
     , 'b
     , 'c
     , 'd
     , 'e
     , 'f
     , [ `Protocol_versions ] * unit Truth.false_t )
     with_header
  -> ( ( 'a
       , 'b
       , 'c
       , 'd
       , 'e
       , 'f
       , [ `Protocol_versions ] * unit Truth.true_t )
       with_header
     , [> `Invalid_protocol_version | `Mismatched_protocol_version ] )
     Result.t

val skip_protocol_versions_validation :
     [ `This_block_has_valid_protocol_versions ]
  -> ( 'a
     , 'b
     , 'c
     , 'd
     , 'e
     , 'f
     , [ `Protocol_versions ] * unit Truth.false_t )
     with_block
  -> ( 'a
     , 'b
     , 'c
     , 'd
     , 'e
     , 'f
     , [ `Protocol_versions ] * unit Truth.true_t )
     with_block

val with_body :
     ( 'a
     , 'b
     , 'c
     , 'd
     , 'e
     , [ `Staged_ledger_diff ] * unit Truth.false_t
     , 'f )
     with_header
  -> Staged_ledger_diff.Body.t
  -> ( 'a
     , 'b
     , 'c
     , 'd
     , 'e
     , [ `Staged_ledger_diff ] * unit Truth.false_t
     , 'f )
     with_block
