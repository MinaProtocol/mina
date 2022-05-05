open Async
open Core
open Gadt_lib
open Network_peer
open Mina_base
module Sync_ledger = Mina_ledger.Sync_ledger

(* There must be at least 2 peers to create a network *)
type 'n num_peers = 'n Peano.gt_1

type peer_state =
  { frontier : Transition_frontier.t
  ; consensus_local_state : Consensus.Data.Local_state.t
  ; get_staged_ledger_aux_and_pending_coinbases_at_hash :
         Pasta_bindings.Fp.t Envelope.Incoming.t
      -> ( Staged_ledger.Scan_state.t
         * Pasta_bindings.Fp.t
         * Pending_coinbase.t
         * Mina_state.Protocol_state.value list )
         option
         Deferred.t
  ; get_some_initial_peers : unit Envelope.Incoming.t -> Peer.t list Deferred.t
  ; answer_sync_ledger_query :
         (Pasta_bindings.Fp.t * Sync_ledger.Query.t) Envelope.Incoming.t
      -> (Sync_ledger.Answer.t, Error.t) result Deferred.t
  ; get_ancestry :
         ( Consensus.Data.Consensus_state.Value.t
         , Pasta_bindings.Fp.t )
         With_hash.t
         Envelope.Incoming.t
      -> ( Mina_block.t
         , State_body_hash.t list * Mina_block.t )
         Proof_carrying_data.t
         option
         Deferred.t
  ; get_best_tip :
         unit Envelope.Incoming.t
      -> ( Mina_block.t
         , Pasta_bindings.Fp.t list * Mina_block.t )
         Proof_carrying_data.t
         option
         Deferred.t
  ; get_node_status :
         unit Envelope.Incoming.t
      -> (Mina_networking.Rpcs.Get_node_status.Node_status.t, Error.t) result
         Deferred.t
  ; get_transition_knowledge :
      unit Envelope.Incoming.t -> Pasta_bindings.Fp.t list Deferred.t
  ; get_transition_chain_proof :
         Pasta_bindings.Fp.t Envelope.Incoming.t
      -> (Pasta_bindings.Fp.t * Pasta_bindings.Fp.t list) option Deferred.t
  ; get_transition_chain :
         Pasta_bindings.Fp.t list Envelope.Incoming.t
      -> Mina_block.t list option Deferred.t
  }

type peer_network =
  { peer : Network_peer.Peer.t
  ; state : peer_state
  ; network : Mina_networking.t
  }

