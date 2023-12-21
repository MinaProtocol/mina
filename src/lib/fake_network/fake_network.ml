open Async
open Core
open Mina_base
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
end

(* There must be at least 2 peers to create a network *)
type 'n num_peers = 'n Peano.gt_1

(* TODO: make transition frontier a mutable option *)
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
  let config peer consensus_local_state =
    let trust_system = Trust_system.null () in
    let open Mina_networking.Config in
    don't_wait_for
      (Pipe_lib.Strict_pipe.Reader.iter
         (Trust_system.upcall_pipe trust_system)
         ~f:(const Deferred.unit) ) ;
    { logger
    ; trust_system
    ; time_controller
    ; consensus_local_state
    ; is_seed = Vect.is_empty peers
    ; genesis_ledger_hash =
        Mina_ledger.Ledger.merkle_root
          (Lazy.force (Precomputed_values.genesis_ledger precomputed_values))
    ; constraint_constants = precomputed_values.constraint_constants
    ; consensus_constants = precomputed_values.consensus_constants
    ; precomputed_values
    ; creatable_gossip_net =
        Gossip_net.Any.Creatable
          ( (module Gossip_net.Fake)
          , Gossip_net.Fake.create_instance fake_gossip_network peer )
    ; log_gossip_heard =
        { snark_pool_diff = true
        ; transaction_pool_diff = true
        ; new_state = true
        }
    }
  in
  let peer_networks =
    Vect.map2 peers states ~f:(fun peer state ->
        let network =
          Thread_safe.block_on_async_exn (fun () ->
              (* TODO: merge implementations with mina_lib *)
              Mina_networking.create
                (config peer state.consensus_local_state)
                ~sinks:
                  ( Transition_handler.Block_sink.void
                  , Network_pool.Transaction_pool.Remote_sink.void
                  , Network_pool.Snark_pool.Remote_sink.void )
                ~get_staged_ledger_aux_and_pending_coinbases_at_hash:
                  state.get_staged_ledger_aux_and_pending_coinbases_at_hash
                ~get_some_initial_peers:state.get_some_initial_peers
                ~answer_sync_ledger_query:state.answer_sync_ledger_query
                ~get_ancestry:state.get_ancestry
                ~get_best_tip:state.get_best_tip
                ~get_node_status:state.get_node_status
                ~get_transition_knowledge:state.get_transition_knowledge
                ~get_transition_chain_proof:state.get_transition_chain_proof
                ~get_transition_chain:state.get_transition_chain )
        in
        { peer; state; network } )
  in
  { fake_gossip_network; peer_networks }

