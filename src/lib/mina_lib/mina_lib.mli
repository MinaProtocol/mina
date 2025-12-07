(** Core logic of the Mina protocol daemon.

    This module orchestrates ledger, consensus, networking, and state management.
    Used by [Mina_run], CLI tools, and other services to operate a Mina node.

    See {!val:create} for initialization and subprocess details. *)

open Async_kernel
open Core
open Mina_base
open Mina_state
open Pipe_lib
open Signature_lib
module Archive_client = Archive_client
module Config = Config
module Conf_dir = Conf_dir
module Subscriptions = Mina_subscriptions
module Root_ledger = Mina_ledger.Root

type t

type Structured_log_events.t +=
  | Connecting
  | Listening
  | Bootstrapping
  | Ledger_catchup
  | Synced
  | Rebroadcast_transition of { state_hash : State_hash.t }
  [@@deriving register_event]

module type CONTEXT = sig
  val logger : Logger.t

  val time_controller : Block_time.Controller.t

  val trust_system : Trust_system.t

  val consensus_local_state : Consensus.Data.Local_state.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t

  val commit_id : string

  val vrf_poll_interval : Time.Span.t

  val zkapp_cmd_limit : int option ref

  val compaction_interval : Time.Span.t option

  val ledger_sync_config : Syncable_ledger.daemon_config

  val proof_cache_db : Proof_cache_tag.cache_db

  val signature_kind : Mina_signature_kind.t
end

exception Snark_worker_error of int

exception Snark_worker_signal_interrupt of Signal.t

exception Offline_shutdown

exception Bootstrap_stuck_shutdown

val time_controller : t -> Block_time.Controller.t

val subscription : t -> Mina_subscriptions.t

val commit_id : t -> string

val daemon_start_time : Time_ns.t

