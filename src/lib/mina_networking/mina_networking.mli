open Async
open Core
open Mina_base
open Mina_ledger
open Network_pool
open Pipe_lib
open Network_peer

exception No_initial_peers

type Structured_log_events.t +=
  | Gossip_new_state of { state_hash : State_hash.t }
  | Gossip_transaction_pool_diff of
      { fee_payer_summaries : User_command.fee_payer_summary_t list }
  | Gossip_snark_pool_diff of { work : Snark_pool.Resource_pool.Diff.compact }
  [@@deriving register_event]

module type CONTEXT = sig
  val logger : Logger.t

  val trust_system : Trust_system.t

  val time_controller : Block_time.Controller.t

  val consensus_local_state : Consensus.Data.Local_state.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t

  val compile_config : Mina_compile_config.t
end

module Node_status = Node_status
module Sinks = Sinks

module Gossip_net : Gossip_net.S with module Rpc_interface := Rpcs

module Rpcs : sig
  module Get_some_initial_peers : sig
    type query = unit

    type response = Peer.t list
  end

  module Get_staged_ledger_aux_and_pending_coinbases_at_hash : sig
    type query = State_hash.t

    type response =
      ( Staged_ledger.Scan_state.t
      * Ledger_hash.t
      * Pending_coinbase.t
      * Mina_state.Protocol_state.value list )
      option
  end

  module Answer_sync_ledger_query : sig
    type query = Ledger_hash.t * Sync_ledger.Query.t

    type response =
      (Sync_ledger.Answer.t, Bounded_types.Wrapped_error.Stable.V1.t) Result.t
  end

  module Get_transition_chain : sig
    type query = State_hash.t list

    type response = Mina_block.t list option
  end

  module Get_transition_chain_proof : sig
    type query = State_hash.t

    type response = (State_hash.t * State_body_hash.t list) option
  end

  module Get_transition_knowledge : sig
    type query = unit

    type response = State_hash.t list
  end

  module Get_ancestry : sig
    type query =
      (Consensus.Data.Consensus_state.Value.t, State_hash.t) With_hash.t

    type response =
      ( Mina_block.t
      , State_body_hash.t list * Mina_block.t )
      Proof_carrying_data.t
      option
  end

  module Ban_notify : sig
    (* banned until this time *)
    type query = Core.Time.t

    type response = unit
  end

  module Get_best_tip : sig
    type query = unit

    type response =
      ( Mina_block.t
      , State_body_hash.t list * Mina_block.t )
      Proof_carrying_data.t
      option
  end

  type ('query, 'response) rpc = ('query, 'response) Rpcs.rpc =
    | Get_some_initial_peers
        : (Get_some_initial_peers.query, Get_some_initial_peers.response) rpc
    | Get_staged_ledger_aux_and_pending_coinbases_at_hash
        : ( Get_staged_ledger_aux_and_pending_coinbases_at_hash.query
          , Get_staged_ledger_aux_and_pending_coinbases_at_hash.response )
          rpc
    | Answer_sync_ledger_query
        : ( Answer_sync_ledger_query.query
          , Answer_sync_ledger_query.response )
          rpc
    | Get_transition_chain
        : (Get_transition_chain.query, Get_transition_chain.response) rpc
    | Get_transition_knowledge
        : ( Get_transition_knowledge.query
          , Get_transition_knowledge.response )
          rpc
    | Get_transition_chain_proof
        : ( Get_transition_chain_proof.query
          , Get_transition_chain_proof.response )
          rpc
    | Get_ancestry : (Get_ancestry.query, Get_ancestry.response) rpc
    | Ban_notify : (Ban_notify.query, Ban_notify.response) rpc
    | Get_best_tip : (Get_best_tip.query, Get_best_tip.response) rpc
end

module Config : sig
  type log_gossip_heard =
    { snark_pool_diff : bool; transaction_pool_diff : bool; new_state : bool }
  [@@deriving make]

  type t =
    { genesis_ledger_hash : Ledger_hash.t
    ; creatable_gossip_net : Gossip_net.Any.creatable
    ; is_seed : bool
    ; log_gossip_heard : log_gossip_heard
    }
  [@@deriving make]
end

type t

val peers : t -> Network_peer.Peer.t list Deferred.t

