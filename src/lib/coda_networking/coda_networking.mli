open Async
open Core
open Coda_base
open Coda_transition
open Network_pool
open Pipe_lib

exception No_initial_peers

val refused_answer_query_string : string

module Rpcs : sig
  module Get_staged_ledger_aux_and_pending_coinbases_at_hash : sig
    type query = State_hash.t

    type response =
      (Staged_ledger.Scan_state.t * Ledger_hash.t * Pending_coinbase.t) option
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
    ; creatable_gossip_net: Gossip_net.Any.creatable
    ; log_gossip_heard: log_gossip_heard }
  [@@deriving make]
end

type t

val states :
     t
  -> (External_transition.t Envelope.Incoming.t * Block_time.t)
     Strict_pipe.Reader.t

val peers : t -> Network_peer.Peer.t list

val on_first_received_message : t -> f:(unit -> 'a) -> 'a Deferred.t

val fill_first_received_message_signal : t -> unit

val on_first_connect : t -> f:(unit -> 'a) -> 'a Deferred.t

val on_first_high_connectivity : t -> f:(unit -> 'a) -> 'a Deferred.t

val online_status : t -> [`Online | `Offline] Broadcast_pipe.Reader.t

val random_peers : t -> int -> Network_peer.Peer.t list

val get_ancestry :
     t
  -> Unix.Inet_addr.t
  -> Consensus.Data.Consensus_state.Value.t
  -> ( External_transition.t
     , State_body_hash.t list * External_transition.t )
     Proof_carrying_data.t
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
  -> Unix.Inet_addr.t
  -> State_hash.t
  -> (Staged_ledger.Scan_state.t * Ledger_hash.t * Pending_coinbase.t)
     Deferred.Or_error.t

val ban_notify : t -> Network_peer.Peer.t -> Time.t -> unit Deferred.Or_error.t

val snark_pool_diffs :
  t -> Snark_pool.Resource_pool.Diff.t Envelope.Incoming.t Linear_pipe.Reader.t

val transaction_pool_diffs :
     t
  -> Transaction_pool.Resource_pool.Diff.t Envelope.Incoming.t
     Linear_pipe.Reader.t

val broadcast_state : t -> External_transition.t -> unit

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
  t -> Network_peer.Peer.t -> ('q, 'r) Rpcs.rpc -> 'q -> 'r Deferred.Or_error.t

val initial_peers : t -> Host_and_port.t list

val peers_by_ip : t -> Unix.Inet_addr.t -> Network_peer.Peer.t list

val net2 : t -> Coda_net2.net option

val ban_notification_reader :
  t -> Gossip_net.ban_notification Linear_pipe.Reader.t

val create :
     Config.t
  -> get_staged_ledger_aux_and_pending_coinbases_at_hash:(   State_hash.t
                                                             Envelope.Incoming
                                                             .t
                                                          -> ( Staged_ledger
                                                               .Scan_state
                                                               .t
                                                             * Ledger_hash.t
                                                             * Pending_coinbase
                                                               .t )
                                                             Deferred.Option.t)
  -> answer_sync_ledger_query:(   (Ledger_hash.t * Sync_ledger.Query.t)
                                  Envelope.Incoming.t
                               -> Sync_ledger.Answer.t Deferred.Or_error.t)
  -> get_ancestry:(   Consensus.Data.Consensus_state.Value.t Envelope.Incoming.t
                   -> ( External_transition.t
                      , State_body_hash.t list * External_transition.t )
                      Proof_carrying_data.t
                      Deferred.Option.t)
  -> get_best_tip:(   unit Envelope.Incoming.t
                   -> ( External_transition.t
                      , State_body_hash.t list * External_transition.t )
                      Proof_carrying_data.t
                      Deferred.Option.t)
  -> get_transition_chain_proof:(   State_hash.t Envelope.Incoming.t
                                 -> (State_hash.t * State_body_hash.t list)
                                    Deferred.Option.t)
  -> get_transition_chain:(   State_hash.t list Envelope.Incoming.t
                           -> External_transition.t list Deferred.Option.t)
  -> t Deferred.t