(** Derived from local state (aka they may not reflect the latest public keys to which you've attempted to change *)
val block_production_pubkeys : t -> Public_key.Compressed.Set.t

val coinbase_receiver : t -> Consensus.Coinbase_receiver.t

val replace_coinbase_receiver : t -> Consensus.Coinbase_receiver.t -> unit

val next_producer_timing :
  t -> Daemon_rpcs.Types.Status.Next_producer_timing.t option

val staking_ledger :
  t -> Consensus.Data.Local_state.Snapshot.Ledger_snapshot.t option

val next_epoch_ledger :
     t
  -> [ `Finalized of Consensus.Data.Local_state.Snapshot.Ledger_snapshot.t
     | `Notfinalized ]
     option

val current_epoch_delegators :
  t -> pk:Public_key.Compressed.t -> Mina_base.Account.t list option

val last_epoch_delegators :
  t -> pk:Public_key.Compressed.t -> Mina_base.Account.t list option

(** [replace_snark_worker_key t key_opt] Replace all SNARK worker's key
    associated with current coordinator.
    - If the new key is [None], SNARK worker will be turned off if it's running;
    - If the new key is [Some k], SNARK worker will be turn on if it's not running. *)
val replace_snark_worker_key :
  t -> Public_key.Compressed.t option -> unit Deferred.t

val add_block_subscriber :
     t
  -> Public_key.Compressed.t option
  -> (Filtered_external_transition.t, State_hash.t) With_hash.t Pipe.Reader.t

val add_payment_subscriber : t -> Account.key -> Signed_command.t Pipe.Reader.t

val snark_worker_key : t -> Public_key.Compressed.t option

val snark_coordinator_key : t -> Public_key.Compressed.t option

val snark_work_fee : t -> Currency.Fee.t

val set_snark_work_fee : t -> Currency.Fee.t -> unit

val request_work :
     t
  -> ( Snark_work_lib.Spec.Partitioned.Stable.Latest.t
     , Work_partitioner.Snark_worker_shared.Failed_to_generate_inputs.t )
     Result.t
     option

val work_selection_method : t -> (module Work_selector.Selection_method_intf)

val add_work :
     t
  -> Snark_work_lib.Result.Partitioned.Stable.Latest.t
  -> [> `Ok | `Removed | `SpecUnmatched ]

val add_work_graphql :
     t
  -> Network_pool.Snark_pool.Resource_pool.Diff.t
  -> ( [ `Broadcasted | `Not_broadcasted ]
     * Network_pool.Snark_pool.Resource_pool.Diff.t
     * Network_pool.Snark_pool.Resource_pool.Diff.rejected )
     Deferred.Or_error.t

val work_selector : t -> Work_selector.State.t

val get_current_nonce :
     t
  -> Account_id.t
  -> ([> `Min of Account.Nonce.t ] * Account.Nonce.t, string) result

val add_transactions :
     t
  -> User_command_input.t list
  -> ( [ `Broadcasted | `Not_broadcasted ]
     * Network_pool.Transaction_pool.Resource_pool.Diff.t
     * Network_pool.Transaction_pool.Resource_pool.Diff.Rejected.t )
     Deferred.Or_error.t

val add_full_transactions :
     t
  -> User_command.Stable.Latest.t list
  -> ( [ `Broadcasted | `Not_broadcasted ]
     * Network_pool.Transaction_pool.Resource_pool.Diff.t
     * Network_pool.Transaction_pool.Resource_pool.Diff.Rejected.t )
     Deferred.Or_error.t

val add_zkapp_transactions :
     t
  -> Zkapp_command.Stable.Latest.t list
  -> ( [ `Broadcasted | `Not_broadcasted ]
     * Network_pool.Transaction_pool.Resource_pool.Diff.t
     * Network_pool.Transaction_pool.Resource_pool.Diff.Rejected.t )
     Deferred.Or_error.t

val get_account : t -> Account_id.t -> Account.t option Participating_state.T.t

val get_inferred_nonce_from_transaction_pool_and_ledger :
  t -> Account_id.t -> Account.Nonce.t option Participating_state.t

val active_or_bootstrapping : t -> unit Participating_state.t

val get_node_state : t -> Node_error_service.node_state Deferred.t

val best_staged_ledger : t -> Staged_ledger.t Participating_state.t

val best_ledger : t -> Mina_ledger.Ledger.t Participating_state.t

val root_length : t -> int Participating_state.t

val best_protocol_state : t -> Protocol_state.Value.t Participating_state.t

val best_tip : t -> Transition_frontier.Breadcrumb.t Participating_state.t

val sync_status : t -> Sync_status.t Mina_incremental.Status.Observer.t

val visualize_frontier : filename:string -> t -> unit Participating_state.t

val peers : t -> Network_peer.Peer.t list Deferred.t

val initial_peers : t -> Mina_net2.Multiaddr.t list

val client_port : t -> int

val validated_transitions : t -> Mina_block.Validated.t Strict_pipe.Reader.t

val initialization_finish_signal : t -> unit Ivar.t

val dump_tf : t -> string Or_error.t

val best_path : t -> State_hash.t list option

val best_chain :
  ?max_length:int -> t -> Transition_frontier.Breadcrumb.t list option

val transaction_pool : t -> Network_pool.Transaction_pool.t

val snark_pool : t -> Network_pool.Snark_pool.t

val start : t -> unit Deferred.t

val start_with_precomputed_blocks :
  t -> Mina_block.Precomputed.t Sequence.t -> unit Deferred.t

val stop_snark_worker : ?should_wait_kill:bool -> t -> unit Deferred.t

(** Create and initialize the Mina daemon.

    {2 Subprocesses}

    Spawns child processes via [Rpc_parallel]:

    - {b Prover} ([Prover.t]): Generates SNARK proofs for transactions and blocks.
      Runs in separate process due to high memory/CPU requirements.
    - {b Verifier} ([Verifier.t]): Verifies signatures, transaction SNARKs, and
      blockchain SNARKs. See [Verifier] module for architecture details.
    - {b VRF evaluator} ([Vrf_evaluator.t]): Evaluates VRF for block production
      slot determination.
    - {b Snark worker} (optional): Generates SNARK proofs for the snark pool.
      Can be enabled/disabled at runtime.
    - {b Uptime snark worker} (optional): Specialized worker for uptime service.

    These are stored in the [processes] record and passed to components like
    [Block_producer], [Transaction_pool], [Snark_pool], and [Transition_frontier].

    {2 Components initialized}

    - [Transaction_pool]: Mempool for pending transactions
    - [Snark_pool]: Pool of completed SNARK work
    - [Transition_frontier]: Recent block history for consensus
    - Networking via [Mina_networking] *)
val create :
  commit_id:string -> ?wallets:Secrets.Wallets.t -> Config.t -> t Deferred.t

val transition_frontier :
  t -> Transition_frontier.t option Broadcast_pipe.Reader.t

val get_ledger : t -> State_hash.t option -> Account.t list Deferred.Or_error.t

val get_snarked_ledger_full :
  t -> State_hash.t option -> Mina_ledger.Ledger.t Deferred.Or_error.t

val get_snarked_ledger :
  t -> State_hash.t option -> Account.t list Deferred.Or_error.t

val wallets : t -> Secrets.Wallets.t

val subscriptions : t -> Mina_subscriptions.t

val most_recent_valid_transition :
  t -> Mina_block.initial_valid_header Broadcast_pipe.Reader.t

val block_produced_bvar :
  t -> (Transition_frontier.Breadcrumb.t, read_write) Bvar.t

val top_level_logger : t -> Logger.t

val config : t -> Config.t

val net : t -> Mina_networking.t

val runtime_config : t -> Runtime_config.t

val compile_config : t -> Mina_compile_config.t

val start_filtered_log : t -> string list -> unit Or_error.t

val get_filtered_log_entries : t -> int -> string list * bool

val prover : t -> Prover.t

val vrf_evaluator : t -> Vrf_evaluator.t

val genesis_ledger : t -> Mina_ledger.Ledger.t Lazy.t

val vrf_evaluation_state : t -> Block_producer.Vrf_evaluation_state.t

val best_chain_block_by_height :
  t -> Unsigned.UInt32.t -> Transition_frontier.Breadcrumb.t Or_error.t

val best_chain_block_by_state_hash :
  t -> State_hash.t -> Transition_frontier.Breadcrumb.t Or_error.t

module Hardfork_config : sig
  type mina_lib = t

  type breadcrumb_spec =
    [ `Stop_slot
    | `State_hash of State_hash.t
    | `Block_height of Unsigned.UInt32.t ]

  val breadcrumb :
       breadcrumb_spec:breadcrumb_spec
    -> mina_lib
    -> Transition_frontier.Breadcrumb.t Deferred.Or_error.t

  (** The ledgers that will be used to compute the hard fork genesis ledgers.
      Note that a [Mina_ledger.Ledger.t] here, like the [staged_ledger] or
      (potentially) the [next_epoch_ledger], must have the [root_snarked_ledger]
      as its root. *)
  type genesis_source_ledgers =
    { root_snarked_ledger : Root_ledger.t
    ; staged_ledger : Mina_ledger.Ledger.t
    ; staking_ledger :
        [ `Genesis of Genesis_ledger.Packed.t | `Root of Root_ledger.t ]
    ; next_epoch_ledger :
        [ `Genesis of Genesis_ledger.Packed.t
        | `Root of Root_ledger.t
        | `Uncommitted of Mina_ledger.Ledger.t ]
    }

  val genesis_source_ledger_cast :
       [< `Genesis of Genesis_ledger.Packed.t
       | `Root of Root_ledger.t
       | `Uncommitted of Mina_ledger.Ledger.t ]
    -> Mina_ledger.Ledger.Any_ledger.witness

  (** Retrieve the [genesis_source_ledgers] from the transition frontier,
      starting at the given [breadcrumb]. *)
  val source_ledgers :
       breadcrumb:Transition_frontier.Breadcrumb.t
    -> mina_lib
    -> genesis_source_ledgers Deferred.Or_error.t

  type inputs =
    { source_ledgers : genesis_source_ledgers
    ; global_slot_since_genesis : Mina_numbers.Global_slot_since_genesis.t
    ; genesis_state_timestamp : string
    ; state_hash : State_hash.t
    ; staking_epoch_seed : Epoch_seed.t
    ; next_epoch_seed : Epoch_seed.t
    ; blockchain_length : Mina_numbers.Length.t
    }

  val prepare_inputs :
    breadcrumb_spec:breadcrumb_spec -> mina_lib -> inputs Deferred.Or_error.t

  (** Compute a full hard fork config (genesis ledger, genesis epoch ledgers,
      and node config) both without hard fork ledger migrations applied (the
      "legacy" format, compatible with the current daemon) and with the hard
      fork ledger migrations applied (the actual hard fork format, compatible
      with a hard fork daemon). The legacy format config will be saved in
      [daemon.legacy.json] and [genesis_legacy/] in [directory_name], and the
      hard fork format files will be saved in [daemon.json] and [genesis/] in
      that same directory. An empty [activated] file will be created in
      [directory_name] at the very end of this process to indicate that the
      config was generated successfully. *)
  val dump_reference_config :
       breadcrumb_spec:breadcrumb_spec
    -> config_dir:string
    -> generate_fork_validation:bool
    -> mina_lib
    -> unit Deferred.Or_error.t
end

val zkapp_cmd_limit : t -> int option ref

val proof_cache_db : t -> Proof_cache_tag.cache_db

val signature_kind : t -> Mina_signature_kind.t
