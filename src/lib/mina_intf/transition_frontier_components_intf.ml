open Core
open Async_kernel
open Pipe_lib
open Cache_lib
open Mina_base
open Network_peer

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t
end

module type Transition_handler_validator_intf = sig
  type unprocessed_transition_cache

  type transition_frontier

  val run :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> time_controller:Block_time.Controller.t
    -> frontier:transition_frontier
    -> transition_reader:
         Mina_block.initial_valid_block Envelope.Incoming.t Strict_pipe.Reader.t
    -> valid_transition_writer:
         ( ( Mina_block.initial_valid_block Envelope.Incoming.t
           , State_hash.t )
           Cached.t
         , Strict_pipe.drop_head Strict_pipe.buffered
         , unit )
         Strict_pipe.Writer.t
    -> unprocessed_transition_cache:unprocessed_transition_cache
    -> unit

  val validate_transition :
       logger:Logger.t
    -> frontier:transition_frontier
    -> unprocessed_transition_cache:unprocessed_transition_cache
    -> Mina_block.initial_valid_block Envelope.Incoming.t
    -> ( ( Mina_block.initial_valid_block Envelope.Incoming.t
         , State_hash.t )
         Cached.t
       , [> `In_frontier of State_hash.t
         | `In_process of State_hash.t Cache_lib.Intf.final_state
         | `Disconnected ] )
       Result.t
end

module type Breadcrumb_builder_intf = sig
  type transition_frontier

  type transition_frontier_breadcrumb

  val build_subtrees_of_breadcrumbs :
       logger:Logger.t
    -> verifier:Verifier.t
    -> trust_system:Trust_system.t
    -> frontier:transition_frontier
    -> initial_hash:State_hash.t
    -> ( Mina_block.initial_valid_block Envelope.Incoming.t
       , State_hash.t )
       Cached.t
       Rose_tree.t
       List.t
    -> (transition_frontier_breadcrumb, State_hash.t) Cached.t Rose_tree.t
       List.t
       Deferred.Or_error.t
end

module type Transition_handler_processor_intf = sig
  type transition_frontier

  type transition_frontier_breadcrumb

  val run :
       logger:Logger.t
    -> verifier:Verifier.t
    -> trust_system:Trust_system.t
    -> time_controller:Block_time.Controller.t
    -> frontier:transition_frontier
    -> primary_transition_reader:
         ( Mina_block.initial_valid_block Envelope.Incoming.t
         , State_hash.t )
         Cached.t
         Strict_pipe.Reader.t
    -> producer_transition_reader:
         transition_frontier_breadcrumb Strict_pipe.Reader.t
    -> clean_up_catchup_scheduler:unit Ivar.t
    -> catchup_job_writer:
         ( State_hash.t
           * ( Mina_block.initial_valid_block Envelope.Incoming.t
             , State_hash.t )
             Cached.t
             Rose_tree.t
             list
         , Strict_pipe.crash Strict_pipe.buffered
         , unit )
         Strict_pipe.Writer.t
    -> catchup_breadcrumbs_reader:
         ( (transition_frontier_breadcrumb, State_hash.t) Cached.t Rose_tree.t
           list
         * [ `Ledger_catchup of unit Ivar.t | `Catchup_scheduler ] )
         Strict_pipe.Reader.t
    -> catchup_breadcrumbs_writer:
         ( (transition_frontier_breadcrumb, State_hash.t) Cached.t Rose_tree.t
           list
           * [ `Ledger_catchup of unit Ivar.t | `Catchup_scheduler ]
         , Strict_pipe.crash Strict_pipe.buffered
         , unit )
         Strict_pipe.Writer.t
    -> processed_transition_writer:
         ( [ `Transition of Mina_block.Validated.t ]
           * [ `Source of [ `Gossip | `Catchup | `Internal ] ]
         , Strict_pipe.crash Strict_pipe.buffered
         , unit )
         Strict_pipe.Writer.t
    -> unit
end

module type Unprocessed_transition_cache_intf = sig
  type t

  val create : logger:Logger.t -> t

  val register_exn :
       t
    -> Mina_block.initial_valid_block Envelope.Incoming.t
    -> ( Mina_block.initial_valid_block Envelope.Incoming.t
       , State_hash.t )
       Cached.t
end

