(** A breadcrumb is a "full node" in the transition frontier. It contains the
 *  fully expanded state from an external transition, including the full
 *  staged ledger at that state of the blockchain.
 *)

open Async_kernel
open Core_kernel
open Signature_lib
open Coda_base
open Coda_state
open Coda_transition
open Network_peer

type t [@@deriving sexp, eq, compare, to_yojson]

type display =
  { state_hash: string
  ; blockchain_state: Blockchain_state.display
  ; consensus_state: Consensus.Data.Consensus_state.display
  ; parent: string }
[@@deriving yojson]

val create : External_transition.Validated.t -> Staged_ledger.t -> t

val build :
     logger:Logger.t
  -> precomputed_values:Precomputed_values.t
  -> verifier:Verifier.t
  -> trust_system:Trust_system.t
  -> parent:t
  -> transition:External_transition.Almost_validated.t
  -> sender:Envelope.Sender.t option
  -> ( t
     , [ `Invalid_staged_ledger_diff of Error.t
       | `Invalid_staged_ledger_hash of Error.t
       | `Fatal_error of exn ] )
     Result.t
     Deferred.t

val validated_transition : t -> External_transition.Validated.t

val staged_ledger : t -> Staged_ledger.t

val just_emitted_a_proof : t -> bool

val hash : t -> int

val blockchain_state : t -> Coda_state.Blockchain_state.Value.t

val protocol_state : t -> Coda_state.Protocol_state.Value.t

val consensus_state : t -> Consensus.Data.Consensus_state.Value.t

val blockchain_length : t -> Unsigned.UInt32.t

val state_hash : t -> State_hash.t

val parent_hash : t -> State_hash.t

val block_producer : t -> Signature_lib.Public_key.Compressed.t

val commands : t -> Command_transaction.Valid.t With_status.t list

val payments : t -> User_command.t With_status.t list

val mask : t -> Ledger.Mask.Attached.t

val all_user_commands : t list -> User_command.Set.t

val display : t -> display

val name : t -> string

module For_tests : sig
  val gen :
       ?logger:Logger.t
    -> precomputed_values:Precomputed_values.t
    -> ?verifier:Verifier.t
    -> ?trust_system:Trust_system.t
    -> accounts_with_secret_keys:(Private_key.t option * Account.t) list
    -> (t -> t Deferred.t) Quickcheck.Generator.t

  val gen_non_deferred :
       ?logger:Logger.t
    -> precomputed_values:Precomputed_values.t
    -> ?verifier:Verifier.t
    -> ?trust_system:Trust_system.t
    -> accounts_with_secret_keys:(Private_key.t option * Account.t) list
    -> (t -> t) Quickcheck.Generator.t

  val gen_seq :
       ?logger:Logger.t
    -> precomputed_values:Precomputed_values.t
    -> ?verifier:Verifier.t
    -> ?trust_system:Trust_system.t
    -> accounts_with_secret_keys:(Private_key.t option * Account.t) list
    -> int
    -> (t -> t list Deferred.t) Quickcheck.Generator.t
end
