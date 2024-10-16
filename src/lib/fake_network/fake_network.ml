open Async
open Core
module Sync_ledger = Mina_ledger.Sync_ledger
open Gadt_lib
open Signature_lib
open Network_peer
module Gossip_net = Mina_networking.Gossip_net

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t

  val compile_config : Mina_compile_config.t
end

(* There must be at least 2 peers to create a network *)
type 'n num_peers = 'n Peano.gt_1

(* TODO: make transition frontier a mutable option *)
type peer_state =
  { frontier : Transition_frontier.t
  ; consensus_local_state : Consensus.Data.Local_state.t
  ; rpc_mocks : Gossip_net.Fake.rpc_mocks
  }

type peer_network =
  { peer : Network_peer.Peer.t
  ; state : peer_state
  ; network : Mina_networking.t
  }

type nonrec 'n t =
  { fake_gossip_network : Gossip_net.Fake.network
  ; peer_networks : (peer_network, 'n) Vect.t
  }
  constraint 'n = _ num_peers

module Constants = struct
  let init_ip = Int32.of_int_exn 1

  let init_discovery_port = 1337
end

let setup (type n) ~context:(module Context : CONTEXT)
    ?(time_controller = Block_time.Controller.basic ~logger:Context.logger)
    (states : (peer_state, n num_peers) Vect.t) : n num_peers t =
  let open Context in
  let _, peers =
    Vect.fold_map states
      ~init:(Constants.init_ip, Constants.init_discovery_port)
      ~f:(fun (ip, libp2p_port) _ ->
        (* each peer has a distinct IP address, so we lookup frontiers by IP *)
        let peer =
          Network_peer.Peer.create
            (Unix.Inet_addr.inet4_addr_of_int32 ip)
            ~libp2p_port
            ~peer_id:
              (Peer.Id.unsafe_of_string
                 (sprintf "fake peer at port %d" libp2p_port) )
        in
        ((Int32.( + ) Int32.one ip, libp2p_port + 1), peer) )
  in
  let fake_gossip_network =
    Gossip_net.Fake.create_network (Vect.to_list peers)
  in
  let context trust_system consensus_local_state :
      (module Mina_networking.CONTEXT) =
    ( module struct
      include Context

      let trust_system = trust_system

      let time_controller = time_controller

      let consensus_local_state = consensus_local_state
    end )
  in
  let config rpc_mocks peer =
    let open Mina_networking.Config in
    { is_seed = Vect.is_empty peers
    ; genesis_ledger_hash =
        Mina_ledger.Ledger.merkle_root
          (Lazy.force (Precomputed_values.genesis_ledger precomputed_values))
    ; creatable_gossip_net =
        Gossip_net.Any.Creatable
          ( (module Gossip_net.Fake)
          , Gossip_net.Fake.create_instance ~network:fake_gossip_network
              ~rpc_mocks ~local_ip:peer )
    ; log_gossip_heard =
        { snark_pool_diff = true
        ; transaction_pool_diff = true
        ; new_state = true
        }
    }
  in
  let get_node_status _ = failwith "unimplemented" in
  let peer_networks =
    Vect.map2 peers states ~f:(fun peer state ->
        let trust_system = Trust_system.null () in
        don't_wait_for
          (Pipe_lib.Strict_pipe.Reader.iter
             Trust_system.(upcall_pipe trust_system)
             ~f:(const Deferred.unit) ) ;
        let network =
          Thread_safe.block_on_async_exn (fun () ->
              Mina_networking.create
                (context trust_system state.consensus_local_state)
                (config state.rpc_mocks peer)
                ~sinks:
                  ( Transition_handler.Block_sink.void
                  , Network_pool.Transaction_pool.Remote_sink.void
                  , Network_pool.Snark_pool.Remote_sink.void )
                ~get_transition_frontier:(Fn.const (Some state.frontier))
                ~get_node_status )
        in
        { peer; state; network } )
  in
  { fake_gossip_network; peer_networks }

include struct
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

  let make_peer_state :
      (   frontier:Transition_frontier.t
       -> consensus_local_state:Consensus.Data.Local_state.t
       -> peer_state )
      fn_with_mocks =
   fun ?get_some_initial_peers
       ?get_staged_ledger_aux_and_pending_coinbases_at_hash
       ?answer_sync_ledger_query ?get_transition_chain ?get_transition_knowledge
       ?get_transition_chain_proof ?get_ancestry ?get_best_tip ~frontier
       ~consensus_local_state ->
    let rpc_mocks : Gossip_net.Fake.rpc_mocks =
      let get_mock (type q r) (rpc : (q, r) Rpcs.rpc) :
          (q, r) Gossip_net.Fake.rpc_mock option =
        match rpc with
        | Get_some_initial_peers ->
            get_some_initial_peers
        | Get_staged_ledger_aux_and_pending_coinbases_at_hash ->
            get_staged_ledger_aux_and_pending_coinbases_at_hash
        | Answer_sync_ledger_query ->
            answer_sync_ledger_query
        | Get_transition_chain ->
            get_transition_chain
        | Get_transition_knowledge ->
            get_transition_knowledge
        | Get_transition_chain_proof ->
            get_transition_chain_proof
        | Get_ancestry ->
            get_ancestry
        | Ban_notify ->
            None
        | Get_best_tip ->
            get_best_tip
      in
      { get_mock }
    in
    { frontier; consensus_local_state; rpc_mocks }
end

module Generator = struct
  open Quickcheck
  open Generator.Let_syntax

  type peer_config =
       context:(module CONTEXT)
    -> verifier:Verifier.t
    -> max_frontier_length:int
    -> use_super_catchup:bool
    -> peer_state Generator.t

  let fresh_peer_custom_rpc ?get_some_initial_peers
      ?get_staged_ledger_aux_and_pending_coinbases_at_hash
      ?answer_sync_ledger_query ?get_transition_chain ?get_transition_knowledge
      ?get_transition_chain_proof ?get_ancestry ?get_best_tip
      ~context:(module Context : CONTEXT) ~verifier ~max_frontier_length
      ~use_super_catchup =
    let open Context in
    let epoch_ledger_location =
      Filename.temp_dir_name ^/ "epoch_ledger"
      ^ (Uuid_unix.create () |> Uuid.to_string)
    in
    let genesis_ledger = Precomputed_values.genesis_ledger precomputed_values in
    let consensus_local_state =
      Consensus.Data.Local_state.create Public_key.Compressed.Set.empty
        ~context:(module Context)
        ~genesis_ledger
        ~genesis_epoch_data:precomputed_values.genesis_epoch_data
        ~epoch_ledger_location
        ~genesis_state_hash:
          precomputed_values.protocol_state_with_hashes.hash.state_hash
    in
    let%map frontier =
      Transition_frontier.For_tests.gen ~precomputed_values ~verifier
        ~consensus_local_state ~max_length:max_frontier_length ~size:0
        ~use_super_catchup ()
    in
    make_peer_state ~frontier ~consensus_local_state
      ?get_staged_ledger_aux_and_pending_coinbases_at_hash
      ?get_some_initial_peers ?answer_sync_ledger_query ?get_ancestry
      ?get_best_tip ?get_transition_knowledge ?get_transition_chain_proof
      ?get_transition_chain

  let fresh_peer ~context:(module Context : CONTEXT) ~verifier
      ~max_frontier_length ~use_super_catchup =
    fresh_peer_custom_rpc
      ?get_staged_ledger_aux_and_pending_coinbases_at_hash:None
      ?get_some_initial_peers:None ?answer_sync_ledger_query:None
      ?get_ancestry:None ?get_best_tip:None ?get_transition_knowledge:None
      ?get_transition_chain_proof:None ?get_transition_chain:None
      ~context:(module Context)
      ~verifier ~max_frontier_length ~use_super_catchup

  let peer_with_branch_custom_rpc ~frontier_branch_size ?get_some_initial_peers
      ?get_staged_ledger_aux_and_pending_coinbases_at_hash
      ?answer_sync_ledger_query ?get_transition_chain ?get_transition_knowledge
      ?get_transition_chain_proof ?get_ancestry ?get_best_tip
      ~context:(module Context : CONTEXT) ~verifier ~max_frontier_length
      ~use_super_catchup =
    let open Context in
    let epoch_ledger_location =
      Filename.temp_dir_name ^/ "epoch_ledger"
      ^ (Uuid_unix.create () |> Uuid.to_string)
    in
    let genesis_ledger = Precomputed_values.genesis_ledger precomputed_values in
    let consensus_local_state =
      Consensus.Data.Local_state.create Public_key.Compressed.Set.empty
        ~context:(module Context)
        ~genesis_ledger
        ~genesis_epoch_data:precomputed_values.genesis_epoch_data
        ~epoch_ledger_location
        ~genesis_state_hash:
          precomputed_values.protocol_state_with_hashes.hash.state_hash
    in
    let%map frontier, branch =
      Transition_frontier.For_tests.gen_with_branch ~precomputed_values
        ~verifier ~use_super_catchup ~max_length:max_frontier_length
        ~frontier_size:0 ~branch_size:frontier_branch_size
        ~consensus_local_state ()
    in
    Async.Thread_safe.block_on_async_exn (fun () ->
        Deferred.List.iter branch
          ~f:(Transition_frontier.add_breadcrumb_exn frontier) ) ;

    make_peer_state ~frontier ~consensus_local_state
      ?get_staged_ledger_aux_and_pending_coinbases_at_hash
      ?get_some_initial_peers ?answer_sync_ledger_query ?get_ancestry
      ?get_best_tip ?get_transition_knowledge ?get_transition_chain_proof
      ?get_transition_chain

  let peer_with_branch ~frontier_branch_size ~context:(module Context : CONTEXT)
      ~verifier ~max_frontier_length ~use_super_catchup =
    peer_with_branch_custom_rpc ~frontier_branch_size
      ?get_staged_ledger_aux_and_pending_coinbases_at_hash:None
      ?get_some_initial_peers:None ?answer_sync_ledger_query:None
      ?get_ancestry:None ?get_best_tip:None ?get_transition_knowledge:None
      ?get_transition_chain_proof:None ?get_transition_chain:None
      ~context:(module Context)
      ~verifier ~max_frontier_length ~use_super_catchup

  let gen ?(logger = Logger.null ()) ~precomputed_values ~verifier
      ~max_frontier_length ~use_super_catchup
      (configs : (peer_config, 'n num_peers) Gadt_lib.Vect.t) ~compile_config =
    (* TODO: Pass in *)
    let module Context = struct
      let logger = logger

      let precomputed_values = precomputed_values

      let constraint_constants =
        precomputed_values.Precomputed_values.constraint_constants

      let consensus_constants =
        precomputed_values.Precomputed_values.consensus_constants

      let compile_config = compile_config
    end in
    let open Quickcheck.Generator.Let_syntax in
    let%map states =
      Vect.Quickcheck_generator.map configs ~f:(fun (config : peer_config) ->
          config
            ~context:(module Context)
            ~verifier ~max_frontier_length ~use_super_catchup )
    in
    setup ~context:(module Context) states
end