val bandwidth_info :
     t
  -> ([ `Input of float ] * [ `Output of float ] * [ `Cpu_usage of float ])
     Deferred.Or_error.t

val get_peer_node_status :
  t -> Network_peer.Peer.t -> Node_status.t Deferred.Or_error.t

val get_node_status_from_peers :
     t
  -> Mina_net2.Multiaddr.t list option
  -> Node_status.t Or_error.t list Deferred.t

val add_peer :
  t -> Network_peer.Peer.t -> is_seed:bool -> unit Deferred.Or_error.t

val on_first_connect : t -> f:(unit -> 'a) -> 'a Deferred.t

val on_first_high_connectivity : t -> f:(unit -> 'a) -> 'a Deferred.t

val random_peers : t -> int -> Network_peer.Peer.t list Deferred.t

val get_ancestry :
     t
  -> Peer.Id.t
  -> (Consensus.Data.Consensus_state.Value.t, State_hash.t) With_hash.t
  -> (Mina_block.t, State_body_hash.t list * Mina_block.t) Proof_carrying_data.t
     Envelope.Incoming.t
     Deferred.Or_error.t

val get_best_tip :
     ?heartbeat_timeout:Time_ns.Span.t
  -> ?timeout:Time.Span.t
  -> t
  -> Network_peer.Peer.t
  -> (Mina_block.t, State_body_hash.t list * Mina_block.t) Proof_carrying_data.t
     Deferred.Or_error.t

val get_transition_chain_proof :
     ?heartbeat_timeout:Time_ns.Span.t
  -> ?timeout:Time.Span.t
  -> t
  -> Network_peer.Peer.t
  -> State_hash.t
  -> (State_hash.t * State_body_hash.t List.t) Deferred.Or_error.t

val get_transition_chain :
     ?heartbeat_timeout:Time_ns.Span.t
  -> ?timeout:Time.Span.t
  -> t
  -> Network_peer.Peer.t
  -> State_hash.t list
  -> Mina_block.t list Deferred.Or_error.t

val get_staged_ledger_aux_and_pending_coinbases_at_hash :
     t
  -> Peer.Id.t
  -> State_hash.t
  -> ( Staged_ledger.Scan_state.t
     * Ledger_hash.t
     * Pending_coinbase.t
     * Mina_state.Protocol_state.value list )
     Deferred.Or_error.t

val ban_notify : t -> Network_peer.Peer.t -> Time.t -> unit Deferred.Or_error.t

val broadcast_state :
  t -> Mina_block.t State_hash.With_state_hashes.t -> unit Deferred.t

val broadcast_snark_pool_diff :
  ?nonce:int -> t -> Snark_pool.Resource_pool.Diff.t -> unit Deferred.t

val broadcast_transaction_pool_diff :
  ?nonce:int -> t -> Transaction_pool.Resource_pool.Diff.t -> unit Deferred.t

val glue_sync_ledger :
     t
  -> preferred:Peer.t list
  -> (Ledger_hash.t * Mina_ledger.Sync_ledger.Query.t) Linear_pipe.Reader.t
  -> ( Ledger_hash.t
     * Mina_ledger.Sync_ledger.Query.t
     * Mina_ledger.Sync_ledger.Answer.t Envelope.Incoming.t )
     Linear_pipe.Writer.t
  -> unit

val query_peer :
     ?heartbeat_timeout:Time_ns.Span.t
  -> ?timeout:Time.Span.t
  -> t
  -> Network_peer.Peer.Id.t
  -> ('q, 'r) Rpcs.rpc
  -> 'q
  -> 'r Gossip_net.rpc_response Deferred.t

val restart_helper : t -> unit

val initial_peers : t -> Mina_net2.Multiaddr.t list

val connection_gating_config : t -> Mina_net2.connection_gating Deferred.t

val set_connection_gating_config :
     t
  -> ?clean_added_peers:bool
  -> Mina_net2.connection_gating
  -> Mina_net2.connection_gating Deferred.t

val ban_notification_reader :
  t -> Gossip_net.ban_notification Linear_pipe.Reader.t

val create :
     (module CONTEXT)
  -> Config.t
  -> sinks:Sinks.t
  -> get_transition_frontier:(unit -> Transition_frontier.t option)
  -> get_node_status:(unit -> Node_status.t Deferred.Or_error.t)
  -> t Deferred.t
