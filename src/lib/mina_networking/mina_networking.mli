open Async
open Core
open Mina_base
open Mina_transition
open Network_pool
open Pipe_lib
open Network_peer

exception No_initial_peers

type Structured_log_events.t +=
  | Block_received of { state_hash : State_hash.t; sender : Envelope.Sender.t }
  | Snark_work_received of
      { work : Snark_pool.Resource_pool.Diff.compact
      ; sender : Envelope.Sender.t
      }
  | Transactions_received of
      { txns : Transaction_pool.Resource_pool.Diff.t
      ; sender : Envelope.Sender.t
      }
  | Gossip_new_state of { state_hash : State_hash.t }
  | Gossip_transaction_pool_diff of
      { txns : Transaction_pool.Resource_pool.Diff.t }
  | Gossip_snark_pool_diff of { work : Snark_pool.Resource_pool.Diff.compact }
  [@@deriving register_event]

val refused_answer_query_string : string

module Rpcs : sig
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

    type response = Sync_ledger.Answer.t Core.Or_error.t
  end

  module Get_transition_chain : sig
    type query = State_hash.t list

    type response = External_transition.t list option
  end

  module Get_transition_knowledge : sig
    type query = unit

    type response = State_hash.t list
  end

  module Get_transition_chain_proof : sig
    type query = State_hash.t

    type response = (State_hash.t * State_body_hash.t list) option
  end

  module Get_ancestry : sig
    type query =
      (Consensus.Data.Consensus_state.Value.t, State_hash.t) With_hash.t

    type response =
      ( External_transition.t
      , State_body_hash.t list * External_transition.t )
      Proof_carrying_data.t
      option
  end

  module Ban_notify : sig
    type query = Core.Time.t

    type response = unit
  end

  module Get_best_tip : sig
    type query = unit [@@deriving sexp, to_yojson]

    type response =
      ( External_transition.t
      , State_body_hash.t list * External_transition.t )
      Proof_carrying_data.t
      option
  end

  module Get_node_status : sig
    module Node_status : sig
      [%%versioned:
      module Stable : sig
        module V2 : sig
          type t =
            { node_ip_addr : Core.Unix.Inet_addr.Stable.V1.t
            ; node_peer_id : Peer.Id.Stable.V1.t
            ; sync_status : Sync_status.Stable.V1.t
            ; peers : Network_peer.Peer.Stable.V1.t list
            ; block_producers :
                Signature_lib.Public_key.Compressed.Stable.V1.t list
            ; protocol_state_hash : State_hash.Stable.V1.t
            ; ban_statuses :
                ( Network_peer.Peer.Stable.V1.t
                * Trust_system.Peer_status.Stable.V1.t )
                list
            ; k_block_hashes_and_timestamps :
                (State_hash.Stable.V1.t * string) list
            ; git_commit : string
            ; uptime_minutes : int
            ; block_height_opt : int option
            }
        end
      end]
    end

    type query = unit [@@deriving sexp, to_yojson]

    type response = Node_status.t Or_error.t [@@deriving to_yojson]
  end

  module Get_some_initial_peers : sig
    type query = unit [@@deriving sexp, to_yojson]

    type response = Network_peer.Peer.t list [@@deriving to_yojson]
  end

  type ('query, 'response) rpc =
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
    | Get_node_status : (Get_node_status.query, Get_node_status.response) rpc
    | Get_ancestry : (Get_ancestry.query, Get_ancestry.response) rpc
    | Ban_notify : (Ban_notify.query, Ban_notify.response) rpc
    | Get_best_tip : (Get_best_tip.query, Get_best_tip.response) rpc
    | Consensus_rpc : ('q, 'r) Consensus.Hooks.Rpcs.rpc -> ('q, 'r) rpc

  include Rpc_intf.Rpc_interface_intf with type ('q, 'r) rpc := ('q, 'r) rpc
end

module Sinks : module type of Sinks

module Gossip_net :
  Gossip_net.S with module Rpc_intf := Rpcs with type sinks := Sinks.sinks

