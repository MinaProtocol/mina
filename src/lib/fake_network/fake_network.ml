open Async
open Core
open Coda_base
open Gadt_lib
open Signature_lib
open Network_peer
module Gossip_net = Coda_networking.Gossip_net

(* There must be at least 2 peers to create a network *)
type 'n num_peers = 'n Peano.gt_1

(* TODO: make transition frontier a mutable option *)
type peer_state =
  { frontier: Transition_frontier.t
  ; consensus_local_state: Consensus.Data.Local_state.t
  ; genesis_constants: Genesis_constants.t }

type peer_network =
  {peer: Network_peer.Peer.t; state: peer_state; network: Coda_networking.t}

type nonrec 'n t =
  { fake_gossip_network: Gossip_net.Fake.network
  ; peer_networks: (peer_network, 'n) Vect.t }
  constraint 'n = _ num_peers

module Constants = struct
  let init_ip = Int32.of_int_exn 1

  let init_discovery_port = 1337
end

let setup (type n) ?(logger = Logger.null ())
    ?(trust_system = Trust_system.null ())
    ?(time_controller = Block_time.Controller.basic ~logger)
    (states : (peer_state, n num_peers) Vect.t) : n num_peers t =
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
                 (sprintf "fake peer at port %d" libp2p_port))
        in
        ((Int32.( + ) Int32.one ip, libp2p_port + 1), peer) )
  in
  let fake_gossip_network =
    Gossip_net.Fake.create_network (Vect.to_list peers)
  in
  let config peer genesis_constants consensus_local_state =
    let open Coda_networking.Config in
    { logger
    ; trust_system
    ; time_controller
    ; consensus_local_state
    ; is_seed= Vect.is_empty peers
    ; genesis_ledger_hash=
        Ledger.merkle_root (Lazy.force Test_genesis_ledger.t)
    ; creatable_gossip_net=
        Gossip_net.Any.Creatable
          ( (module Gossip_net.Fake)
          , Gossip_net.Fake.create_instance fake_gossip_network peer )
    ; log_gossip_heard=
        {snark_pool_diff= true; transaction_pool_diff= true; new_state= true}
    ; genesis_constants }
  in
  let peer_networks =
    Vect.map2 peers states ~f:(fun peer state ->
        let frontier = state.frontier in
        let network =
          Thread_safe.block_on_async_exn (fun () ->
              (* TODO: merge implementations with coda_lib *)
              Coda_networking.create
                (config peer state.genesis_constants
                   state.consensus_local_state)
                ~get_staged_ledger_aux_and_pending_coinbases_at_hash:
                  (fun query_env ->
                  let input = Envelope.Incoming.data query_env in
                  Deferred.return
                    (let open Option.Let_syntax in
                    let%map scan_state, expected_merkle_root, pending_coinbases
                        =
                      Sync_handler
                      .get_staged_ledger_aux_and_pending_coinbases_at_hash
                        ~frontier input
                    in
                    let staged_ledger_hash =
                      Staged_ledger_hash.of_aux_ledger_and_coinbase_hash
                        (Staged_ledger.Scan_state.hash scan_state)
                        expected_merkle_root pending_coinbases
                    in
                    Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
                      ~metadata:
                        [ ( "staged_ledger_hash"
                          , Staged_ledger_hash.to_yojson staged_ledger_hash )
                        ]
                      "sending scan state and pending coinbase" ;
                    (scan_state, expected_merkle_root, pending_coinbases)) )
                ~answer_sync_ledger_query:(fun _ ->
                  failwith "Answer_sync_ledger_query unimplemented" )
                ~get_ancestry:(fun query_env ->
                  Deferred.return
                    (Sync_handler.Root.prove ~logger ~frontier
                       (Envelope.Incoming.data query_env)) )
                ~get_best_tip:(fun _ -> failwith "Get_best_tip unimplemented")
                ~get_telemetry_data:(fun _ ->
                  failwith "Get_telemetry data unimplemented" )
                ~get_transition_chain_proof:(fun query_env ->
                  Deferred.return
                    (Transition_chain_prover.prove ~frontier
                       (Envelope.Incoming.data query_env)) )
                ~get_transition_chain:(fun query_env ->
                  Deferred.return
                    (Sync_handler.get_transition_chain ~frontier
                       (Envelope.Incoming.data query_env)) ) )
        in
        {peer; state; network} )
  in
  {fake_gossip_network; peer_networks}

module Generator = struct
  open Quickcheck
  open Generator.Let_syntax

  type peer_config =
       genesis_constants:Genesis_constants.t
    -> max_frontier_length:int
    -> peer_state Generator.t

  let fresh_peer ~genesis_constants ~max_frontier_length =
    let consensus_local_state =
      Consensus.Data.Local_state.create Public_key.Compressed.Set.empty
        ~genesis_ledger:Test_genesis_ledger.t
    in
    let%map frontier =
      Transition_frontier.For_tests.gen ~consensus_local_state
        ~genesis_constants ~max_length:max_frontier_length ~size:0 ()
    in
    {frontier; consensus_local_state; genesis_constants}

  let peer_with_branch ~frontier_branch_size ~genesis_constants
      ~max_frontier_length =
    let consensus_local_state =
      Consensus.Data.Local_state.create Public_key.Compressed.Set.empty
        ~genesis_ledger:Test_genesis_ledger.t
    in
    let%map frontier, branch =
      Transition_frontier.For_tests.gen_with_branch ~genesis_constants
        ~max_length:max_frontier_length ~frontier_size:0
        ~branch_size:frontier_branch_size ~consensus_local_state ()
    in
    Async.Thread_safe.block_on_async_exn (fun () ->
        Deferred.List.iter branch
          ~f:(Transition_frontier.add_breadcrumb_exn frontier) ) ;
    {frontier; consensus_local_state; genesis_constants}

  let gen ~genesis_constants ~max_frontier_length configs =
    let open Quickcheck.Generator.Let_syntax in
    let%map states =
      Vect.Quickcheck_generator.map configs ~f:(fun (config : peer_config) ->
          config ~genesis_constants ~max_frontier_length )
    in
    setup states
end

(*
let send_transition ~logger ~transition_writer ~peer:{peer; frontier}
    state_hash =
  let transition =
    let validated_transition =
      Transition_frontier.find_exn frontier state_hash
      |> Transition_frontier.Breadcrumb.validated_transition
    in
    validated_transition
    |> External_transition.Validation
       .reset_frontier_dependencies_validation
    |> External_transition.Validation.reset_staged_ledger_diff_validation
  in
  Logger.info logger ~module_:__MODULE__ ~location:__LOC__
    ~metadata:
      [ ("peer", Network_peer.Peer.to_yojson peer)
      ; ("state_hash", State_hash.to_yojson state_hash) ]
    "Peer $peer sending $state_hash" ;
  let enveloped_transition =
    Envelope.Incoming.wrap ~data:transition
      ~sender:(Envelope.Sender.Remote peer.host)
  in
  Pipe_lib.Strict_pipe.Writer.write transition_writer
    (`Transition enveloped_transition, `Time_received Constants.time)

let make_transition_pipe () =
  Pipe_lib.Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
    (Buffered (`Capacity 30, `Overflow Drop_head))
*)