module type Transition_handler_intf = sig
  type transition_frontier

  type transition_frontier_breadcrumb

  module Unprocessed_transition_cache : Unprocessed_transition_cache_intf

  module Breadcrumb_builder :
    Breadcrumb_builder_intf
      with type transition_frontier := transition_frontier
       and type transition_frontier_breadcrumb := transition_frontier_breadcrumb

  module Validator :
    Transition_handler_validator_intf
      with type unprocessed_transition_cache := Unprocessed_transition_cache.t
       and type transition_frontier := transition_frontier

  module Processor :
    Transition_handler_processor_intf
      with type transition_frontier := transition_frontier
       and type transition_frontier_breadcrumb := transition_frontier_breadcrumb
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
    -> ( Mina_block.t State_hash.With_state_hashes.t
       , State_body_hash.t list * Mina_block.t )
       Proof_carrying_data.t
       option

  val verify :
       verifier:Verifier.t
    -> genesis_constants:Genesis_constants.t
    -> precomputed_values:Precomputed_values.t
    -> ( Mina_block.t
       , State_body_hash.t list * Mina_block.t )
       Proof_carrying_data.t
    -> ( [ `Root of Mina_block.initial_valid_block ]
       * [ `Best_tip of Mina_block.initial_valid_block ] )
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
    -> ( Mina_block.t
       , State_body_hash.t list * Mina_block.t )
       Proof_carrying_data.t
       option

  val verify :
       context:(module CONTEXT)
    -> verifier:Verifier.t
    -> genesis_constants:Genesis_constants.t
    -> Consensus.Data.Consensus_state.Value.t State_hash.With_state_hashes.t
    -> ( Mina_block.t
       , State_body_hash.t list * Mina_block.t )
       Proof_carrying_data.t
    -> ( [ `Root of Mina_block.initial_valid_block ]
       * [ `Best_tip of Mina_block.initial_valid_block ] )
       Deferred.Or_error.t
end

module type Sync_handler_intf = sig
  type transition_frontier

  val answer_query :
       frontier:transition_frontier
    -> Ledger_hash.t
    -> Mina_ledger.Sync_ledger.Query.t Envelope.Incoming.t
    -> logger:Logger.t
    -> trust_system:Trust_system.t
    -> Mina_ledger.Sync_ledger.Answer.t option Deferred.t

  val get_staged_ledger_aux_and_pending_coinbases_at_hash :
       frontier:transition_frontier
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

module type Bootstrap_controller_intf = sig
  type network

  type transition_frontier

  type persistent_root

  type persistent_frontier

  val run :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> verifier:Verifier.t
    -> network:network
    -> consensus_local_state:Consensus.Data.Local_state.t
    -> transition_reader:
         Mina_block.initial_valid_block Envelope.Incoming.t Strict_pipe.Reader.t
    -> persistent_root:persistent_root
    -> persistent_frontier:persistent_frontier
    -> initial_root_transition:Mina_block.Validated.t
    -> genesis_state_hash:State_hash.t
    -> genesis_ledger:Mina_ledger.Ledger.t Lazy.t
    -> genesis_constants:Genesis_constants.t
    -> ( transition_frontier
       * Mina_block.initial_valid_block Envelope.Incoming.t list )
       Deferred.t
end

module type Transition_frontier_controller_intf = sig
  type transition_frontier

  type breadcrumb

  type network

  val run :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> verifier:Verifier.t
    -> network:network
    -> time_controller:Block_time.Controller.t
    -> collected_transitions:
         Mina_block.initial_valid_block Envelope.Incoming.t list
    -> frontier:transition_frontier
    -> network_transition_reader:
         Mina_block.initial_valid_block Envelope.Incoming.t Strict_pipe.Reader.t
    -> producer_transition_reader:breadcrumb Strict_pipe.Reader.t
    -> clear_reader:[ `Clear ] Strict_pipe.Reader.t
    -> unit
    -> Mina_block.Validated.t Strict_pipe.Reader.t
end

module type Transition_router_intf = sig
  type transition_frontier

  type transition_frontier_persistent_root

  type transition_frontier_persistent_frontier

  type breadcrumb

  type network

  (** [sync_local_state] is `true` by default, may be set to `false` for tests *)
  val run :
       ?sync_local_state:bool
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
    -> frontier_broadcast_pipe:
         transition_frontier option Pipe_lib.Broadcast_pipe.Reader.t
         * transition_frontier option Pipe_lib.Broadcast_pipe.Writer.t
    -> network_transition_reader:
         ( [ `Transition of Mina_block.t Envelope.Incoming.t ]
         * [ `Time_received of Block_time.t ]
         * [ `Valid_cb of Mina_net2.Validation_callback.t ] )
         Strict_pipe.Reader.t
    -> producer_transition_reader:breadcrumb Strict_pipe.Reader.t
    -> most_recent_valid_block:
         Mina_block.initial_valid_block Broadcast_pipe.Reader.t
         * Mina_block.initial_valid_block Broadcast_pipe.Writer.t
    -> get_completed_work:
         (   Transaction_snark_work.Statement.t
          -> Transaction_snark_work.Checked.t option )
    -> catchup_mode:[ `Normal | `Super ]
    -> notify_online:(unit -> unit Deferred.t)
    -> unit
    -> ( [ `Transition of Mina_block.Validated.t ]
       * [ `Source of [ `Gossip | `Catchup | `Internal ] ]
       * [ `Valid_cb of Mina_net2.Validation_callback.t option ] )
       Strict_pipe.Reader.t
       * unit Ivar.t
end
