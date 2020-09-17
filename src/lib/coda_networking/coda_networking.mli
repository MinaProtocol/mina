open Async
open Core
open Coda_base
open Coda_transition
open Network_pool
open Pipe_lib
open Network_peer

exception No_initial_peers

type Structured_log_events.t +=
  | Block_received of {state_hash: State_hash.t; sender: Envelope.Sender.t}
  | Snark_work_received of
      { work: Snark_pool.Resource_pool.Diff.compact
      ; sender: Envelope.Sender.t }
  | Transactions_received of
      { txns: Transaction_pool.Resource_pool.Diff.t
      ; sender: Envelope.Sender.t }
  | Gossip_new_state of {state_hash: State_hash.t}
  | Gossip_transaction_pool_diff of
      { txns: Transaction_pool.Resource_pool.Diff.t }
  | Gossip_snark_pool_diff of {work: Snark_pool.Resource_pool.Diff.compact}
  [@@deriving register_event]

val refused_answer_query_string : string

module Rpcs : sig
  module Get_staged_ledger_aux_and_pending_coinbases_at_hash : sig
    type query = State_hash.t

    type response =
      ( Staged_ledger.Scan_state.t
      * Ledger_hash.t
      * Pending_coinbase.t
      * Coda_state.Protocol_state.value list )
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

  module Get_transition_chain_proof : sig
    type query = State_hash.t

    type response = (State_hash.t * State_body_hash.t list) option
  end

  module Get_ancestry : sig
    type query = Consensus.Data.Consensus_state.Value.t

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

  module Get_telemetry_data : sig
    module Telemetry_data : sig
      [%%versioned:
      module Stable : sig
        module V1 : sig
          type t =
            { node_ip_addr: Core.Unix.Inet_addr.Stable.V1.t
            ; node_peer_id: Peer.Id.Stable.V1.t
            ; peers: Network_peer.Peer.Stable.V1.t list
            ; block_producers:
                Signature_lib.Public_key.Compressed.Stable.V1.t list
            ; protocol_state_hash: State_hash.Stable.V1.t
            ; ban_statuses:
                ( Core.Unix.Inet_addr.Stable.V1.t
                * Trust_system.Peer_status.Stable.V1.t )
                list
            ; k_block_hashes: State_hash.Stable.V1.t list }
        end
      end]
    end

    type query = unit [@@deriving sexp, to_yojson]

    type response = Telemetry_data.t Or_error.t [@@deriving to_yojson]
  end

  type ('query, 'response) rpc =
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
    | Get_transition_chain_proof
        : ( Get_transition_chain_proof.query
          , Get_transition_chain_proof.response )
          rpc
    | Get_ancestry : (Get_ancestry.query, Get_ancestry.response) rpc
    | Ban_notify : (Ban_notify.query, Ban_notify.response) rpc
    | Get_best_tip : (Get_best_tip.query, Get_best_tip.response) rpc
    | Get_telemetry_data
        : (Get_telemetry_data.query, Get_telemetry_data.response) rpc
    | Consensus_rpc : ('q, 'r) Consensus.Hooks.Rpcs.rpc -> ('q, 'r) rpc

  include Rpc_intf.Rpc_interface_intf with type ('q, 'r) rpc := ('q, 'r) rpc
end

module Gossip_net : Gossip_net.S with module Rpc_intf := Rpcs

module Config : sig
  type log_gossip_heard =
    {snark_pool_diff: bool; transaction_pool_diff: bool; new_state: bool}
  [@@deriving make]

  type t =
    { logger: Logger.t
    ; trust_system: Trust_system.t
    ; time_controller: Block_time.Controller.t
    ; consensus_local_state: Consensus.Data.Local_state.t
    ; genesis_ledger_hash: Ledger_hash.t
    ; constraint_constants: Genesis_constants.Constraint_constants.t
    ; creatable_gossip_net: Gossip_net.Any.creatable
    ; is_seed: bool
    ; log_gossip_heard: log_gossip_heard }
  [@@deriving make]
end

type t

val states :
     t
  -> (External_transition.t Envelope.Incoming.t * Block_time.t * (bool -> unit))
     Strict_pipe.Reader.t

val peers : t -> Network_peer.Peer.t list Deferred.t

