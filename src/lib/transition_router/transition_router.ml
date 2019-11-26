open Core_kernel
open Async_kernel
open Coda_state
open Pipe_lib
open Coda_transition
open O1trace

let create_bufferred_pipe ?name () =
  Strict_pipe.create ?name (Buffered (`Capacity 50, `Overflow Crash))

let is_transition_for_bootstrap ~logger root_state new_transition =
  let new_state =
    External_transition.Initial_validated.protocol_state new_transition
  in
  Consensus.Hooks.should_bootstrap
    ~existing:(Protocol_state.consensus_state root_state)
    ~candidate:(Protocol_state.consensus_state new_state)
    ~logger:
      (Logger.extend logger
         [ ( "selection_context"
           , `String "Transition_router.is_transition_for_bootstrap" ) ])

let get_root_state frontier =
  Transition_frontier.root frontier
  |> Transition_frontier.Breadcrumb.protocol_state

let start_transition_frontier_controller ~logger ~trust_system ~verifier
    ~network ~time_controller ~proposer_transition_reader
    ~verified_transition_writer ~clear_reader ~collected_transitions
    ~transition_reader_ref ~transition_writer_ref ~frontier_w
    ~initialization_finish_signal frontier =
  Logger.info logger ~module_:__MODULE__ ~location:__LOC__
    "Starting Transition Frontier Controller phase" ;
  initialization_finish_signal := true ;
  let ( transition_frontier_controller_reader
      , transition_frontier_controller_writer ) =
    create_bufferred_pipe ~name:"transition frontier controller pipe" ()
  in
  transition_reader_ref := transition_frontier_controller_reader ;
  transition_writer_ref := transition_frontier_controller_writer ;
  Broadcast_pipe.Writer.write frontier_w (Some frontier) |> don't_wait_for ;
  let new_verified_transition_reader =
    trace_recurring "transition frontier controller" (fun () ->
        Transition_frontier_controller.run ~logger ~trust_system ~verifier
          ~network ~time_controller ~collected_transitions ~frontier
          ~network_transition_reader:!transition_reader_ref
          ~proposer_transition_reader ~clear_reader )
  in
  Strict_pipe.Reader.iter new_verified_transition_reader
    ~f:
      (Fn.compose Deferred.return
         (Strict_pipe.Writer.write verified_transition_writer))
  |> don't_wait_for

let start_bootstrap_controller ~logger ~trust_system ~verifier ~network
    ~time_controller ~proposer_transition_reader ~verified_transition_writer
    ~clear_reader ~transition_reader_ref ~transition_writer_ref
    ~consensus_local_state ~frontier_w ~initialization_finish_signal
    ~initial_root_transition ~persistent_root ~persistent_frontier
    ~genesis_protocol_state_hash ~genesis_ledger =
  Logger.info logger ~module_:__MODULE__ ~location:__LOC__
    "Starting Bootstrap Controller phase" ;
  initialization_finish_signal := false ;
  let bootstrap_controller_reader, bootstrap_controller_writer =
    create_bufferred_pipe ~name:"bootstrap controller pipe" ()
  in
  transition_reader_ref := bootstrap_controller_reader ;
  transition_writer_ref := bootstrap_controller_writer ;
  don't_wait_for (Broadcast_pipe.Writer.write frontier_w None) ;
  trace_recurring "bootstrap controller" (fun () ->
      upon
        (let%bind () =
           let connectivity_time_uppperbound = 60.0 in
           let high_connectivity_deferred =
             Coda_networking.on_first_high_connectivity network ~f:Fn.id
           in
           Deferred.any
             [ high_connectivity_deferred
             ; ( after (Time_ns.Span.of_sec connectivity_time_uppperbound)
               >>| fun () ->
               if not @@ Deferred.is_determined high_connectivity_deferred then
                 Logger.info logger
                   !"Will start bootstrapping without connecting with too \
                     many peers"
                   ~metadata:
                     [ ( "num peers"
                       , `Int (List.length @@ Coda_networking.peers network) )
                     ; ( "Max seconds to wait for high connectivity"
                       , `Float connectivity_time_uppperbound ) ]
                   ~location:__LOC__ ~module_:__MODULE__
               else
                 Logger.info logger ~location:__LOC__ ~module_:__MODULE__
                   "Already connected to enough peers, start bootstrapping" )
             ]
         in
         initialization_finish_signal := true ;
         Bootstrap_controller.run ~logger ~trust_system ~verifier ~network
           ~consensus_local_state ~transition_reader:!transition_reader_ref
           ~persistent_frontier ~persistent_root ~initial_root_transition
           ~genesis_protocol_state_hash ~genesis_ledger)
        (fun (new_frontier, collected_transitions) ->
          Strict_pipe.Writer.kill !transition_writer_ref ;
          start_transition_frontier_controller ~logger ~trust_system ~verifier
            ~network ~time_controller ~proposer_transition_reader
            ~verified_transition_writer ~clear_reader ~collected_transitions
            ~transition_reader_ref ~transition_writer_ref ~frontier_w
            ~initialization_finish_signal new_frontier ) )

let run ~logger ~trust_system ~verifier ~network ~time_controller
    ~consensus_local_state ~persistent_root ~persistent_frontier
    ~frontier_broadcast_pipe:(frontier_r, frontier_w)
    ~network_transition_reader ~proposer_transition_reader
    ~most_recent_valid_block:( most_recent_valid_block_reader
                             , most_recent_valid_block_writer )
    ~genesis_protocol_state_hash ~genesis_ledger =
  let initialization_finish_signal = ref false in
  let clear_reader, clear_writer =
    Strict_pipe.create ~name:"clear" Synchronous
  in
  let verified_transition_reader, verified_transition_writer =
    create_bufferred_pipe ~name:"verified transitions" ()
  in
  let transition_reader, transition_writer =
    create_bufferred_pipe ~name:"transition pipe" ()
  in
  let transition_reader_ref = ref transition_reader in
  let transition_writer_ref = ref transition_writer in
  (* This might be unsafe. Image the following scenario:
     If a node joined at the very end of the first epoch, and
     it didn't receive any transition from network for a while.
     Then it went to the second epoch and it could propose at
     the second epoch. *)
  let now = Coda_base.Block_time.now time_controller in
  don't_wait_for
    (let%map () =
       match Broadcast_pipe.Reader.peek frontier_r with
       | Some frontier ->
           if
             try Consensus.Hooks.is_genesis now
             with Invalid_argument _ ->
               (* if "now" is before the genesis timestamp, the calculation
              of the proof-of-stake epoch results in an exception
           *)
               let module Time = Coda_base.Block_time in
               let time_till_genesis =
                 Time.diff Consensus.Constants.genesis_state_timestamp now
               in
               Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
                 ~metadata:
                   [ ( "time_till_genesis"
                     , `Int
                         (Int64.to_int_exn (Time.Span.to_ms time_till_genesis))
                     ) ]
                 "Node started before genesis: waiting $time_till_genesis \
                  milliseconds before running transition router" ;
               let seconds_to_wait = 30 in
               let milliseconds_to_wait =
                 Int64.of_int_exn (seconds_to_wait * 1000)
               in
               let rec wait_loop tm =
                 if Int64.(tm <= zero) then ()
                 else (
                   Core.Unix.sleep seconds_to_wait ;
                   let tm_remaining = Int64.(tm - milliseconds_to_wait) in
                   Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
                     "Still waiting $tm_remaining milliseconds before running \
                      transition router"
                     ~metadata:
                       [("tm_remaining", `Int (Int64.to_int_exn tm_remaining))] ;
                   wait_loop tm_remaining )
               in
               wait_loop @@ Time.Span.to_ms time_till_genesis ;
               (* after waiting, we're at least at the genesis time, maybe a bit past it *)
               Consensus.Hooks.is_genesis
               @@ Coda_base.Block_time.now time_controller
           then (
             start_transition_frontier_controller ~logger ~trust_system
               ~verifier ~network ~time_controller ~proposer_transition_reader
               ~verified_transition_writer ~clear_reader
               ~collected_transitions:[] ~transition_reader_ref
               ~transition_writer_ref ~frontier_w ~initialization_finish_signal
               frontier ;
             Deferred.unit )
           else
             let initial_root_transition =
               Transition_frontier.(
                 Breadcrumb.validated_transition (root frontier))
             in
             let%map () = Transition_frontier.close frontier in
             start_bootstrap_controller ~logger ~trust_system ~verifier
               ~network ~time_controller ~proposer_transition_reader
               ~verified_transition_writer ~clear_reader ~transition_reader_ref
               ~consensus_local_state ~transition_writer_ref ~frontier_w
               ~initialization_finish_signal ~persistent_root
               ~persistent_frontier ~initial_root_transition
               ~genesis_protocol_state_hash ~genesis_ledger
       | None ->
           let%map initial_root_transition =
             Persistent_frontier.(
               with_instance_exn persistent_frontier
                 ~f:Instance.get_root_transition)
             >>| Result.ok_or_failwith
           in
           start_bootstrap_controller ~logger ~trust_system ~verifier ~network
             ~time_controller ~proposer_transition_reader
             ~verified_transition_writer ~clear_reader ~transition_reader_ref
             ~consensus_local_state ~transition_writer_ref ~frontier_w
             ~initialization_finish_signal ~persistent_root
             ~persistent_frontier ~initial_root_transition
             ~genesis_protocol_state_hash ~genesis_ledger
     in
     let ( valid_protocol_state_transition_reader
         , valid_protocol_state_transition_writer ) =
       create_bufferred_pipe ~name:"valid transitions" ()
     in
     Initial_validator.run ~logger ~trust_system ~verifier
       ~transition_reader:network_transition_reader
       ~valid_transition_writer:valid_protocol_state_transition_writer
       ~initialization_finish_signal ~genesis_protocol_state_hash ;
     let valid_protocol_state_transition_reader, valid_transition_reader =
       Strict_pipe.Reader.Fork.two valid_protocol_state_transition_reader
     in
     don't_wait_for
       (Strict_pipe.Reader.iter valid_transition_reader
          ~f:(fun transition_with_time ->
            let `Transition enveloped_transition, _ = transition_with_time in
            let transition = Envelope.Incoming.data enveloped_transition in
            let current_consensus_state =
              External_transition.consensus_state
                (Broadcast_pipe.Reader.peek most_recent_valid_block_reader)
            in
            if
              Consensus.Hooks.select ~existing:current_consensus_state
                ~candidate:
                  External_transition.Initial_validated.(
                    consensus_state transition)
                ~logger
              = `Take
            then
              Broadcast_pipe.Writer.write most_recent_valid_block_writer
                (External_transition.Validation.forget_validation transition)
            else Deferred.unit )) ;
     don't_wait_for
       (Strict_pipe.Reader.iter_without_pushback
          valid_protocol_state_transition_reader
          ~f:(fun transition_with_time ->
            let `Transition enveloped_transition, _ = transition_with_time in
            let transition = Envelope.Incoming.data enveloped_transition in
            don't_wait_for
              (let%map () =
                 match Broadcast_pipe.Reader.peek frontier_r with
                 | Some frontier ->
                     if
                       is_transition_for_bootstrap ~logger
                         (get_root_state frontier) transition
                     then (
                       Strict_pipe.Writer.kill !transition_writer_ref ;
                       don't_wait_for
                         (Strict_pipe.Writer.write clear_writer `Clear) ;
                       let initial_root_transition =
                         Transition_frontier.(
                           Breadcrumb.validated_transition (root frontier))
                       in
                       let%map () = Transition_frontier.close frontier in
                       start_bootstrap_controller ~logger ~trust_system
                         ~verifier ~network ~time_controller
                         ~proposer_transition_reader
                         ~verified_transition_writer ~clear_reader
                         ~transition_reader_ref ~transition_writer_ref
                         ~consensus_local_state ~frontier_w
                         ~initialization_finish_signal ~persistent_root
                         ~persistent_frontier ~initial_root_transition
                         ~genesis_protocol_state_hash ~genesis_ledger )
                     else Deferred.unit
                 | None ->
                     Deferred.unit
               in
               Strict_pipe.Writer.write !transition_writer_ref
                 transition_with_time) ))) ;
  verified_transition_reader
