open Core
open Coda_base
open Gadt_lib

type peer_network =
  { peer: Network_peer.Peer.t
  ; frontier: Transition_frontier.t
  ; network: Coda_networking.t }

type nonrec 'num_peers t =
  { fake_gossip_network: Coda_networking.Gossip_net.Fake.network
  ; peer_networks: (peer_network, 'num_peers) Vect.t }

val setup :
     ?logger:Logger.t
  -> ?trust_system:Trust_system.t
  -> ?time_controller:Block_time.Controller.t
  -> consensus_local_state:Consensus.Data.Local_state.t
  -> (Transition_frontier.t, 'n) Vect.t
  -> 'n t

module Generator : sig
  open Quickcheck

  type peer_config =
       max_frontier_length:int
    -> consensus_local_state:Consensus.Data.Local_state.t
    -> Transition_frontier.t Generator.t

  val fresh_peer : peer_config

  val peer_with_branch : frontier_branch_size:int -> peer_config

  val gen :
    max_frontier_length:int -> (peer_config, 'n) Vect.t -> 'n t Generator.t
end
