(** A breadcrumb is a "full node" in the transition frontier. It contains the
 *  fully expanded state from an external transition, including the full
 *  staged ledger at that state of the blockchain.
 *)

open Async_kernel
open Core_kernel
open Signature_lib
open Mina_base
open Mina_state
open Network_peer

type t [@@deriving equal, compare, to_yojson]

type display =
  { state_hash : string
  ; blockchain_state : Blockchain_state.display
  ; consensus_state : Consensus.Data.Consensus_state.display
  ; parent : string
  }
[@@deriving yojson]

val create :
     validated_transition:Mina_block.Validated.t
  -> staged_ledger:Staged_ledger.t
  -> just_emitted_a_proof:bool
  -> transition_receipt_time:Time.t option
  -> accounts_created:Account_id.t list
  -> block_tag:Mina_block.Stable.Latest.t State_hash.File_storage.tag
  -> t

val build :
     ?skip_staged_ledger_verification:[ `All | `Proofs ]
  -> ?transaction_pool_proxy:Staged_ledger.transaction_pool_proxy
  -> logger:Logger.t
  -> precomputed_values:Precomputed_values.t
  -> verifier:Verifier.t
  -> trust_system:Trust_system.t
  -> parent:t
  -> transition:Mina_block.almost_valid_block
  -> get_completed_work:
       (   Transaction_snark_work.Statement.t
        -> Transaction_snark_work.Checked.t option )
  -> sender:Envelope.Sender.t option
  -> transition_receipt_time:Time.t option
  -> unit
  -> ( t
     , [> `Invalid_staged_ledger_diff of Error.t
       | `Invalid_staged_ledger_hash of Error.t
       | `Fatal_error of exn ] )
     Result.t
     Deferred.t

val contains_transaction_by_hash :
  t -> Mina_transaction.Transaction_hash.t -> bool

val header : t -> Mina_block.Header.t

val command_stats : t -> Command_stats.t

val block_tag : t -> Mina_block.Stable.Latest.t State_hash.File_storage.tag

val staged_ledger : t -> Staged_ledger.t

val just_emitted_a_proof : t -> bool

val transition_receipt_time : t -> Time.t option

val hash : t -> int

val protocol_state_with_hashes :
  t -> Mina_state.Protocol_state.Value.t State_hash.With_state_hashes.t

val protocol_state : t -> Mina_state.Protocol_state.Value.t

val consensus_state : t -> Consensus.Data.Consensus_state.Value.t

val consensus_state_with_hashes :
  t -> Consensus.Data.Consensus_state.Value.t State_hash.With_state_hashes.t

val state_hash : t -> State_hash.t

val parent_hash : t -> State_hash.t

val mask : t -> Mina_ledger.Ledger.Mask.Attached.t

val display : t -> display

val name : t -> string

val staged_ledger_hash : t -> Staged_ledger_hash.t

(** The accounts created in the block that this breadcrumb represents
    For convenience of implementation, it's by definition an empty list for the root *)
val accounts_created : t -> Account_id.t list

val delta_block_chain_proof : t -> State_hash.t Mina_stdlib.Nonempty_list.t

val staged_ledger_aux_and_pending_coinbases_cached :
  t -> Network_types.Staged_ledger_aux_and_pending_coinbases.data_tag option

val staged_ledger_aux_and_pending_coinbases :
     scan_state_protocol_states:
       (   Staged_ledger.Scan_state.t
        -> Mina_state.Protocol_state.Value.t list option )
  -> t
  -> Network_types.Staged_ledger_aux_and_pending_coinbases.data_tag option

(** Convert a breadcrumb to a block data

    Will return an exception if called on transition frontier root or
    a lite breadcrumb (i.e. one that was added to frontier).
*)
val to_block_data_exn : t -> Block_data.Full.t

(** Convert a full breadcrumb to a lite breadcrumb *)
val lighten : t -> t

(** Get the validated transition from a breadcrumb.

    Caution: operation is expensive if called on a lite
    breadcrumb (and can throw an exception on reading from
    multi-key file storage for block).
*)
val validated_transition : t -> Mina_block.Validated.t

(** Get the block with hash from a breadcrumb.

    Caution: operation is expensive if called on a lite
    breadcrumb (and can throw an exception on reading from
    multi-key file storage for block).
*)
val block_with_hash : t -> Mina_block.with_hash

(** Get the block from a breadcrumb.

    Caution: operation is expensive if called on a lite
    breadcrumb (and can throw an exception on reading from
    multi-key file storage for block).
*)
val block : t -> Mina_block.t

(** Get the command hashes from a breadcrumb
    (in order of transaction appearance in block).

    Caution: operation is expensive if called on a lite
    breadcrumb (and can throw an exception on reading from
    multi-key file storage for block).
*)
val command_hashes : t -> Mina_transaction.Transaction_hash.t list

(** Get the valid commands from a breadcrumb along with their hashes
    (in order of transaction appearance in block).

    Caution: operation is expensive if called on a lite
    breadcrumb (and can throw an exception on reading from
    multi-key file storage for block).
*)
val valid_commands_hashed :
     t
  -> Mina_transaction.Transaction_hash.User_command_with_valid_signature.t
     With_status.t
     list

val of_block_data :
     logger:Logger.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> parent_staged_ledger:Staged_ledger.t
  -> state_hash:Frozen_ledger_hash.t
  -> Block_data.Full.t
  -> (t, Staged_ledger.Staged_ledger_error.t) Deferred.Result.t

module For_tests : sig
  val gen :
       ?logger:Logger.t
    -> ?send_to_random_pk:bool
    -> precomputed_values:Precomputed_values.t
    -> verifier:Verifier.t
    -> ?trust_system:Trust_system.t
    -> accounts_with_secret_keys:(Private_key.t option * Account.t) list
    -> unit
    -> (t -> t Deferred.t) Quickcheck.Generator.t

  val gen_non_deferred :
       ?logger:Logger.t
    -> precomputed_values:Precomputed_values.t
    -> verifier:Verifier.t
    -> ?trust_system:Trust_system.t
    -> accounts_with_secret_keys:(Private_key.t option * Account.t) list
    -> unit
    -> (t -> t) Quickcheck.Generator.t

  val gen_seq :
       ?logger:Logger.t
    -> precomputed_values:Precomputed_values.t
    -> verifier:Verifier.t
    -> ?trust_system:Trust_system.t
    -> accounts_with_secret_keys:(Private_key.t option * Account.t) list
    -> int
    -> (t -> t list Deferred.t) Quickcheck.Generator.t

  val build_fail :
       ?skip_staged_ledger_verification:[ `All | `Proofs ]
    -> logger:Logger.t
    -> precomputed_values:Precomputed_values.t
    -> verifier:Verifier.t
    -> trust_system:Trust_system.t
    -> parent:t
    -> transition:Mina_block.almost_valid_block
    -> sender:Envelope.Sender.t option
    -> transition_receipt_time:Time.t option
    -> unit
    -> ( t
       , [> `Invalid_staged_ledger_diff of Error.t
         | `Invalid_staged_ledger_hash of Error.t
         | `Fatal_error of exn ] )
       Result.t
       Deferred.t
end
