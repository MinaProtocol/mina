open Core
open Async_kernel
open Pipe_lib
open Mina_base
open Network_peer
module Root_ledger = Mina_ledger.Root

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t

  val ledger_sync_config : Syncable_ledger.daemon_config

  val proof_cache_db : Proof_cache_tag.cache_db

  val signature_kind : Mina_signature_kind.t
end

(** Interface that allows a peer to prove their best_tip in the
    transition_frontier *)
module type Best_tip_prover_intf = sig
  module type CONTEXT = sig
    val logger : Logger.t
  end

  type transition_frontier

  val prove :
       context:(module CONTEXT)
    -> transition_frontier
    -> ( Frontier_base.Breadcrumb.t
       , State_body_hash.t list * Frontier_base.Breadcrumb.t )
       Proof_carrying_data.t
       option

  val verify :
       verifier:Verifier.t
    -> genesis_constants:Genesis_constants.t
    -> precomputed_values:Precomputed_values.t
    -> ( Mina_block.Header.t
       , State_body_hash.t list * Mina_block.Header.t )
       Proof_carrying_data.t
    -> ( [ `Root of Mina_block.initial_valid_header ]
       * [ `Best_tip of Mina_block.initial_valid_header ] )
       Deferred.Or_error.t
end

(** Interface that allows a peer to prove their best_tip in the
    transition_frontier based off of a condition on the consensus_state from
    the requesting node *)
module type Consensus_best_tip_prover_intf = sig
  type transition_frontier

  val prove :
       context:(module CONTEXT)
    -> frontier:transition_frontier
    -> Consensus.Data.Consensus_state.Value.t State_hash.With_state_hashes.t
    -> ( Frontier_base.Breadcrumb.t
       , State_body_hash.t list * Frontier_base.Breadcrumb.t )
       Proof_carrying_data.t
       option

  val verify :
       context:(module CONTEXT)
    -> verifier:Verifier.t
    -> Consensus.Data.Consensus_state.Value.t State_hash.With_state_hashes.t
    -> ( Mina_block.Header.t
       , State_body_hash.t list * Mina_block.Header.t )
       Proof_carrying_data.t
    -> ( [ `Root of Mina_block.initial_valid_header ]
       * [ `Best_tip of Mina_block.initial_valid_header ] )
       Deferred.Or_error.t
end

module type Sync_handler_intf = sig
  type transition_frontier

  val answer_query :
       frontier:transition_frontier
    -> Ledger_hash.t
    -> Mina_ledger.Sync_ledger.Query.t Envelope.Incoming.t
    -> context:(module CONTEXT)
    -> trust_system:Trust_system.t
    -> Mina_ledger.Sync_ledger.Answer.t Or_error.t Deferred.t

  val get_staged_ledger_aux_and_pending_coinbases_at_hash :
       logger:Logger.t
    -> frontier:transition_frontier
    -> State_hash.t
    -> ( Staged_ledger.Scan_state.t
       * Ledger_hash.t
       * Pending_coinbase.t
       * Mina_state.Protocol_state.value list )
       Option.t

  val get_transition_chain :
       frontier:transition_frontier
    -> State_hash.t list
    -> Mina_block.t list option

  val best_tip_path : frontier:transition_frontier -> State_hash.t list

  (** Allows a peer to prove to a node that they can bootstrap from transition
      that they have gossiped to the network *)
  module Root :
    Consensus_best_tip_prover_intf
      with type transition_frontier := transition_frontier
end

module type Transition_chain_prover_intf = sig
  type transition_frontier

  val prove :
       ?length:int
    -> frontier:transition_frontier
    -> State_hash.t
    -> (State_hash.t * State_body_hash.t list) option
end

module type Transition_router_intf = sig
  type transition_frontier

  type transition_frontier_persistent_root

  type transition_frontier_persistent_frontier

  type breadcrumb

  type network

  (** [sync_local_state] is `true` by default, may be set to `false` for tests.
      Returns the valid transitions, a signal filled once the router has
      initialized, and a function that stops the frontier controller, if it
      is running, and is determined once it has drained, so that its frontier
      can be closed. *)
  val run :
       ?sync_local_state:bool
    -> ?cache_exceptions:bool
    -> ?transaction_pool_proxy:Staged_ledger.transaction_pool_proxy
    -> context:(module CONTEXT)
    -> trust_system:Trust_system.t
    -> verifier:Verifier.t
    -> network:network
    -> is_seed:bool
    -> is_demo_mode:bool
    -> time_controller:Block_time.Controller.t
    -> consensus_local_state:Consensus.Data.Local_state.t
    -> persistent_root_location:string
    -> persistent_frontier_location:string
    -> get_current_frontier:(unit -> transition_frontier option)
    -> frontier_broadcast_writer:
         transition_frontier option Pipe_lib.Broadcast_pipe.Writer.t
    -> network_transition_reader:
         ( [ `Block of Mina_block.Stable.Latest.t Envelope.Incoming.t
           | `Header of Mina_block.Header.Stable.Latest.t Envelope.Incoming.t
           ]
         * [ `Time_received of Block_time.t ]
         * [ `Valid_cb of Mina_net2.Validation_callback.t ] )
         Strict_pipe.Reader.t
    -> producer_transition_reader:breadcrumb Strict_pipe.Reader.t
    -> get_most_recent_valid_block:(unit -> Mina_block.initial_valid_header)
    -> most_recent_valid_block_writer:
         Mina_block.initial_valid_header Broadcast_pipe.Writer.t
    -> get_completed_work:
         (   Transaction_snark_work.Statement.t
          -> Transaction_snark_work.Checked.t option )
    -> notify_online:(unit -> unit Deferred.t)
    -> ledger_backing:Mina_ledger.Root.Config.backing_type
    -> bootstrap_status:Bootstrap_status.t
    -> unit
    -> ( [ `Transition of Mina_block.Validated.t ]
       * [ `Source of [ `Gossip | `Catchup | `Internal ] ]
       * [ `Valid_cb of Mina_net2.Validation_callback.t option ] )
       Strict_pipe.Reader.t
       * unit Ivar.t
       * (unit -> unit Deferred.t)
end
