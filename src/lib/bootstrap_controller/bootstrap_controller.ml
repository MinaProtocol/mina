(* Only show stdout for failed inline tests. *)
open Core
open Async
open Mina_base
module Ledger = Mina_ledger.Ledger
module Sync_ledger = Mina_ledger.Sync_ledger
open Mina_state
open Pipe_lib.Strict_pipe
open Network_peer
module Transition_cache = Transition_cache

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t

  val ledger_sync_config : Syncable_ledger.daemon_config

  val proof_cache_db : Proof_cache_tag.cache_db
end

type Structured_log_events.t += Bootstrap_complete
  [@@deriving register_event { msg = "Bootstrap state: complete." }]

type t =
  { context : (module CONTEXT)
  ; trust_system : Trust_system.t
  ; verifier : Verifier.t
  ; mutable best_seen_transition : Mina_block.initial_valid_block
  ; mutable current_root : Mina_block.initial_valid_block
  ; network : Mina_networking.t
  ; mutable num_of_root_snarked_ledger_retargeted : int
  }

type time = Time.Span.t

let time_to_yojson span =
  `String (Printf.sprintf "%f seconds" (Time.Span.to_sec span))

type opt_time = time option

let opt_time_to_yojson = function
  | Some time ->
      time_to_yojson time
  | None ->
      `Null

(** An auxiliary data structure for collecting various metrics for bootstrap controller. *)
type bootstrap_cycle_stats =
  { cycle_result : string
  ; sync_ledger_time : time
  ; staged_ledger_data_download_time : time
  ; staged_ledger_construction_time : opt_time
  ; local_state_sync_required : bool
  ; local_state_sync_time : opt_time
  }
[@@deriving to_yojson]

let time_deferred deferred =
  let start_time = Time.now () in
  let%map result = deferred in
  let end_time = Time.now () in
  (Time.diff end_time start_time, result)

