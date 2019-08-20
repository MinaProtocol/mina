open Core
open Async_kernel
open Async_rpc_kernel
open Pipe_lib
open Coda_base

module type Network_intf = sig
  type t

  type external_transition

  type transaction_snark_scan_state

  type snark_pool_diff

  type transaction_pool_diff

  type ban_notification

  val states :
       t
    -> (external_transition Envelope.Incoming.t * Block_time.t)
       Strict_pipe.Reader.t

  val peers : t -> Network_peer.Peer.t list

  val first_connection : t -> unit Ivar.t

  val first_message : t -> unit Ivar.t

  val online_status : t -> [`Online | `Offline] Broadcast_pipe.Reader.t

  val random_peers : t -> int -> Network_peer.Peer.t list

  val get_ancestry :
       t
    -> Unix.Inet_addr.t
    -> Consensus.Data.Consensus_state.Value.t
    -> ( external_transition
       , State_body_hash.t list * external_transition )
       Proof_carrying_data.t
       Deferred.Or_error.t

  val get_bootstrappable_best_tip :
       t
    -> Network_peer.Peer.t
    -> Consensus.Data.Consensus_state.Value.t
    -> ( external_transition
       , State_body_hash.t list * external_transition )
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
    -> external_transition list Deferred.Or_error.t

  val get_staged_ledger_aux_and_pending_coinbases_at_hash :
       t
    -> Unix.Inet_addr.t
    -> State_hash.t
    -> (transaction_snark_scan_state * Ledger_hash.t * Pending_coinbase.t)
       Deferred.Or_error.t

  val ban_notify :
    t -> Network_peer.Peer.t -> Time.t -> unit Deferred.Or_error.t

  val snark_pool_diffs :
    t -> snark_pool_diff Envelope.Incoming.t Linear_pipe.Reader.t

  val transaction_pool_diffs :
    t -> transaction_pool_diff Envelope.Incoming.t Linear_pipe.Reader.t

  val broadcast_state : t -> external_transition -> unit

  val broadcast_snark_pool_diff : t -> snark_pool_diff -> unit

  val broadcast_transaction_pool_diff : t -> transaction_pool_diff -> unit

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
    -> Network_peer.Peer.t
    -> (Versioned_rpc.Connection_with_menu.t -> 'q -> 'r Deferred.Or_error.t)
    -> 'q
    -> 'r Deferred.Or_error.t

  val initial_peers : t -> Host_and_port.t list

  val peers_by_ip : t -> Unix.Inet_addr.t -> Network_peer.Peer.t list

  val ban_notification_reader : t -> ban_notification Linear_pipe.Reader.t

  val banned_peer : ban_notification -> Network_peer.Peer.t

  val banned_until : ban_notification -> Time.t

  module Gossip_net : sig
    module Config : Gossip_net.Config_intf
  end

  module Config : sig
    type t =
      { logger: Logger.t
      ; trust_system: Trust_system.t
      ; gossip_net_params: Gossip_net.Config.t
      ; time_controller: Block_time.Controller.t
      ; consensus_local_state: Consensus.Data.Local_state.t }
  end

  val create :
       Config.t
    -> get_staged_ledger_aux_and_pending_coinbases_at_hash:(   State_hash.t
                                                               Envelope
                                                               .Incoming
                                                               .t
                                                            -> ( transaction_snark_scan_state
                                                               * Ledger_hash.t
                                                               * Pending_coinbase
                                                                 .t )
                                                               Deferred.Option
                                                               .t)
    -> answer_sync_ledger_query:(   (Ledger_hash.t * Sync_ledger.Query.t)
                                    Envelope.Incoming.t
                                 -> Sync_ledger.Answer.t Deferred.Or_error.t)
    -> get_ancestry:(   Consensus.Data.Consensus_state.Value.t
                        Envelope.Incoming.t
                     -> ( external_transition
                        , State_body_hash.t list * external_transition )
                        Proof_carrying_data.t
                        Deferred.Option.t)
    -> get_bootstrappable_best_tip:(   Consensus.Data.Consensus_state.Value.t
                                       Envelope.Incoming.t
                                    -> ( external_transition
                                       , State_body_hash.t list
                                         * external_transition )
                                       Proof_carrying_data.t
                                       Deferred.Option.t)
    -> get_transition_chain_proof:(   State_hash.t Envelope.Incoming.t
                                   -> (State_hash.t * State_body_hash.t list)
                                      Deferred.Option.t)
    -> get_transition_chain:(   State_hash.t list Envelope.Incoming.t
                             -> external_transition list Deferred.Option.t)
    -> t Deferred.t
end
