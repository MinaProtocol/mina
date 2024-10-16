open Core
open Gadt_lib
module Sync_ledger = Mina_ledger.Sync_ledger

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t

  val compile_config : Mina_compile_config.t
end

(* There must be at least 2 peers to create a network *)
type 'n num_peers = 'n Peano.gt_1

type peer_state =
  { frontier : Transition_frontier.t
  ; consensus_local_state : Consensus.Data.Local_state.t
  ; rpc_mocks : Mina_networking.Gossip_net.Fake.rpc_mocks
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

include sig
  open Mina_networking

  type 'a fn_with_mocks =
       ?get_some_initial_peers:
         ( Rpcs.Get_some_initial_peers.query
         , Rpcs.Get_some_initial_peers.response )
         Gossip_net.Fake.rpc_mock
    -> ?get_staged_ledger_aux_and_pending_coinbases_at_hash:
         ( Rpcs.Get_staged_ledger_aux_and_pending_coinbases_at_hash.query
         , Rpcs.Get_staged_ledger_aux_and_pending_coinbases_at_hash.response )
         Gossip_net.Fake.rpc_mock
    -> ?answer_sync_ledger_query:
         ( Rpcs.Answer_sync_ledger_query.query
         , Rpcs.Answer_sync_ledger_query.response )
         Gossip_net.Fake.rpc_mock
    -> ?get_transition_chain:
         ( Rpcs.Get_transition_chain.query
         , Rpcs.Get_transition_chain.response )
         Gossip_net.Fake.rpc_mock
    -> ?get_transition_knowledge:
         ( Rpcs.Get_transition_knowledge.query
         , Rpcs.Get_transition_knowledge.response )
         Gossip_net.Fake.rpc_mock
    -> ?get_transition_chain_proof:
         ( Rpcs.Get_transition_chain_proof.query
         , Rpcs.Get_transition_chain_proof.response )
         Gossip_net.Fake.rpc_mock
    -> ?get_ancestry:
         ( Rpcs.Get_ancestry.query
         , Rpcs.Get_ancestry.response )
         Gossip_net.Fake.rpc_mock
    -> ?get_best_tip:
         ( Rpcs.Get_best_tip.query
         , Rpcs.Get_best_tip.response )
         Gossip_net.Fake.rpc_mock
    -> 'a
end

module Generator : sig
  open Quickcheck

  type peer_config =
       context:(module CONTEXT)
    -> verifier:Verifier.t
    -> max_frontier_length:int
    -> use_super_catchup:bool
    -> peer_state Generator.t

  val fresh_peer_custom_rpc : peer_config fn_with_mocks

  val fresh_peer : peer_config

  val peer_with_branch_custom_rpc :
    frontier_branch_size:int -> peer_config fn_with_mocks

  val peer_with_branch : frontier_branch_size:int -> peer_config

  val gen :
       ?logger:Logger.t
    -> precomputed_values:Precomputed_values.t
    -> verifier:Verifier.t
    -> max_frontier_length:int
    -> use_super_catchup:bool
    -> (peer_config, 'n num_peers) Vect.t
    -> compile_config:Mina_compile_config.t
    -> 'n num_peers t Generator.t
end