val on_first_received_message : t -> f:(unit -> 'a) -> 'a Deferred.t

val fill_first_received_message_signal : t -> unit

val on_first_connect : t -> f:(unit -> 'a) -> 'a Deferred.t

val on_first_high_connectivity : t -> f:(unit -> 'a) -> 'a Deferred.t

val online_status : t -> [`Online | `Offline] Broadcast_pipe.Reader.t

val random_peers : t -> int -> Network_peer.Peer.t list Deferred.t

val get_ancestry :
     t
  -> Peer.Id.t
  -> Consensus.Data.Consensus_state.Value.t
  -> ( External_transition.t
     , State_body_hash.t list * External_transition.t )
     Proof_carrying_data.t
     Envelope.Incoming.t
     Deferred.Or_error.t

val get_best_tip :
     t
  -> Network_peer.Peer.t
  -> ( External_transition.t
     , State_body_hash.t list * External_transition.t )
     Proof_carrying_data.t
     Deferred.Or_error.t

val get_transition_chain_proof :
     t
  -> Network_peer.Peer.t
  -> State_hash.t
  -> (State_hash.t * State_body_hash.t List.t) Deferred.Or_error.t

val get_transition_chain :
     t
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
     * Coda_state.Protocol_state.value list )
     Deferred.Or_error.t

val ban_notify : t -> Network_peer.Peer.t -> Time.t -> unit Deferred.Or_error.t

val snark_pool_diffs :
     t
  -> (Snark_pool.Resource_pool.Diff.t Envelope.Incoming.t * (bool -> unit))
     Strict_pipe.Reader.t

val transaction_pool_diffs :
     t
  -> ( Transaction_pool.Resource_pool.Diff.t Envelope.Incoming.t
     * (bool -> unit) )
     Strict_pipe.Reader.t

val broadcast_state :
  t -> (External_transition.t, State_hash.t) With_hash.t -> unit

val broadcast_snark_pool_diff : t -> Snark_pool.Resource_pool.Diff.t -> unit

val broadcast_transaction_pool_diff :
  t -> Transaction_pool.Resource_pool.Diff.t -> unit

val glue_sync_ledger :
     t
  -> (Ledger_hash.t * Sync_ledger.Query.t) Linear_pipe.Reader.t
  -> ( Ledger_hash.t
     * Sync_ledger.Query.t
     * Sync_ledger.Answer.t Envelope.Incoming.t )
     Linear_pipe.Writer.t
  -> unit

val query_peer :
     t
  -> Network_peer.Peer.Id.t
  -> ('q, 'r) Rpcs.rpc
  -> 'q
  -> 'r Coda_base.Rpc_intf.rpc_response Deferred.t

val ip_for_peer :
  t -> Network_peer.Peer.Id.t -> Unix.Inet_addr.t option Deferred.t

val initial_peers : t -> Coda_net2.Multiaddr.t list

val ban_notification_reader :
  t -> Gossip_net.ban_notification Linear_pipe.Reader.t

val create :
     Config.t
  -> get_staged_ledger_aux_and_pending_coinbases_at_hash:(   Rpcs
                                                             .Get_staged_ledger_aux_and_pending_coinbases_at_hash
                                                             .query
                                                             Envelope.Incoming
                                                             .t
                                                          -> Rpcs
                                                             .Get_staged_ledger_aux_and_pending_coinbases_at_hash
                                                             .response
                                                             Deferred.t)
  -> answer_sync_ledger_query:(   Rpcs.Answer_sync_ledger_query.query
                                  Envelope.Incoming.t
                               -> Rpcs.Answer_sync_ledger_query.response
                                  Deferred.t)
  -> get_ancestry:(   Rpcs.Get_ancestry.query Envelope.Incoming.t
                   -> Rpcs.Get_ancestry.response Deferred.t)
  -> get_best_tip:(   Rpcs.Get_best_tip.query Envelope.Incoming.t
                   -> Rpcs.Get_best_tip.response Deferred.t)
  -> get_telemetry_data:(   Rpcs.Get_telemetry_data.query Envelope.Incoming.t
                         -> Rpcs.Get_telemetry_data.response Deferred.t)
  -> get_transition_chain_proof:(   Rpcs.Get_transition_chain_proof.query
                                    Envelope.Incoming.t
                                 -> Rpcs.Get_transition_chain_proof.response
                                    Deferred.t)
  -> get_transition_chain:(   Rpcs.Get_transition_chain.query
                              Envelope.Incoming.t
                           -> Rpcs.Get_transition_chain.response Deferred.t)
  -> t Deferred.t
