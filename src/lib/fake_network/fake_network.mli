open Async
open Core
open Gadt_lib
open Network_peer

(* There must be at least 2 peers to create a network *)
type 'n num_peers = 'n Peano.gt_1

type peer_state =
  { frontier : Transition_frontier.t
  ; consensus_local_state : Consensus.Data.Local_state.t
  ; get_transition_chain_impl :
      (   Mina_networking.Rpcs.Get_transition_chain.query Envelope.Incoming.t
       -> Mina_networking.Rpcs.Get_transition_chain.response Deferred.t)
      option
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
     ?logger:Logger.t
  -> ?trust_system:Trust_system.t
  -> ?time_controller:Block_time.Controller.t
  -> precomputed_values:Precomputed_values.t
  -> (peer_state, 'n num_peers) Vect.t
  -> 'n num_peers t

module Verifier_dummy_success = Verifier.Dummy

module MakeGenerator (Test_verifier : sig
  type t

  type ledger_proof

  val create :
       logger:Logger.t
    -> proof_level:Genesis_constants.Proof_level.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> pids:Child_processes.Termination.t
    -> conf_dir:string option
    -> t Deferred.t

  val verify_blockchain_snark :
    t -> Blockchain_snark.Blockchain.t list -> bool Or_error.t Deferred.t

  val verify_transaction_snarks :
       t
    -> (ledger_proof * Mina_base.Sok_message.t) list
    -> bool Or_error.t Deferred.t

  val verify_commands :
       t
    -> Mina_base.User_command.Verifiable.t list
       (* The first level of error represents failure to verify, the second a failure in
          communicating with the verifier. *)
    -> [ `Valid of Mina_base.User_command.Valid.t
       | `Invalid
       | `Valid_assuming of
         ( Pickles.Side_loaded.Verification_key.t
         * Mina_base.Snapp_statement.t
         * Pickles.Side_loaded.Proof.t )
         list ]
       list
       Deferred.Or_error.t
end) : sig
  open Quickcheck

  type peer_config =
       precomputed_values:Precomputed_values.t
    -> verifier:Test_verifier.t
    -> max_frontier_length:int
    -> use_super_catchup:bool
    -> peer_state Generator.t

  val fresh_peer : peer_config

  val peer_with_branch : frontier_branch_size:int -> peer_config

  val broken_rpc_peer_branch :
       frontier_branch_size:int
    -> get_transition_chain_impl_option:
         (   Mina_networking.Rpcs.Get_transition_chain.query Envelope.Incoming.t
          -> Mina_networking.Rpcs.Get_transition_chain.response Deferred.t)
         option
    -> peer_config

  val gen :
       precomputed_values:Precomputed_values.t
    -> verifier:Test_verifier.t
    -> max_frontier_length:int
    -> use_super_catchup:bool
    -> (peer_config, 'n num_peers) Vect.t
    -> 'n num_peers t Generator.t
end
