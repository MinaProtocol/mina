(** Persona -> Daemon_rpcs.Types.Status.t adapter.

    Builds a real [Daemon_rpcs.Types.Status.t] record from the canned
    persona JSON so the mock can serve [daemonStatus] queries through
    the shared [Mina_graphql.Types.Make_daemon_status] functor without
    maintaining a parallel mock DaemonStatus type.

    Fields without persona counterparts (histograms, catchup_status,
    next_block_production, consensus_time_best_tip) return [None].
    Synthetic values cover the few non-option fields the persona doesn't
    yet provide (peers list, addrs_and_ports, metrics, consensus_time_now). *)

open Core

(* Mainnet-flavored consensus constants, built from the compiled defaults.
   Used both for [Consensus_time.zero] (to supply [consensus_time_now] in
   the Status record) and as the functor's [consensus_constants] callback
   so [ConsensusTime.startTime/endTime] resolvers can compute reasonable
   values for whatever [Consensus_time.t] the mock surfaces. *)
let mock_consensus_constants : Consensus.Constants.t =
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let protocol_constants =
    Genesis_constants.Compiled.genesis_constants.protocol
  in
  Consensus.Constants.create ~constraint_constants ~protocol_constants

let synthetic_peers (n : int) : Network_peer.Peer.Display.t list =
  List.init n ~f:(fun i ->
      { Network_peer.Peer.Display.host = Printf.sprintf "192.0.2.%d" (i + 1)
      ; libp2p_port = 8302
      ; peer_id =
          Printf.sprintf
            "12D3KooWMockPeerId%dxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" i
      } )

let synthetic_self_peer : Network_peer.Peer.Display.t =
  { host = "127.0.0.1"
  ; libp2p_port = 8302
  ; peer_id = "12D3KooWMockSelfPeerIdxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  }

let synthetic_addrs_and_ports : Node_addrs_and_ports.Display.t =
  { external_ip = "203.0.113.42"
  ; bind_ip = "0.0.0.0"
  ; peer = Some synthetic_self_peer
  ; libp2p_port = 8302
  ; client_port = 8301
  }

let synthetic_metrics : Daemon_rpcs.Types.Status.Metrics.t =
  { block_production_delay = []
  ; transaction_pool_diff_received = 0
  ; transaction_pool_diff_broadcasted = 0
  ; transactions_added_to_pool = 0
  ; transaction_pool_size = 0
  ; snark_pool_diff_received = 0
  ; snark_pool_diff_broadcasted = 0
  ; pending_snark_work = 0
  ; snark_pool_size = 0
  }

let parse_sync_status (s : string) : Sync_status.t =
  match Sync_status.of_string s with
  | Ok status ->
      status
  | Error _ ->
      `Synced

let build (p : Persona.t) : Daemon_rpcs.Types.Status.t =
  let d = p.daemon in
  { num_accounts = d.num_accounts
  ; blockchain_length = Some d.blockchain_length
  ; highest_block_length_received = d.highest_block_length_received
  ; highest_unvalidated_block_length_received =
      d.highest_unvalidated_block_length_received
  ; uptime_secs = d.uptime_secs
  ; ledger_merkle_root = d.ledger_merkle_root
  ; state_hash = d.state_hash
  ; chain_id = d.chain_id
  ; commit_id = d.commit_id
  ; conf_dir = d.conf_dir
  ; peers = synthetic_peers d.peers
  ; user_commands_sent = d.user_commands_sent
  ; snark_worker = d.snark_worker
  ; snark_work_fee = d.snark_work_fee
  ; sync_status = parse_sync_status d.sync_status
  ; catchup_status = None
  ; block_production_keys = [ d.block_producer_account ]
  ; coinbase_receiver = d.coinbase_receiver
  ; histograms = None
  ; consensus_time_best_tip = None
  ; global_slot_since_genesis_best_tip = d.global_slot_since_genesis_best_tip
  ; next_block_production = None
  ; consensus_time_now =
      Consensus.Data.Consensus_time.zero ~constants:mock_consensus_constants
  ; consensus_mechanism = d.consensus_mechanism
  ; consensus_configuration =
      Consensus.Configuration.t
        ~constraint_constants:Genesis_constants.Compiled.constraint_constants
        ~protocol_constants:
          Genesis_constants.Compiled.genesis_constants.protocol
  ; addrs_and_ports = synthetic_addrs_and_ports
  ; metrics = synthetic_metrics
  }