let worth_getting_root ({ context = (module Context); _ } as t) candidate =
  let module Consensus_context = struct
    include Context

    let logger =
      Logger.extend logger
        [ ( "selection_context"
          , `String "Bootstrap_controller.worth_getting_root" )
        ]
  end in
  Consensus.Hooks.equal_select_status `Take
  @@ Consensus.Hooks.select
       ~context:(module Consensus_context)
       ~existing:
         ( t.best_seen_transition |> Mina_block.Validation.block_with_hash
         |> With_hash.map ~f:Mina_block.consensus_state )
       ~candidate

let received_bad_proof ({ context = (module Context); _ } as t) host e =
  let open Context in
  Trust_system.(
    record t.trust_system logger host
      Actions.
        ( Violated_protocol
        , Some
            ( "Bad ancestor proof: $error"
            , [ ("error", Error_json.error_to_yojson e) ] ) ))

let done_syncing_root root_sync_ledger =
  Option.is_some (Sync_ledger.Db.peek_valid_tree root_sync_ledger)

let should_sync ~root_sync_ledger t candidate_state =
  (not @@ done_syncing_root root_sync_ledger)
  && worth_getting_root t candidate_state

(** Update [Synced_ledger]'s target and [best_seen_transition] and [current_root] accordingly. *)
let start_sync_job_with_peer ~sender ~root_sync_ledger
    ({ context = (module Context); _ } as t) peer_best_tip peer_root =
  let open Context in
  let%bind () =
    Trust_system.(
      record t.trust_system logger sender
        Actions.
          ( Fulfilled_request
          , Some ("Received verified peer root and best tip", []) ))
  in
  t.best_seen_transition <- peer_best_tip ;
  t.current_root <- peer_root ;
  let blockchain_state =
    t.current_root |> Mina_block.Validation.block |> Mina_block.header
    |> Mina_block.Header.protocol_state |> Protocol_state.blockchain_state
  in
  let expected_staged_ledger_hash =
    blockchain_state |> Blockchain_state.staged_ledger_hash
  in
  let snarked_ledger_hash =
    blockchain_state |> Blockchain_state.snarked_ledger_hash
  in
  return
  @@
  match
    Sync_ledger.Db.new_goal root_sync_ledger
      (Frozen_ledger_hash.to_ledger_hash snarked_ledger_hash)
      ~data:
        ( State_hash.With_state_hashes.state_hash
          @@ Mina_block.Validation.block_with_hash t.current_root
        , sender
        , expected_staged_ledger_hash )
      ~equal:(fun (hash1, _, _) (hash2, _, _) -> State_hash.equal hash1 hash2)
  with
  | `New ->
      t.num_of_root_snarked_ledger_retargeted <-
        t.num_of_root_snarked_ledger_retargeted + 1 ;
      `Syncing_new_snarked_ledger
  | `Update_data ->
      `Updating_root_transition
  | `Repeat ->
      `Ignored

let to_consensus_state h =
  Mina_block.Header.protocol_state h |> Protocol_state.consensus_state

(** For each transition, this function would compare it with the existing one.
    If the incoming transition is better, then download the merkle list from
    that transition to its root and verify it. If we get a better root than
    the existing one, then reset the Sync_ledger's target by calling
    [start_sync_job_with_peer] function. *)
let on_transition ({ context = (module Context); _ } as t) ~sender
    ~root_sync_ledger candidate_header =
  let open Context in
  let candidate_consensus_state =
    With_hash.map ~f:to_consensus_state candidate_header
  in
  if not @@ should_sync ~root_sync_ledger t candidate_consensus_state then
    Deferred.return `Ignored
  else
    match%bind
      Mina_networking.get_ancestry t.network sender.Peer.peer_id
        (With_hash.map_hash candidate_consensus_state
           ~f:State_hash.State_hashes.state_hash )
    with
    | Error e ->
        [%log error]
          ~metadata:[ ("error", Error_json.error_to_yojson e) ]
          !"Could not get the proof of the root transition from the network: \
            $error" ;
        Deferred.return `Ignored
    | Ok peer_root_with_proof -> (
        let pcd =
          peer_root_with_proof.data
          |> Proof_carrying_data.map
               ~f:(Mina_block.write_all_proofs_to_disk ~proof_cache_db)
          |> Proof_carrying_data.map_proof
               ~f:
                 (Tuple2.map_snd
                    ~f:(Mina_block.write_all_proofs_to_disk ~proof_cache_db) )
        in
        match%bind
          Mina_block.verify_on_header
            ~verify:
              (Sync_handler.Root.verify
                 ~context:(module Context)
                 ~verifier:t.verifier candidate_consensus_state )
            pcd
        with
        | Ok (`Root root, `Best_tip best_tip) ->
            if done_syncing_root root_sync_ledger then return `Ignored
            else
              start_sync_job_with_peer ~sender ~root_sync_ledger t best_tip root
        | Error e ->
            return (received_bad_proof t sender e |> Fn.const `Ignored) )

(** A helper function that wraps the calls to Sync_ledger and iterate through
    incoming transitions, add those to the transition_cache and calls
    [on_transition] function. *)
let sync_ledger ({ context = (module Context); _ } as t) ~preferred
    ~root_sync_ledger ~transition_graph ~sync_ledger_reader =
  let open Context in
  let query_reader = Sync_ledger.Db.query_reader root_sync_ledger in
  let response_writer = Sync_ledger.Db.answer_writer root_sync_ledger in
  Mina_networking.glue_sync_ledger ~preferred t.network query_reader
    response_writer ;
  Pipe_lib.Choosable_synchronous_pipe.iter sync_ledger_reader
    ~f:(fun (b_or_h, `Valid_cb vc) ->
      let header_with_hash, sender, transition_cache_element =
        match b_or_h with
        | `Block b_env ->
            ( Envelope.Incoming.data b_env
              |> Mina_block.Validation.block_with_hash
              |> With_hash.map ~f:Mina_block.header
            , Envelope.Incoming.remote_sender_exn b_env
            , Envelope.Incoming.map ~f:(fun x -> `Block x) b_env )
        | `Header h_env ->
            ( Envelope.Incoming.data h_env
              |> Mina_block.Validation.header_with_hash
            , Envelope.Incoming.remote_sender_exn h_env
            , Envelope.Incoming.map ~f:(fun x -> `Header x) h_env )
      in
      let previous_state_hash =
        With_hash.data header_with_hash
        |> Mina_block.Header.protocol_state
        |> Protocol_state.previous_state_hash
      in
      Transition_cache.add transition_graph ~parent:previous_state_hash
        (transition_cache_element, vc) ;
      (* TODO: Efficiently limiting the number of green threads in #1337 *)
      if
        worth_getting_root t
          (With_hash.map ~f:to_consensus_state header_with_hash)
      then (
        [%log trace] "Added the transition from sync_ledger_reader into cache"
          ~metadata:
            [ ( "state_hash"
              , State_hash.to_yojson
                  (State_hash.With_state_hashes.state_hash header_with_hash) )
            ; ( "header"
              , Mina_block.Header.to_yojson (With_hash.data header_with_hash) )
            ] ;

        Deferred.ignore_m
        @@ on_transition t ~sender ~root_sync_ledger header_with_hash )
      else Deferred.unit )

let external_transition_compare ~context:(module Context : CONTEXT) =
  let get_consensus_state =
    Fn.compose Protocol_state.consensus_state Mina_block.Header.protocol_state
  in
  Comparable.lift
    (fun existing candidate ->
      (* To prevent the logger to spam a lot of messages, the logger input is set to null *)
      if
        State_hash.equal
          (State_hash.With_state_hashes.state_hash existing)
          (State_hash.With_state_hashes.state_hash candidate)
      then 0
      else if
        Consensus.Hooks.equal_select_status `Keep
        @@ Consensus.Hooks.select ~context:(module Context) ~existing ~candidate
      then -1
      else 1 )
    ~f:(With_hash.map ~f:get_consensus_state)

let download_snarked_ledger ~trust_system ~preferred_peers ~transition_graph
    ~sync_ledger_reader ~context t temp_snarked_ledger =
  time_deferred
    (let root_sync_ledger =
       Sync_ledger.Db.create temp_snarked_ledger ~context ~trust_system
     in
     don't_wait_for
       (sync_ledger t ~preferred:preferred_peers ~root_sync_ledger
          ~transition_graph ~sync_ledger_reader ) ;
     (* We ignore the resulting ledger returned here since it will always
        * be the same as the ledger we started with because we are syncing
        * a db ledger. *)
     let%map _, data = Sync_ledger.Db.valid_tree root_sync_ledger in
     Sync_ledger.Db.destroy root_sync_ledger ;
     data )

(** Run one bootstrap cycle *)
let run_cycle ~context:(module Context : CONTEXT) ~trust_system ~verifier
    ~network ~consensus_local_state ~network_transition_pipe ~preferred_peers
    ~persistent_root ~persistent_frontier ~initial_root_transition ~catchup_mode
    previous_cycles =
  let open Context in
  (* The short-lived pipe allocated here will be closed
     when a follow-up pipe is allocated: in the next cycle of bootstrap
     or when controll is passed to the transition frontier controller.staged_ledger_construction_time
     Because [Choosable_synchronous_pipe.t] is used, no data will be lost: any
     successful read is followed by mom-blocking handling, and if the read/write
     pair is not consumed, it will continue in a follow-up pipe allocated in the
     next call to [Swappable.swap_reader].
  *)
  let%bind sync_ledger_reader = Swappable.swap_reader network_transition_pipe in
  let initial_root_transition =
    initial_root_transition |> Mina_block.Validated.remember
    |> Mina_block.Validation.reset_frontier_dependencies_validation
    |> Mina_block.Validation.reset_staged_ledger_diff_validation
  in
  let t =
    { network
    ; context = (module Context)
    ; trust_system
    ; verifier
    ; best_seen_transition = initial_root_transition
    ; current_root = initial_root_transition
    ; num_of_root_snarked_ledger_retargeted = 0
    }
  in
  let transition_graph = Transition_cache.create () in
  let temp_persistent_root_instance =
    Transition_frontier.Persistent_root.create_instance_exn persistent_root
  in
  let temp_snarked_ledger =
    Transition_frontier.Persistent_root.Instance.snarked_ledger
      temp_persistent_root_instance
  in
  (* step 1. download snarked_ledger *)
  let%bind sync_ledger_time, (hash, sender, expected_staged_ledger_hash) =
    download_snarked_ledger
      ~context:(module Context)
      ~trust_system ~preferred_peers ~transition_graph ~sync_ledger_reader t
      temp_snarked_ledger
  in
  Mina_metrics.(
    Counter.inc Bootstrap.root_snarked_ledger_sync_ms
      Time.Span.(to_ms sync_ledger_time)) ;
  Mina_metrics.(
    Gauge.set Bootstrap.num_of_root_snarked_ledger_retargeted
      (Float.of_int t.num_of_root_snarked_ledger_retargeted)) ;
  (* step 2. Download scan state and pending coinbases. *)
  let%bind ( staged_ledger_data_download_time
           , staged_ledger_construction_time
           , staged_ledger_aux_result ) =
    let%bind ( staged_ledger_data_download_time
             , staged_ledger_data_download_result ) =
      time_deferred
        (Mina_networking.get_staged_ledger_aux_and_pending_coinbases_at_hash
           t.network sender.peer_id hash )
    in
    match staged_ledger_data_download_result with
    | Error err ->
        Deferred.return (staged_ledger_data_download_time, None, Error err)
    | Ok
        ( scan_state_uncached
        , expected_merkle_root
        , pending_coinbases
        , protocol_states ) -> (
        let%map staged_ledger_construction_result =
          O1trace.thread "construct_root_staged_ledger" (fun () ->
              let open Deferred.Or_error.Let_syntax in
              let received_staged_ledger_hash =
                Staged_ledger_hash.of_aux_ledger_and_coinbase_hash
                  (Staged_ledger.Scan_state.Stable.Latest.hash
                     scan_state_uncached )
                  expected_merkle_root pending_coinbases
              in
              [%log debug]
                ~metadata:
                  [ ( "expected_staged_ledger_hash"
                    , Staged_ledger_hash.to_yojson expected_staged_ledger_hash
                    )
                  ; ( "received_staged_ledger_hash"
                    , Staged_ledger_hash.to_yojson received_staged_ledger_hash
                    )
                  ]
                "Comparing $expected_staged_ledger_hash to \
                 $received_staged_ledger_hash" ;
              let%bind new_root =
                t.current_root
                |> Mina_block.Validation.skip_frontier_dependencies_validation
                     `This_block_belongs_to_a_detached_subtree
                |> Mina_block.Validation.validate_staged_ledger_hash
                     (`Staged_ledger_already_materialized
                       received_staged_ledger_hash )
                |> Result.map_error ~f:(fun _ ->
                       Error.of_string "received faulty scan state from peer" )
                |> Deferred.return
              in
              let protocol_states =
                List.map protocol_states
                  ~f:(With_hash.of_data ~hash_data:Protocol_state.hashes)
              in
              let scan_state =
                Staged_ledger.Scan_state.write_all_proofs_to_disk
                  ~proof_cache_db scan_state_uncached
              in
              let%bind protocol_states =
                Staged_ledger.Scan_state.check_required_protocol_states
                  scan_state ~protocol_states
                |> Deferred.return
              in
              let protocol_states_map =
                protocol_states
                |> List.map ~f:(fun ps ->
                       (State_hash.With_state_hashes.state_hash ps, ps) )
                |> State_hash.Map.of_alist_exn
              in
              let get_state hash =
                match Map.find protocol_states_map hash with
                | None ->
                    let new_state_hash =
                      State_hash.With_state_hashes.state_hash (fst new_root)
                    in
                    [%log error]
                      ~metadata:
                        [ ("new_root", State_hash.to_yojson new_state_hash)
                        ; ("state_hash", State_hash.to_yojson hash)
                        ]
                      "Protocol state (for scan state transactions) for \
                       $state_hash not found when bootstrapping to the new \
                       root $new_root" ;
                    Or_error.errorf
                      !"Protocol state (for scan state transactions) for \
                        %{sexp:State_hash.t} not found when bootstrapping to \
                        the new root %{sexp:State_hash.t}"
                      hash new_state_hash
                | Some protocol_state ->
                    Ok (With_hash.data protocol_state)
              in
              (* step 3. Construct staged ledger from snarked ledger, scan state
                 and pending coinbases. *)
              (* Construct the staged ledger before constructing the transition
               * frontier in order to verify the scan state we received.
               * TODO: reorganize the code to avoid doing this twice (#3480) *)
              let open Deferred.Let_syntax in
              let%map staged_ledger_construction_time, construction_result =
                time_deferred
                  (let open Deferred.Let_syntax in
                  let temp_mask = Ledger.of_database temp_snarked_ledger in
                  let%map result =
                    Staged_ledger
                    .of_scan_state_pending_coinbases_and_snarked_ledger ~logger
                      ~snarked_local_state:
                        Mina_block.(
                          t.current_root |> Validation.block |> header
                          |> Header.protocol_state
                          |> Protocol_state.blockchain_state
                          |> Blockchain_state.snarked_local_state)
                      ~verifier ~constraint_constants ~scan_state
                      ~snarked_ledger:temp_mask ~expected_merkle_root
                      ~pending_coinbases ~get_state
                  in
                  ignore
                    ( Ledger.Maskable.unregister_mask_exn ~loc:__LOC__ temp_mask
                      : Ledger.unattached_mask ) ;
                  Result.map result
                    ~f:
                      (const
                         ( scan_state
                         , pending_coinbases
                         , new_root
                         , protocol_states ) ))
              in
              Ok (staged_ledger_construction_time, construction_result) )
        in
        match staged_ledger_construction_result with
        | Error err ->
            (staged_ledger_data_download_time, None, Error err)
        | Ok (staged_ledger_construction_time, result) ->
            ( staged_ledger_data_download_time
            , Some staged_ledger_construction_time
            , result ) )
  in
  Transition_frontier.Persistent_root.Instance.close
    temp_persistent_root_instance ;
  match staged_ledger_aux_result with
  | Error e ->
      let%map () =
        Trust_system.(
          record t.trust_system logger sender
            Actions.
              ( Outgoing_connection_error
              , Some
                  ( "Can't find scan state from the peer or received faulty \
                     scan state from the peer."
                  , [] ) ))
      in
      [%log error]
        ~metadata:
          [ ("error", Error_json.error_to_yojson e)
          ; ("state_hash", State_hash.to_yojson hash)
          ; ( "expected_staged_ledger_hash"
            , Staged_ledger_hash.to_yojson expected_staged_ledger_hash )
          ]
        "Failed to find scan state for the transition with hash $state_hash \
         from the peer or received faulty scan state: $error. Retry bootstrap" ;
      let this_cycle =
        { cycle_result = "failed to download and construct scan state"
        ; sync_ledger_time
        ; staged_ledger_data_download_time
        ; staged_ledger_construction_time
        ; local_state_sync_required = false
        ; local_state_sync_time = None
        }
      in
      `Repeat (this_cycle :: previous_cycles)
  | Ok (scan_state, pending_coinbase, new_root, protocol_states) -> (
      let%bind () =
        Trust_system.(
          record t.trust_system logger sender
            Actions.
              ( Fulfilled_request
              , Some ("Received valid scan state from peer", []) ))
      in
      let best_seen_block_with_hash, _ = t.best_seen_transition in
      let consensus_state =
        With_hash.data best_seen_block_with_hash
        |> Mina_block.header |> Mina_block.Header.protocol_state
        |> Protocol_state.consensus_state
      in
      (* step 4. Synchronize consensus local state if necessary *)
      let%bind ( local_state_sync_time
               , (local_state_sync_required, local_state_sync_result) ) =
        time_deferred
          ( match
              Consensus.Hooks.required_local_state_sync
                ~constants:precomputed_values.consensus_constants
                ~consensus_state ~local_state:consensus_local_state
            with
          | None ->
              [%log debug]
                ~metadata:
                  [ ( "local_state"
                    , Consensus.Data.Local_state.to_yojson consensus_local_state
                    )
                  ; ( "consensus_state"
                    , Consensus.Data.Consensus_state.Value.to_yojson
                        consensus_state )
                  ]
                "Not synchronizing consensus local state" ;
              Deferred.return (false, Or_error.return ())
          | Some sync_jobs ->
              [%log info] "Synchronizing consensus local state" ;
              let%map result =
                Consensus.Hooks.sync_local_state
                  ~context:(module Context)
                  ~local_state:consensus_local_state ~trust_system
                  ~glue_sync_ledger:(Mina_networking.glue_sync_ledger t.network)
                  sync_jobs
              in
              (true, result) )
      in
      match local_state_sync_result with
      | Error e ->
          [%log error]
            ~metadata:[ ("error", Error_json.error_to_yojson e) ]
            "Local state sync failed: $error. Retry bootstrap" ;
          let this_cycle =
            { cycle_result = "failed to synchronize local state"
            ; sync_ledger_time
            ; staged_ledger_data_download_time
            ; staged_ledger_construction_time
            ; local_state_sync_required
            ; local_state_sync_time = Some local_state_sync_time
            }
          in
          Deferred.return (`Repeat (this_cycle :: previous_cycles))
      | Ok () ->
          (* step 5. Close the old frontier and reload a new one from disk. *)
          let new_root_data : Transition_frontier.Root_data.Limited.t =
            Transition_frontier.Root_data.Limited.create
              ~transition:(Mina_block.Validated.lift new_root)
              ~scan_state ~pending_coinbase ~protocol_states
          in
          let%bind () =
            Transition_frontier.Persistent_frontier.reset_database_exn
              persistent_frontier ~root_data:new_root_data
              ~genesis_state_hash:
                (State_hash.With_state_hashes.state_hash
                   precomputed_values.protocol_state_with_hashes )
          in
          (* TODO: lazy load db in persistent root to avoid unnecessary opens like this *)
          Transition_frontier.Persistent_root.(
            with_instance_exn persistent_root ~f:(fun instance ->
                Instance.set_root_state_hash instance
                @@ Mina_block.Validated.state_hash
                @@ Mina_block.Validated.lift new_root )) ;
          let%map new_frontier =
            let fail msg =
              failwith
                ( "failed to initialize transition frontier after \
                   bootstrapping: " ^ msg )
            in
            Transition_frontier.load
              ~context:(module Context)
              ~retry_with_fresh_db:false ~verifier ~consensus_local_state
              ~persistent_root ~persistent_frontier ~catchup_mode ()
            >>| function
            | Ok frontier ->
                frontier
            | Error (`Failure msg) ->
                fail msg
            | Error `Bootstrap_required ->
                fail
                  "bootstrap still required (indicates logical error in code)"
            | Error `Persistent_frontier_malformed ->
                fail "persistent frontier was malformed"
            | Error `Snarked_ledger_mismatch ->
                fail
                  "this should not happen, because we just reset the \
                   snarked_ledger"
          in
          [%str_log info] Bootstrap_complete ;
          let collected_transitions = Transition_cache.data transition_graph in
          let logger =
            Logger.extend logger
              [ ("context", `String "Filter collected transitions in bootstrap")
              ]
          in
          let root_consensus_state =
            Transition_frontier.(
              Breadcrumb.consensus_state_with_hashes (root new_frontier))
          in
          let filtered_collected_transitions =
            List.filter collected_transitions
              ~f:(fun (incoming_transition, _) ->
                let transition =
                  Envelope.Incoming.data incoming_transition
                  |> Transition_cache.header_with_hash
                in
                Consensus.Hooks.equal_select_status `Take
                @@ Consensus.Hooks.select
                     ~context:(module Context)
                     ~existing:root_consensus_state
                     ~candidate:
                       (With_hash.map
                          ~f:
                            (Fn.compose Protocol_state.consensus_state
                               Mina_block.Header.protocol_state )
                          transition ) )
          in
          [%log debug] "Sorting filtered transitions by consensus state"
            ~metadata:[] ;
          let sorted_filtered_collected_transitions =
            O1trace.sync_thread "sorting_collected_transitions" (fun () ->
                List.sort filtered_collected_transitions
                  ~compare:
                    (Comparable.lift
                       ~f:(fun (x, _) ->
                         Transition_cache.header_with_hash
                         @@ Envelope.Incoming.data x )
                       (external_transition_compare ~context:(module Context)) ) )
          in
          let this_cycle =
            { cycle_result = "success"
            ; sync_ledger_time
            ; staged_ledger_data_download_time
            ; staged_ledger_construction_time
            ; local_state_sync_required
            ; local_state_sync_time = Some local_state_sync_time
            }
          in
          `Finished
            ( this_cycle :: previous_cycles
            , (new_frontier, sorted_filtered_collected_transitions) ) )

(** The entry point function for bootstrap controller. When bootstrap finished
    it would return a transition frontier with the root breadcrumb and a list
    of transitions collected during bootstrap.

    Bootstrap controller would do the following steps to contrust the
    transition frontier:
    1. Download the root snarked_ledger.
    2. Download the scan state and pending coinbases.
    3. Construct the staged ledger from the snarked ledger, scan state and
       pending coinbases.
    4. Synchronize the consensus local state if necessary.
    5. Close the old frontier and reload a new one from disk.
 *)
let run ~context:(module Context : CONTEXT) ~trust_system ~verifier ~network
    ~consensus_local_state ~network_transition_pipe ~preferred_peers
    ~persistent_root ~persistent_frontier ~initial_root_transition ~catchup_mode
    =
  let open Context in
  let run_cycle =
    run_cycle
      ~context:(module Context : CONTEXT)
      ~trust_system ~verifier ~network ~consensus_local_state
      ~network_transition_pipe ~preferred_peers ~persistent_root
      ~persistent_frontier ~initial_root_transition ~catchup_mode
  in
  O1trace.thread "bootstrap"
  @@ fun () ->
  let%map time_elapsed, (cycles, result) =
    time_deferred @@ Deferred.repeat_until_finished [] run_cycle
  in
  [%log info] "Bootstrap completed in $time_elapsed: $bootstrap_stats"
    ~metadata:
      [ ("time_elapsed", time_to_yojson time_elapsed)
      ; ( "bootstrap_stats"
        , `List (List.map ~f:bootstrap_cycle_stats_to_yojson cycles) )
      ] ;
  Mina_metrics.(
    Gauge.set Bootstrap.bootstrap_time_ms Core.Time.(Span.to_ms @@ time_elapsed)) ;
  result

let%test_module "Bootstrap_controller tests" =
  ( module struct
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
        ~compile_config:Mina_compile_config.For_unit_tests.t
        ~max_subtree_depth:None ~default_subtree_depth:None ()

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
          Verifier.For_tests.default ~constraint_constants ~logger ~proof_level
            () )

    module Genesis_ledger = (val precomputed_values.genesis_ledger)

    let downcast_transition ~sender transition =
      let transition =
        transition |> Mina_block.Validated.remember
        |> Mina_block.Validation.reset_frontier_dependencies_validation
        |> Mina_block.Validation.reset_staged_ledger_diff_validation
      in
      Envelope.Incoming.wrap ~data:transition
        ~sender:(Envelope.Sender.Remote sender)

    let downcast_breadcrumb ~sender breadcrumb =
      downcast_transition ~sender
        (Transition_frontier.Breadcrumb.validated_transition breadcrumb)

    let make_non_running_bootstrap ~genesis_root ~network =
      let transition =
        genesis_root
        |> Mina_block.Validation.reset_frontier_dependencies_validation
        |> Mina_block.Validation.reset_staged_ledger_diff_validation
      in
      { context = (module Context)
      ; trust_system
      ; verifier
      ; best_seen_transition = transition
      ; current_root = transition
      ; network
      ; num_of_root_snarked_ledger_retargeted = 0
      }

    let%test_unit "Bootstrap controller caches all transitions it is passed \
                   through the transition_reader" =
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
            Pipe_lib.Choosable_synchronous_pipe.create ()
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
              let%bind sync_ledger_writer' =
                Deferred.List.fold ~init:sync_ledger_writer branch
                  ~f:(fun sync_ledger_writer breadcrumb ->
                    Pipe_lib.Choosable_synchronous_pipe.write sync_ledger_writer
                      ( `Block
                          (downcast_breadcrumb ~sender:other.peer breadcrumb)
                      , `Valid_cb None ) )
              in
              Pipe_lib.Choosable_synchronous_pipe.close sync_ledger_writer' ;
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
          [%test_result: E.Set.t]
            (E.Set.of_list saved_transitions)
            ~expect:(E.Set.of_list expected_transitions) )

    let run_bootstrap ~timeout_duration ~my_net ~network_transition_pipe =
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
      let%bind () =
        Transition_frontier.close ~loc:__LOC__ my_net.state.frontier
      in
      [%log info] "bootstrap begin" ;
      Block_time.Timeout.await_exn time_controller ~timeout_duration
        (run
           ~context:(module Context)
           ~trust_system ~verifier ~network:my_net.network ~preferred_peers:[]
           ~consensus_local_state:my_net.state.consensus_local_state
           ~network_transition_pipe ~persistent_root ~persistent_frontier
           ~catchup_mode:`Super ~initial_root_transition )

    let assert_transitions_increasingly_sorted ~root
        (incoming_transitions : Transition_cache.element list) =
      let root =
        Transition_frontier.Breadcrumb.block root |> Mina_block.header
      in
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
                    (Error.of_string
                       "The blocks are not sorted in increasing order" )
              in
              header )
          |> Or_error.ok_exn
          : Mina_block.Header.t )

    let%test_unit "sync with one node after receiving a transition" =
      Quickcheck.test ~trials:1
        Fake_network.Generator.(
          gen ~precomputed_values ~verifier ~max_frontier_length
            ~ledger_sync_config
            [ fresh_peer
            ; peer_with_branch
                ~frontier_branch_size:((max_frontier_length * 2) + 2)
            ])
        ~f:(fun fake_network ->
          let [ my_net; peer_net ] = fake_network.peer_networks in
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
          let network_transition_pipe =
            Swappable.create ~name:(__MODULE__ ^ __LOC__)
              (Buffered (`Capacity 10, `Overflow (Drop_head ignore)))
          in
          Swappable.write network_transition_pipe (`Block block, `Valid_cb None) ;
          let new_frontier, sorted_external_transitions =
            Async.Thread_safe.block_on_async_exn (fun () ->
                run_bootstrap
                  ~timeout_duration:(Block_time.Span.of_ms 30_000L)
                  ~my_net ~network_transition_pipe )
          in
          assert_transitions_increasingly_sorted
            ~root:(Transition_frontier.root new_frontier)
            sorted_external_transitions ;
          [%test_result: Ledger_hash.t]
            ( Ledger.Db.merkle_root
            @@ Transition_frontier.root_snarked_ledger new_frontier )
            ~expect:
              ( Ledger.Db.merkle_root
              @@ Transition_frontier.root_snarked_ledger peer_net.state.frontier
              ) )

    let%test_unit "reconstruct staged_ledgers using \
                   of_scan_state_and_snarked_ledger" =
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
              [%test_eq: Staged_ledger_hash.t]
                ~message:
                  (sprintf "mismatch of staged ledger hash height %d" height)
                (Transition_frontier.Breadcrumb.staged_ledger_hash breadcrumb)
                (Staged_ledger.hash actual_staged_ledger) ) )

    (*
    let%test_unit "if we see a new transition that is better than the \
                   transition that we are syncing from, than we should \
                   retarget our root" =
      Quickcheck.test ~trials:1
        Fake_network.Generator.(
          gen ~max_frontier_length
            [ fresh_peer
            ; peer_with_branch ~frontier_branch_size:max_frontier_length
            ; peer_with_branch
                ~frontier_branch_size:((max_frontier_length * 2) + 2) ])
        ~f:(fun fake_network ->
          let [me; weaker_chain; stronger_chain] =
            fake_network.peer_networks
          in
          let transition_reader, transition_writer =
            Pipe_lib.Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
              (Buffered (`Capacity 10, `Overflow Drop_head))
          in
          Envelope.Incoming.wrap
            ~data:
              ( Transition_frontier.best_tip weaker_chain.state.frontier
              |> Transition_frontier.Breadcrumb.validated_transition
              |> Mina_block.Validated.to_initial_validated )
            ~sender:
              (Envelope.Sender.Remote
                 (weaker_chain.peer.host, weaker_chain.peer.peer_id))
          |> Pipe_lib.Strict_pipe.Writer.write transition_writer ;
          Envelope.Incoming.wrap
            ~data:
              ( Transition_frontier.best_tip stronger_chain.state.frontier
              |> Transition_frontier.Breadcrumb.validated_transition
              |> Mina_block.Validated.to_initial_validated )
            ~sender:
              (Envelope.Sender.Remote
                 (stronger_chain.peer.host, stronger_chain.peer.peer_id))
          |> Pipe_lib.Strict_pipe.Writer.write transition_writer ;
          let new_frontier, sorted_external_transitions =
            Async.Thread_safe.block_on_async_exn (fun () ->
                run_bootstrap
                  ~timeout_duration:(Block_time.Span.of_ms 60_000L)
                  ~my_net:me ~transition_reader )
          in
          assert_transitions_increasingly_sorted
            ~root:(Transition_frontier.root new_frontier)
            sorted_external_transitions ;
          [%test_result: Ledger_hash.t]
            ( Ledger.Db.merkle_root
            @@ Transition_frontier.root_snarked_ledger new_frontier )
            ~expect:
              ( Ledger.Db.merkle_root
              @@ Transition_frontier.root_snarked_ledger
                   stronger_chain.state.frontier ) )
*)
  end )
