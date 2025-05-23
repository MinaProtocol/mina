open Core
open Async
open Mina_base
open Bootstrap_controller
module Ledger = Mina_ledger.Ledger
module Sync_ledger = Mina_ledger.Sync_ledger
open Mina_state
open Pipe_lib.Strict_pipe
open Network_peer

(* Test setup - replicating the test module setup from bootstrap_controller.ml *)
let max_frontier_length =
  Transition_frontier.global_max_length Genesis_constants.For_unit_tests.t

let logger = Logger.null ()

let () =
  (* Disable log messages from best_tip_diff logger. *)
  Logger.Consumer_registry.register ~commit_id:""
    ~id:Logger.Logger_id.best_tip_diff ~processor:(Logger.Processor.raw ())
    ~transport:
      (Logger.Transport.create
         ( module struct
           type t = unit

           let transport () _ = ()
         end )
         () )
    ()

let trust_system =
  let s = Trust_system.null () in
  don't_wait_for
    (Pipe_lib.Strict_pipe.Reader.iter
       (Trust_system.upcall_pipe s)
       ~f:(const Deferred.unit) ) ;
  s

let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

let proof_level = precomputed_values.proof_level

let constraint_constants = precomputed_values.constraint_constants

let ledger_sync_config =
  Syncable_ledger.create_config
    ~compile_config:Mina_compile_config.For_unit_tests.t ~max_subtree_depth:None
    ~default_subtree_depth:None ()

module Context = struct
  let logger = logger

  let precomputed_values = precomputed_values

  let constraint_constants =
    Genesis_constants.For_unit_tests.Constraint_constants.t

  let consensus_constants = precomputed_values.consensus_constants

  let ledger_sync_config =
    Syncable_ledger.create_config
      ~compile_config:Mina_compile_config.For_unit_tests.t
      ~max_subtree_depth:None ~default_subtree_depth:None ()

  let proof_cache_db = Proof_cache_tag.For_tests.create_db ()
end

let verifier =
  Async.Thread_safe.block_on_async_exn (fun () ->
      Verifier.For_tests.default ~constraint_constants ~logger ~proof_level () )

module Genesis_ledger = (val precomputed_values.genesis_ledger)

let downcast_transition ~sender transition =
  let transition =
    transition |> Mina_block.Validated.remember
    |> Mina_block.Validation.reset_frontier_dependencies_validation
    |> Mina_block.Validation.reset_staged_ledger_diff_validation
  in
  Envelope.Incoming.wrap ~data:transition ~sender:(Envelope.Sender.Remote sender)

let downcast_breadcrumb ~sender breadcrumb =
  downcast_transition ~sender
    (Transition_frontier.Breadcrumb.validated_transition breadcrumb)

let make_non_running_bootstrap ~genesis_root ~network =
  let transition =
    genesis_root |> Mina_block.Validation.reset_frontier_dependencies_validation
    |> Mina_block.Validation.reset_staged_ledger_diff_validation
  in
  let open Bootstrap_controller in
  { context = (module Context)
  ; trust_system
  ; verifier
  ; best_seen_transition = transition
  ; current_root = transition
  ; network
  ; num_of_root_snarked_ledger_retargeted = 0
  }

