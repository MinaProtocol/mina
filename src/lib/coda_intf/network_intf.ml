open Core
open Async_kernel
open Async_rpc_kernel
open Pipe_lib
open Coda_base
open Coda_transition
open Network_peer

module type Network_intf = sig
  type t

  type snark_pool_diff

  type transaction_pool_diff

  type ban_notification

  val states :
       t
    -> (External_transition.t Envelope.Incoming.t * Block_time.t)
       Strict_pipe.Reader.t

  val peers : t -> Network_peer.Peer.t list Deferred.t

  val random_peers : t -> int -> Network_peer.Peer.t list Deferred.t

  val first_connection : t -> unit Ivar.t

  val first_message : t -> unit Ivar.t

  val high_connectivity : t -> unit Ivar.t

  val online_status : t -> [`Online | `Offline] Broadcast_pipe.Reader.t

  val get_ancestry :
       t
    -> Network_peer.Peer.Id.t
    -> Consensus.Data.Consensus_state.Value.t
    -> ( External_transition.t
       , State_body_hash.t list * External_transition.t )
       Proof_carrying_data.t
       Envelope.Incoming.t
       Deferred.Or_error.t

  val get_bootstrappable_best_tip :
       t
    -> Network_peer.Peer.Id.t
    -> Consensus.Data.Consensus_state.Value.t
    -> ( External_transition.t
       , State_body_hash.t list * External_transition.t )
       Proof_carrying_data.t
       Envelope.Incoming.t
       Deferred.Or_error.t

  val get_transition_chain_proof :
       t
    -> Network_peer.Peer.Id.t
    -> State_hash.t
    -> (State_hash.t * State_body_hash.t List.t) Envelope.Incoming.t
       Deferred.Or_error.t

  val get_transition_chain :
       t
    -> Network_peer.Peer.Id.t
    -> State_hash.t list
    -> External_transition.t list Envelope.Incoming.t Deferred.Or_error.t

  val get_staged_ledger_aux_and_pending_coinbases_at_hash :
       t
    -> Network_peer.Peer.Id.t
    -> State_hash.t
    -> (Staged_ledger.Scan_state.t * Ledger_hash.t * Pending_coinbase.t)
       Envelope.Incoming.t
       Deferred.Or_error.t

  val ban_notify :
       t
    -> Network_peer.Peer.t
    -> Time.t
    -> unit Envelope.Incoming.t Deferred.Or_error.t

  val snark_pool_diffs :
    t -> snark_pool_diff Envelope.Incoming.t Strict_pipe.Reader.t

  val transaction_pool_diffs :
    t -> transaction_pool_diff Envelope.Incoming.t Strict_pipe.Reader.t

  val broadcast_state : t -> External_transition.t -> unit

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
    -> Network_peer.Peer.Id.t
    -> (Versioned_rpc.Connection_with_menu.t -> 'q -> 'r Deferred.Or_error.t)
    -> 'q
    -> 'r Envelope.Incoming.t Deferred.Or_error.t

  val initial_peers : t -> Coda_net2.Multiaddr.t list

  val ban_notification_reader : t -> ban_notification Linear_pipe.Reader.t

  val banned_peer : ban_notification -> Network_peer.Peer.t

  val banned_until : ban_notification -> Time.t

  val net2 : t -> Coda_net2.net

  module Config : sig
    type log_gossip_heard =
      {snark_pool_diff: bool; transaction_pool_diff: bool; new_state: bool}
    [@@deriving make, fields]

    type t =
      { logger: Logger.t
      ; trust_system: Trust_system.t
      ; time_controller: Block_time.Controller.t
      ; addrs_and_ports: Node_addrs_and_ports.t
      ; conf_dir: string
      ; chain_id: string
      ; log_gossip_heard: log_gossip_heard
      ; keypair: Coda_net2.Keypair.t option
      ; peers: Coda_net2.Multiaddr.t list
      ; consensus_local_state: Consensus.Data.Local_state.t }
  end

  val create :
       Config.t
    -> get_staged_ledger_aux_and_pending_coinbases_at_hash:(   State_hash.t
                                                               Envelope
                                                               .Incoming
                                                               .t
                                                            -> ( Staged_ledger
                                                                 .Scan_state
                                                                 .t
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
                     -> ( External_transition.t
                        , State_body_hash.t list * External_transition.t )
                        Proof_carrying_data.t
                        Deferred.Option.t)
    -> get_bootstrappable_best_tip:(   Consensus.Data.Consensus_state.Value.t
                                       Envelope.Incoming.t
                                    -> ( External_transition.t
                                       , State_body_hash.t list
                                         * External_transition.t )
                                       Proof_carrying_data.t
                                       Deferred.Option.t)
    -> get_transition_chain_proof:(   State_hash.t Envelope.Incoming.t
                                   -> (State_hash.t * State_body_hash.t list)
                                      Deferred.Option.t)
    -> get_transition_chain:(   State_hash.t list Envelope.Incoming.t
                             -> External_transition.t list Deferred.Option.t)
    -> t Deferred.t
end