module Generator = struct
  open Quickcheck
  open Generator.Let_syntax

  type peer_config =
       context:(module CONTEXT)
    -> verifier:Verifier.t
    -> max_frontier_length:int
    -> use_super_catchup:bool
    -> peer_state Generator.t

  let make_peer_state ?get_staged_ledger_aux_and_pending_coinbases_at_hash
      ?get_some_initial_peers ?answer_sync_ledger_query ?get_ancestry
      ?get_best_tip ?get_node_status ?get_transition_knowledge
      ?get_transition_chain_proof ?get_transition_chain ~frontier
      ~consensus_local_state ~context:(module Context : CONTEXT) =
    let open Context in
    { frontier
    ; consensus_local_state
    ; get_staged_ledger_aux_and_pending_coinbases_at_hash =
        ( match get_staged_ledger_aux_and_pending_coinbases_at_hash with
        | Some f ->
            f
        | None ->
            fun query_env ->
              let input = Envelope.Incoming.data query_env in
              Deferred.return
                (let open Option.Let_syntax in
                let%map ( scan_state
                        , expected_merkle_root
                        , pending_coinbases
                        , protocol_states ) =
                  Sync_handler
                  .get_staged_ledger_aux_and_pending_coinbases_at_hash ~frontier
                    input
                in
                let staged_ledger_hash =
                  Staged_ledger_hash.of_aux_ledger_and_coinbase_hash
                    (Staged_ledger.Scan_state.hash scan_state)
                    expected_merkle_root pending_coinbases
                in
                [%log debug]
                  ~metadata:
                    [ ( "staged_ledger_hash"
                      , Staged_ledger_hash.to_yojson staged_ledger_hash )
                    ]
                  "sending scan state and pending coinbase" ;
                ( scan_state
                , expected_merkle_root
                , pending_coinbases
                , protocol_states )) )
    ; get_some_initial_peers =
        ( match get_some_initial_peers with
        | Some f ->
            f
        | None ->
            fun _ -> Deferred.return [] )
    ; answer_sync_ledger_query =
        ( match answer_sync_ledger_query with
        | Some f ->
            f
        | None ->
            fun query_env ->
              let ledger_hash, _ = Envelope.Incoming.data query_env in
              Sync_handler.answer_query ~frontier ledger_hash
                (Envelope.Incoming.map ~f:Tuple2.get2 query_env)
                ~logger:(Logger.create ()) ~trust_system:(Trust_system.null ())
              |> Deferred.map
                 (* begin error string prefix so we can pattern-match *)
                   ~f:
                     (Result.of_option
                        ~error:
                          (Error.createf
                             !"%s for ledger_hash: %{sexp:Ledger_hash.t}"
                             Mina_networking.refused_answer_query_string
                             ledger_hash ) ) )
    ; get_ancestry =
        ( match get_ancestry with
        | Some f ->
            f
        | None ->
            fun query_env ->
              Deferred.return
                (Sync_handler.Root.prove
                   ~context:(module Context)
                   ~frontier
                   ( Envelope.Incoming.data query_env
                   |> With_hash.map_hash ~f:(fun state_hash ->
                          { State_hash.State_hashes.state_hash
                          ; state_body_hash = None
                          } ) ) ) )
    ; get_best_tip =
        ( match get_best_tip with
        | Some f ->
            f
        | None ->
            fun _ -> failwith "Get_best_tip unimplemented" )
    ; get_node_status =
        ( match get_node_status with
        | Some f ->
            f
        | None ->
            fun _ -> failwith "Get_node_status unimplemented" )
    ; get_transition_knowledge =
        ( match get_transition_knowledge with
        | Some f ->
            f
        | None ->
            fun _query -> Deferred.return (Sync_handler.best_tip_path ~frontier)
        )
    ; get_transition_chain_proof =
        ( match get_transition_chain_proof with
        | Some f ->
            f
        | None ->
            fun query_env ->
              Deferred.return
                (Transition_chain_prover.prove ~frontier
                   (Envelope.Incoming.data query_env) ) )
    ; get_transition_chain =
        ( match get_transition_chain with
        | Some f ->
            f
        | None ->
            fun query_env ->
              Deferred.return
                (Sync_handler.get_transition_chain ~frontier
                   (Envelope.Incoming.data query_env) ) )
    }

  let fresh_peer_custom_rpc ?get_staged_ledger_aux_and_pending_coinbases_at_hash
      ?get_some_initial_peers ?answer_sync_ledger_query ?get_ancestry
      ?get_best_tip ?get_node_status ?get_transition_knowledge
      ?get_transition_chain_proof ?get_transition_chain
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
      ~context:(module Context)
      ?get_staged_ledger_aux_and_pending_coinbases_at_hash
      ?get_some_initial_peers ?answer_sync_ledger_query ?get_ancestry
      ?get_best_tip ?get_node_status ?get_transition_knowledge
      ?get_transition_chain_proof ?get_transition_chain

  let fresh_peer ~context:(module Context : CONTEXT) ~verifier
      ~max_frontier_length ~use_super_catchup =
    fresh_peer_custom_rpc
      ?get_staged_ledger_aux_and_pending_coinbases_at_hash:None
      ?get_some_initial_peers:None ?answer_sync_ledger_query:None
      ?get_ancestry:None ?get_best_tip:None ?get_node_status:None
      ?get_transition_knowledge:None ?get_transition_chain_proof:None
      ?get_transition_chain:None
      ~context:(module Context)
      ~verifier ~max_frontier_length ~use_super_catchup

  let peer_with_branch_custom_rpc ~frontier_branch_size
      ?get_staged_ledger_aux_and_pending_coinbases_at_hash
      ?get_some_initial_peers ?answer_sync_ledger_query ?get_ancestry
      ?get_best_tip ?get_node_status ?get_transition_knowledge
      ?get_transition_chain_proof ?get_transition_chain
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
      ~context:(module Context)
      ?get_staged_ledger_aux_and_pending_coinbases_at_hash
      ?get_some_initial_peers ?answer_sync_ledger_query ?get_ancestry
      ?get_best_tip ?get_node_status ?get_transition_knowledge
      ?get_transition_chain_proof ?get_transition_chain

  let peer_with_branch ~frontier_branch_size ~context:(module Context : CONTEXT)
      ~verifier ~max_frontier_length ~use_super_catchup =
    peer_with_branch_custom_rpc ~frontier_branch_size
      ?get_staged_ledger_aux_and_pending_coinbases_at_hash:None
      ?get_some_initial_peers:None ?answer_sync_ledger_query:None
      ?get_ancestry:None ?get_best_tip:None ?get_node_status:None
      ?get_transition_knowledge:None ?get_transition_chain_proof:None
      ?get_transition_chain:None
      ~context:(module Context)
      ~verifier ~max_frontier_length ~use_super_catchup

  let gen ?(logger = Logger.null ()) ~precomputed_values ~verifier
      ~max_frontier_length ~use_super_catchup
      (configs : (peer_config, 'n num_peers) Gadt_lib.Vect.t) =
    (* TODO: Pass in *)
    let module Context = struct
      let logger = logger

      let precomputed_values = precomputed_values

      let constraint_constants =
        precomputed_values.Precomputed_values.constraint_constants

      let consensus_constants =
        precomputed_values.Precomputed_values.consensus_constants
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