module Config : sig
  type log_gossip_heard =
    { snark_pool_diff : bool; transaction_pool_diff : bool; new_state : bool }
  [@@deriving make]

  type t =
    { logger : Logger.t
    ; trust_system : Trust_system.t
    ; time_controller : Block_time.Controller.t
    ; consensus_local_state : Consensus.Data.Local_state.t
    ; genesis_ledger_hash : Ledger_hash.t
    ; constraint_constants : Genesis_constants.Constraint_constants.t
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
     t
  -> Network_peer.Peer.t
  -> Rpcs.Get_node_status.Node_status.t Deferred.Or_error.t

val add_peer :
  t -> Network_peer.Peer.t -> is_seed:bool -> unit Deferred.Or_error.t

val on_first_received_message : t -> f:(unit -> 'a) -> 'a Deferred.t

val fill_first_received_message_signal : t -> unit

val on_first_connect : t -> f:(unit -> 'a) -> 'a Deferred.t

val on_first_high_connectivity : t -> f:(unit -> 'a) -> 'a Deferred.t

val online_status : t -> [ `Online | `Offline ] Broadcast_pipe.Reader.t

val random_peers : t -> int -> Network_peer.Peer.t list Deferred.t

val get_ancestry :
     t
  -> Peer.Id.t
  -> (Consensus.Data.Consensus_state.Value.t, State_hash.t) With_hash.t
  -> ( External_transition.t
     , State_body_hash.t list * External_transition.t )
     Proof_carrying_data.t
     Envelope.Incoming.t
     Deferred.Or_error.t

val get_best_tip :
     ?heartbeat_timeout:Time_ns.Span.t
  -> ?timeout:Time.Span.t
  -> t
  -> Network_peer.Peer.t
  -> ( External_transition.t
     , State_body_hash.t list * External_transition.t )
     Proof_carrying_data.t
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
  -> External_transition.t list Deferred.Or_error.t

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
  t -> (External_transition.t, State_hash.t) With_hash.t -> unit Deferred.t

val broadcast_snark_pool_diff :
  t -> Snark_pool.Resource_pool.Diff.t -> unit Deferred.t

val broadcast_transaction_pool_diff :
  t -> Transaction_pool.Resource_pool.Diff.t -> unit Deferred.t

val glue_sync_ledger :
     t
  -> preferred:Peer.t list
  -> (Ledger_hash.t * Sync_ledger.Query.t) Linear_pipe.Reader.t
  -> ( Ledger_hash.t
     * Sync_ledger.Query.t
     * Sync_ledger.Answer.t Envelope.Incoming.t )
     Linear_pipe.Writer.t
  -> unit

val query_peer :
     ?heartbeat_timeout:Time_ns.Span.t
  -> ?timeout:Time.Span.t
  -> t
  -> Network_peer.Peer.Id.t
  -> ('q, 'r) Rpcs.rpc
  -> 'q
  -> 'r Mina_base.Rpc_intf.rpc_response Deferred.t

val restart_helper : t -> unit

val initial_peers : t -> Mina_net2.Multiaddr.t list

val connection_gating_config : t -> Mina_net2.connection_gating Deferred.t

val set_connection_gating_config :
  t -> Mina_net2.connection_gating -> Mina_net2.connection_gating Deferred.t

val ban_notification_reader :
  t -> Gossip_net.ban_notification Linear_pipe.Reader.t

val create :
     Config.t
  -> sinks:Sinks.Unwrapped.sinks
  -> get_some_initial_peers:
       (   Rpcs.Get_some_initial_peers.query Envelope.Incoming.t
        -> Rpcs.Get_some_initial_peers.response Deferred.t)
  -> get_staged_ledger_aux_and_pending_coinbases_at_hash:
       (   Rpcs.Get_staged_ledger_aux_and_pending_coinbases_at_hash.query
           Envelope.Incoming.t
        -> Rpcs.Get_staged_ledger_aux_and_pending_coinbases_at_hash.response
           Deferred.t)
  -> answer_sync_ledger_query:
       (   Rpcs.Answer_sync_ledger_query.query Envelope.Incoming.t
        -> Rpcs.Answer_sync_ledger_query.response Deferred.t)
  -> get_ancestry:
       (   Rpcs.Get_ancestry.query Envelope.Incoming.t
        -> Rpcs.Get_ancestry.response Deferred.t)
  -> get_best_tip:
       (   Rpcs.Get_best_tip.query Envelope.Incoming.t
        -> Rpcs.Get_best_tip.response Deferred.t)
  -> get_node_status:
       (   Rpcs.Get_node_status.query Envelope.Incoming.t
        -> Rpcs.Get_node_status.response Deferred.t)
  -> get_transition_chain_proof:
       (   Rpcs.Get_transition_chain_proof.query Envelope.Incoming.t
        -> Rpcs.Get_transition_chain_proof.response Deferred.t)
  -> get_transition_chain:
       (   Rpcs.Get_transition_chain.query Envelope.Incoming.t
        -> Rpcs.Get_transition_chain.response Deferred.t)
  -> get_transition_knowledge:
       (   Rpcs.Get_transition_knowledge.query Envelope.Incoming.t
        -> Rpcs.Get_transition_knowledge.response Deferred.t)
  -> t Deferred.t
