open Async_kernel
open Core
open Coda_base
open Coda_state
open Coda_transition
open Pipe_lib
open Signature_lib
module Config = Config
module Subscriptions = Coda_subscriptions

type t

exception Snark_worker_error of int

exception Snark_worker_signal_interrupt of Signal.t

val subscription : t -> Coda_subscriptions.t

(** Derived from local state (aka they may not reflect the latest public keys to which you've attempted to change *)
val propose_public_keys : t -> Public_key.Compressed.Set.t

val replace_propose_keypairs : t -> Keypair.And_compressed_pk.Set.t -> unit

val replace_snark_worker_key :
  t -> Public_key.Compressed.t option -> unit Deferred.t

val add_block_subscriber :
     t
  -> Public_key.Compressed.t
  -> ( Auxiliary_database.Filtered_external_transition.t
     , State_hash.t )
     With_hash.t
     Pipe.Reader.t

val add_payment_subscriber : t -> Account.key -> User_command.t Pipe.Reader.t

val snark_worker_key : t -> Public_key.Compressed.Stable.V1.t option

val snark_work_fee : t -> Currency.Fee.t

val set_snark_work_fee : t -> Currency.Fee.t -> unit

val request_work : t -> Snark_worker.Work.Spec.t option

val add_work : t -> Snark_worker.Work.Result.t -> unit Deferred.t

val best_staged_ledger : t -> Staged_ledger.t Participating_state.t

val best_ledger : t -> Ledger.t Participating_state.t

val root_length : t -> int Participating_state.t

val best_protocol_state : t -> Protocol_state.Value.t Participating_state.t

val best_tip : t -> Transition_frontier.Breadcrumb.t Participating_state.t

val sync_status : t -> Sync_status.t Coda_incremental.Status.Observer.t

val visualize_frontier : filename:string -> t -> unit Participating_state.t

val peers : t -> Network_peer.Peer.t list

val initial_peers : t -> Host_and_port.t list

val client_port : t -> int

val validated_transitions :
  t -> External_transition.Validated.t Strict_pipe.Reader.t

val root_diff :
  t -> Transition_frontier.Diff.Root_diff.view Strict_pipe.Reader.t

val dump_tf : t -> string Or_error.t

val best_path : t -> State_hash.t list option

val transaction_pool : t -> Network_pool.Transaction_pool.t

val transaction_database : t -> Auxiliary_database.Transaction_database.t

val external_transition_database :
  t -> Auxiliary_database.External_transition_database.t

val snark_pool : t -> Network_pool.Snark_pool.t

val start : t -> unit Deferred.t

val stop_snark_worker : ?should_wait_kill:bool -> t -> unit Deferred.t

val create : Config.t -> t Deferred.t

val staged_ledger_ledger_proof : t -> Ledger_proof.t option

val transition_frontier :
  t -> Transition_frontier.t option Broadcast_pipe.Reader.t

val get_ledger :
  t -> Staged_ledger_hash.t option -> Account.t list Deferred.Or_error.t

val receipt_chain_database : t -> Receipt_chain_database.t

val wallets : t -> Secrets.Wallets.t

val most_recent_valid_transition :
  t -> External_transition.t Broadcast_pipe.Reader.t

val top_level_logger : t -> Logger.t

val config : t -> Config.t

val net : t -> Coda_networking.t