type nonrec 'n t =
  { fake_gossip_network : Mina_networking.Gossip_net.Fake.network
  ; peer_networks : (peer_network, 'n) Vect.t
  }
  constraint 'n = _ num_peers

val setup :
     logger:Logger.t
  -> ?trust_system:Trust_system.t
  -> ?time_controller:Block_time.Controller.t
  -> precomputed_values:Precomputed_values.t
  -> (peer_state, 'n num_peers) Vect.t
  -> 'n num_peers t

module Generator : sig
  open Quickcheck

  type peer_config =
       logger:Logger.t
    -> precomputed_values:Precomputed_values.t
    -> verifier:Verifier.t
    -> max_frontier_length:int
    -> use_super_catchup:bool
    -> peer_state Generator.t

  val fresh_peer_custom_rpc :
       ?get_staged_ledger_aux_and_pending_coinbases_at_hash:
         (   Pasta_bindings.Fp.t Envelope.Incoming.t
          -> ( Staged_ledger.Scan_state.t
             * Pasta_bindings.Fp.t
             * Pending_coinbase.t
             * Mina_state.Protocol_state.value list )
             option
             Deferred.t)
    -> ?get_some_initial_peers:
         (unit Envelope.Incoming.t -> Peer.t list Deferred.t)
    -> ?answer_sync_ledger_query:
         (   (Pasta_bindings.Fp.t * Sync_ledger.Query.t) Envelope.Incoming.t
          -> (Sync_ledger.Answer.t, Error.t) result Deferred.t)
    -> ?get_ancestry:
         (   ( Consensus.Data.Consensus_state.Value.t
             , Pasta_bindings.Fp.t )
             With_hash.t
             Envelope.Incoming.t
          -> ( Mina_block.t
             , State_body_hash.t list * Mina_block.t )
             Proof_carrying_data.t
             option
             Deferred.t)
    -> ?get_best_tip:
         (   unit Envelope.Incoming.t
          -> ( Mina_block.t
             , Pasta_bindings.Fp.t list * Mina_block.t )
             Proof_carrying_data.t
             option
             Deferred.t)
    -> ?get_node_status:
         (   unit Envelope.Incoming.t
          -> ( Mina_networking.Rpcs.Get_node_status.Node_status.t
             , Error.t )
             result
             Deferred.t)
    -> ?get_transition_knowledge:
         (unit Envelope.Incoming.t -> Pasta_bindings.Fp.t list Deferred.t)
    -> ?get_transition_chain_proof:
         (   Pasta_bindings.Fp.t Envelope.Incoming.t
          -> (Pasta_bindings.Fp.t * Pasta_bindings.Fp.t list) option Deferred.t)
    -> ?get_transition_chain:
         (   Pasta_bindings.Fp.t list Envelope.Incoming.t
          -> Mina_block.t list option Deferred.t)
    -> peer_config

  val fresh_peer : peer_config

  val peer_with_branch_custom_rpc :
       frontier_branch_size:int
    -> ?get_staged_ledger_aux_and_pending_coinbases_at_hash:
         (   Pasta_bindings.Fp.t Envelope.Incoming.t
          -> ( Staged_ledger.Scan_state.t
             * Pasta_bindings.Fp.t
             * Pending_coinbase.t
             * Mina_state.Protocol_state.value list )
             option
             Deferred.t)
    -> ?get_some_initial_peers:
         (unit Envelope.Incoming.t -> Peer.t list Deferred.t)
    -> ?answer_sync_ledger_query:
         (   (Pasta_bindings.Fp.t * Sync_ledger.Query.t) Envelope.Incoming.t
          -> (Sync_ledger.Answer.t, Error.t) result Deferred.t)
    -> ?get_ancestry:
         (   ( Consensus.Data.Consensus_state.Value.t
             , Pasta_bindings.Fp.t )
             With_hash.t
             Envelope.Incoming.t
          -> ( Mina_block.t
             , State_body_hash.t list * Mina_block.t )
             Proof_carrying_data.t
             option
             Deferred.t)
    -> ?get_best_tip:
         (   unit Envelope.Incoming.t
          -> ( Mina_block.t
             , Pasta_bindings.Fp.t list * Mina_block.t )
             Proof_carrying_data.t
             option
             Deferred.t)
    -> ?get_node_status:
         (   unit Envelope.Incoming.t
          -> ( Mina_networking.Rpcs.Get_node_status.Node_status.t
             , Error.t )
             result
             Deferred.t)
    -> ?get_transition_knowledge:
         (unit Envelope.Incoming.t -> Pasta_bindings.Fp.t list Deferred.t)
    -> ?get_transition_chain_proof:
         (   Pasta_bindings.Fp.t Envelope.Incoming.t
          -> (Pasta_bindings.Fp.t * Pasta_bindings.Fp.t list) option Deferred.t)
    -> ?get_transition_chain:
         (   Pasta_bindings.Fp.t list Envelope.Incoming.t
          -> Mina_block.t list option Deferred.t)
    -> peer_config

  val peer_with_branch : frontier_branch_size:int -> peer_config

  val gen :
       ?logger:Logger.t
    -> precomputed_values:Precomputed_values.t
    -> verifier:Verifier.t
    -> max_frontier_length:int
    -> use_super_catchup:bool
    -> (peer_config, 'n num_peers) Vect.t
    -> 'n num_peers t Generator.t
end