let run_bootstrap ~timeout_duration ~my_net ~transition_reader =
  let open Fake_network in
  let time_controller = Block_time.Controller.basic ~logger in
  let persistent_root =
    Transition_frontier.persistent_root my_net.state.frontier
  in
  let persistent_frontier =
    Transition_frontier.persistent_frontier my_net.state.frontier
  in
  let initial_root_transition =
    Transition_frontier.(
      Breadcrumb.validated_transition (root my_net.state.frontier))
  in
  let%bind () = Transition_frontier.close ~loc:__LOC__ my_net.state.frontier in
  [%log info] "bootstrap begin" ;
  Block_time.Timeout.await_exn time_controller ~timeout_duration
    (run
       ~context:(module Context)
       ~trust_system ~verifier ~network:my_net.network ~preferred_peers:[]
       ~consensus_local_state:my_net.state.consensus_local_state
       ~transition_reader ~persistent_root ~persistent_frontier
       ~catchup_mode:`Super ~initial_root_transition )

let assert_transitions_increasingly_sorted ~root
    (incoming_transitions : Transition_cache.element list) =
  let root = Transition_frontier.Breadcrumb.block root |> Mina_block.header in
  ignore
    ( List.fold_result ~init:root incoming_transitions
        ~f:(fun max_acc incoming_transition ->
          let With_hash.{ data = header; _ } =
            Transition_cache.header_with_hash
              (Envelope.Incoming.data @@ fst incoming_transition)
          in
          let header_len h =
            Mina_block.Header.protocol_state h
            |> Protocol_state.consensus_state
            |> Consensus.Data.Consensus_state.blockchain_length
          in
          let open Result.Let_syntax in
          let%map () =
            Result.ok_if_true
              Mina_numbers.Length.(header_len max_acc <= header_len header)
              ~error:
                (Error.of_string "The blocks are not sorted in increasing order")
          in
          header )
      |> Or_error.ok_exn
      : Mina_block.Header.t )

(* Test 1: Bootstrap controller caches all transitions *)
let test_bootstrap_caches_transitions () =
  let branch_size = (max_frontier_length * 2) + 2 in
  Quickcheck.test ~trials:1
    (let open Quickcheck.Generator.Let_syntax in
    (* we only need one node for this test, but we need more than one peer so that mina_networking does not throw an error *)
    let%bind fake_network =
      Fake_network.Generator.(
        gen ~precomputed_values ~verifier ~max_frontier_length
          ~ledger_sync_config [ fresh_peer; fresh_peer ])
    in
    let%map make_branch =
      Transition_frontier.Breadcrumb.For_tests.gen_seq ~precomputed_values
        ~verifier
        ~accounts_with_secret_keys:(Lazy.force Genesis_ledger.accounts)
        branch_size
    in
    let [ me; _ ] = fake_network.peer_networks in
    let branch =
      Async.Thread_safe.block_on_async_exn (fun () ->
          make_branch (Transition_frontier.root me.state.frontier) )
    in
    (fake_network, branch))
    ~f:(fun (fake_network, branch) ->
      let [ me; other ] = fake_network.peer_networks in
      let genesis_root =
        Transition_frontier.(
          Breadcrumb.validated_transition @@ root me.state.frontier)
        |> Mina_block.Validated.remember
      in
      let transition_graph = Transition_cache.create () in
      let sync_ledger_reader, sync_ledger_writer =
        Pipe_lib.Strict_pipe.create ~name:"sync_ledger_reader" Synchronous
      in
      let bootstrap =
        make_non_running_bootstrap ~genesis_root ~network:me.network
      in
      let root_sync_ledger =
        Sync_ledger.Db.create
          (Transition_frontier.root_snarked_ledger me.state.frontier)
          ~context:(module Context)
          ~trust_system
      in
      Async.Thread_safe.block_on_async_exn (fun () ->
          let sync_deferred =
            sync_ledger bootstrap ~root_sync_ledger ~transition_graph
              ~preferred:[] ~sync_ledger_reader
          in
          let%bind () =
            Deferred.List.iter branch ~f:(fun breadcrumb ->
                Strict_pipe.Writer.write sync_ledger_writer
                  ( `Block (downcast_breadcrumb ~sender:other.peer breadcrumb)
                  , `Valid_cb None ) )
          in
          Strict_pipe.Writer.close sync_ledger_writer ;
          sync_deferred ) ;
      let expected_transitions =
        List.map branch
          ~f:
            (Fn.compose
               (With_hash.map ~f:Mina_block.header)
               (Fn.compose Mina_block.Validation.block_with_hash
                  (Fn.compose Mina_block.Validated.remember
                     Transition_frontier.Breadcrumb.validated_transition ) ) )
      in
      let saved_transitions =
        Transition_cache.data transition_graph
        |> List.map ~f:(fun (x, _) ->
               Transition_cache.header_with_hash @@ Envelope.Incoming.data x )
      in
      let module E = struct
        module T = struct
          type t = Mina_block.Header.t State_hash.With_state_hashes.t
          [@@deriving sexp]

          let compare = external_transition_compare ~context:(module Context)
        end

        include Comparable.Make (T)
      end in
      let saved_set = E.Set.of_list saved_transitions in
      let expected_set = E.Set.of_list expected_transitions in
      Alcotest.(check bool)
        "cached transitions match expected" true
        (E.Set.equal saved_set expected_set) )

(* Test 2: Sync with one node after receiving a transition *)
let test_sync_with_one_node () =
  Quickcheck.test ~trials:1
    Fake_network.Generator.(
      gen ~precomputed_values ~verifier ~max_frontier_length ~ledger_sync_config
        [ fresh_peer
        ; peer_with_branch ~frontier_branch_size:((max_frontier_length * 2) + 2)
        ])
    ~f:(fun fake_network ->
      let [ my_net; peer_net ] = fake_network.peer_networks in
      let transition_reader, transition_writer =
        Pipe_lib.Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
          (Buffered (`Capacity 10, `Overflow (Drop_head ignore)))
      in
      let block =
        Envelope.Incoming.wrap
          ~data:
            ( Transition_frontier.best_tip peer_net.state.frontier
            |> Transition_frontier.Breadcrumb.validated_transition
            |> Mina_block.Validated.remember
            |> Mina_block.Validation.reset_frontier_dependencies_validation
            |> Mina_block.Validation.reset_staged_ledger_diff_validation )
          ~sender:(Envelope.Sender.Remote peer_net.peer)
      in
      Pipe_lib.Strict_pipe.Writer.write transition_writer
        (`Block block, `Valid_cb None) ;
      let new_frontier, sorted_external_transitions =
        Async.Thread_safe.block_on_async_exn (fun () ->
            run_bootstrap
              ~timeout_duration:(Block_time.Span.of_ms 30_000L)
              ~my_net ~transition_reader )
      in
      assert_transitions_increasingly_sorted
        ~root:(Transition_frontier.root new_frontier)
        sorted_external_transitions ;
      let actual_root_hash =
        Ledger.Db.merkle_root
        @@ Transition_frontier.root_snarked_ledger new_frontier
      in
      let expected_root_hash =
        Ledger.Db.merkle_root
        @@ Transition_frontier.root_snarked_ledger peer_net.state.frontier
      in
      Alcotest.(check bool)
        "root ledger hashes match" true
        (Ledger_hash.equal actual_root_hash expected_root_hash) )

(* Test 3: Reconstruct staged_ledgers *)
let test_reconstruct_staged_ledgers () =
  Quickcheck.test ~trials:1
    (Transition_frontier.For_tests.gen ~precomputed_values ~verifier
       ~max_length:max_frontier_length ~size:max_frontier_length () )
    ~f:(fun frontier ->
      Thread_safe.block_on_async_exn
      @@ fun () ->
      Deferred.List.iter (Transition_frontier.all_breadcrumbs frontier)
        ~f:(fun breadcrumb ->
          let staged_ledger =
            Transition_frontier.Breadcrumb.staged_ledger breadcrumb
          in
          let expected_merkle_root =
            Staged_ledger.ledger staged_ledger |> Ledger.merkle_root
          in
          let snarked_ledger =
            Transition_frontier.root_snarked_ledger frontier
            |> Ledger.of_database
          in
          let snarked_local_state =
            Transition_frontier.root frontier
            |> Transition_frontier.Breadcrumb.protocol_state
            |> Protocol_state.blockchain_state
            |> Blockchain_state.snarked_local_state
          in
          let scan_state = Staged_ledger.scan_state staged_ledger in
          let get_state hash =
            match Transition_frontier.find_protocol_state frontier hash with
            | Some protocol_state ->
                Ok protocol_state
            | None ->
                Or_error.errorf
                  !"Protocol state (for scan state transactions) for \
                    %{sexp:State_hash.t} not found"
                  hash
          in
          let pending_coinbases =
            Staged_ledger.pending_coinbase_collection staged_ledger
          in
          let%map actual_staged_ledger =
            Staged_ledger.of_scan_state_pending_coinbases_and_snarked_ledger
              ~scan_state ~logger ~verifier ~constraint_constants
              ~snarked_ledger ~snarked_local_state ~expected_merkle_root
              ~pending_coinbases ~get_state
            |> Deferred.Or_error.ok_exn
          in
          let height =
            Transition_frontier.Breadcrumb.consensus_state breadcrumb
            |> Consensus.Data.Consensus_state.blockchain_length
            |> Mina_numbers.Length.to_int
          in
          let expected_hash =
            Transition_frontier.Breadcrumb.staged_ledger_hash breadcrumb
          in
          let actual_hash = Staged_ledger.hash actual_staged_ledger in
          Alcotest.(check bool)
            (sprintf "staged ledger hash matches at height %d" height)
            true
            (Staged_ledger_hash.equal expected_hash actual_hash) ) )

let tests =
  [ ("bootstrap_caches_transitions", `Quick, test_bootstrap_caches_transitions)
  ; ("sync_with_one_node", `Quick, test_sync_with_one_node)
  ; ("reconstruct_staged_ledgers", `Quick, test_reconstruct_staged_ledgers)
  ]

let () =
  let open Alcotest in
  run "Bootstrap_controller" [ ("bootstrap_tests", tests) ]
