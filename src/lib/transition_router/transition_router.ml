open Core_kernel
open Async_kernel
open Pipe_lib
open Coda_transition

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

  module Network : Coda_intf.Network_intf

  module Transition_frontier : Coda_intf.Transition_frontier_intf

  module Best_tip_prover :
    Coda_intf.Best_tip_prover_intf
    with type transition_frontier := Transition_frontier.t

  module Transition_frontier_controller :
    Coda_intf.Transition_frontier_controller_intf
    with type transition_frontier := Transition_frontier.t
     and type breadcrumb := Transition_frontier.Breadcrumb.t
     and type network := Network.t

  module Bootstrap_controller :
    Coda_intf.Bootstrap_controller_intf
    with type network := Network.t
     and type transition_frontier := Transition_frontier.t
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  module Initial_validator = Initial_validator.Make (Inputs)

  let create_bufferred_pipe ?name () =
    Strict_pipe.create ?name (Buffered (`Capacity 70, `Overflow Crash))

  let is_transition_for_bootstrap ~logger ~frontier new_transition =
    let root = Transition_frontier.root frontier in
    Consensus.Hooks.should_bootstrap
      ~existing:(Transition_frontier.Breadcrumb.consensus_state root)
      ~candidate:(External_transition.consensus_state new_transition)
      ~logger:
        (Logger.extend logger
           [ ( "selection_context"
             , `String "Transition_router.is_transition_for_bootstrap" ) ])

  let start_transition_frontier_controller ~logger ~trust_system ~verifier
      ~network ~time_controller ~proposer_transition_reader
      ~verified_transition_writer ~clear_reader ~collected_transitions
      ~transition_reader_ref ~transition_writer_ref ~frontier_w frontier =
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__
      "Starting Transition Frontier Controller phase" ;
    let ( transition_frontier_controller_reader
        , transition_frontier_controller_writer ) =
      create_bufferred_pipe ~name:"transition frontier controller pipe" ()
    in
    transition_reader_ref := transition_frontier_controller_reader ;
    transition_writer_ref := transition_frontier_controller_writer ;
    Broadcast_pipe.Writer.write frontier_w (Some frontier) |> don't_wait_for ;
    let new_verified_transition_reader =
      Transition_frontier_controller.run ~logger ~trust_system ~verifier
        ~network ~time_controller ~collected_transitions ~frontier
        ~network_transition_reader:!transition_reader_ref
        ~proposer_transition_reader ~clear_reader
    in
    Strict_pipe.Reader.iter new_verified_transition_reader
      ~f:
        (Fn.compose Deferred.return
           (Strict_pipe.Writer.write verified_transition_writer))
    |> don't_wait_for

  let start_bootstrap_controller ~logger ~trust_system ~verifier ~network
      ~time_controller ~proposer_transition_reader ~verified_transition_writer
      ~clear_reader ~transition_reader_ref ~transition_writer_ref ~ledger_db
      ~frontier_w frontier =
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__
      "Starting Bootstrap Controller phase" ;
    let bootstrap_controller_reader, bootstrap_controller_writer =
      create_bufferred_pipe ~name:"bootstrap controller pipe" ()
    in
    transition_reader_ref := bootstrap_controller_reader ;
    transition_writer_ref := bootstrap_controller_writer ;
    Transition_frontier.close frontier ;
    Broadcast_pipe.Writer.write frontier_w None |> don't_wait_for ;
    upon
      (Bootstrap_controller.run ~logger ~trust_system ~verifier ~network
         ~ledger_db ~frontier ~transition_reader:!transition_reader_ref)
      (fun (new_frontier, collected_transitions) ->
        Strict_pipe.Writer.kill !transition_writer_ref ;
        start_transition_frontier_controller ~logger ~trust_system ~verifier
          ~network ~time_controller ~proposer_transition_reader
          ~verified_transition_writer ~clear_reader ~collected_transitions
          ~transition_reader_ref ~transition_writer_ref ~frontier_w
          new_frontier )

  let download_best_tip ~logger ~network ~verifier ~trust_system
      ~most_recent_valid_block_writer =
    let num_peers = 8 in
    let peers = Network.random_peers network num_peers in
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__
      "Requesting peers for their best tip to do initialization" ;
    let open Deferred.Option.Let_syntax in
    let%map best_tip =
      Deferred.List.fold peers ~init:None ~f:(fun acc peer ->
          let open Deferred.Let_syntax in
          match%bind Network.get_best_tip network peer with
          | Error e ->
              Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
                ~metadata:[("peer", Network_peer.Peer.to_yojson peer)]
                !"Could not get best tip from peer: %{sexp:Error.t}"
                e ;
              return acc
          | Ok peer_best_tip -> (
              match%bind Best_tip_prover.verify ~verifier peer_best_tip with
              | Error e ->
                  let error_msg =
                    sprintf
                      !"Peer %{sexp:Network_peer.Peer.t} sent us bad proof \
                        for their best tip"
                      peer
                  in
                  Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
                    ~metadata:[("error", `String (Error.to_string_hum e))]
                    !"%s" error_msg ;
                  let%map () =
                    Trust_system.(
                      record trust_system logger peer.host
                        Actions.(Violated_protocol, Some (error_msg, [])))
                  in
                  acc
              | Ok (`Root _, `Best_tip candidate_best_tip) ->
                  let enveloped_candidate_best_tip =
                    Envelope.Incoming.wrap ~data:candidate_best_tip
                      ~sender:(Envelope.Sender.Remote peer.host)
                  in
                  return
                  @@ Option.merge acc
                       (Option.return enveloped_candidate_best_tip)
                       ~f:(fun existing_best_tip_enveloped
                          candidate_best_tip_enveloped
                          ->
                         let candidate_best_tip =
                           With_hash.data @@ fst
                           @@ Envelope.Incoming.data
                                candidate_best_tip_enveloped
                         in
                         let existing_best_tip =
                           With_hash.data @@ fst
                           @@ Envelope.Incoming.data
                                existing_best_tip_enveloped
                         in
                         if
                           External_transition.compare candidate_best_tip
                             existing_best_tip
                           > 0
                         then (
                           candidate_best_tip
                           |> Broadcast_pipe.Writer.write
                                most_recent_valid_block_writer
                           |> don't_wait_for ;
                           candidate_best_tip_enveloped )
                         else existing_best_tip_enveloped ) ) )
    in
    best_tip |> Envelope.Incoming.data |> fst |> With_hash.data
    |> Broadcast_pipe.Writer.write most_recent_valid_block_writer
    |> don't_wait_for ;
    best_tip

  let initialize ~logger ~network ~verifier ~trust_system ~frontier
      ~time_controller ~ledger_db ~frontier_w ~proposer_transition_reader
      ~clear_reader ~verified_transition_writer ~transition_reader_ref
      ~transition_writer_ref ~most_recent_valid_block_writer =
    let%bind () =
      let connectivity_time_upper_bound =
        Consensus.Constants.initialization_time_in_secs
      in
      let high_connectivity_deferred =
        Ivar.read (Network.high_connectivity network)
      in
      Deferred.any
        [ high_connectivity_deferred
        ; ( after (Time_ns.Span.of_sec connectivity_time_upper_bound)
          >>| fun () ->
          if not @@ Deferred.is_determined high_connectivity_deferred then
            Logger.info logger ~module_:__MODULE__ ~location:__LOC__
              ~metadata:
                [ ("num_peers", `Int (List.length @@ Network.peers network))
                ; ( "connectivity_time_upper_bound"
                  , `Float connectivity_time_upper_bound ) ]
              !"After waiting $connectivity_time_upper_bound, we only \
                accumulate $num_peers peers. Possible reasons for that could \
                be: \n\
                1. You're the first couple of peers joining the testnet. \n\
                2. The network is slow. \n\n\n\
                Would start initialization anyway." ) ]
    in
    match%map
      download_best_tip ~logger ~network ~verifier ~trust_system
        ~most_recent_valid_block_writer
    with
    | Some best_tip_enveloped ->
        if
          is_transition_for_bootstrap ~logger ~frontier
            ( best_tip_enveloped |> Envelope.Incoming.data |> fst
            |> With_hash.data )
        then (
          Strict_pipe.Reader.clear !transition_reader_ref ;
          start_bootstrap_controller ~logger ~trust_system ~verifier ~network
            ~time_controller ~proposer_transition_reader
            ~verified_transition_writer ~clear_reader ~transition_reader_ref
            ~transition_writer_ref ~ledger_db ~frontier_w frontier ;
          Strict_pipe.Writer.write !transition_writer_ref best_tip_enveloped )
        else (
          Strict_pipe.Reader.clear !transition_reader_ref ;
          start_transition_frontier_controller ~logger ~trust_system ~verifier
            ~network ~time_controller ~proposer_transition_reader
            ~verified_transition_writer ~clear_reader
            ~collected_transitions:[best_tip_enveloped] ~transition_reader_ref
            ~transition_writer_ref ~frontier_w frontier )
    | None ->
        start_transition_frontier_controller ~logger ~trust_system ~verifier
          ~network ~time_controller ~proposer_transition_reader
          ~verified_transition_writer ~clear_reader ~collected_transitions:[]
          ~transition_reader_ref ~transition_writer_ref ~frontier_w frontier

  let wait_till_genesis ~logger ~time_controller =
    let module Time = Coda_base.Block_time in
    let now = Time.now time_controller in
    try Consensus.Hooks.is_genesis now |> ignore
    with Invalid_argument _ ->
      let time_till_genesis =
        Time.diff Consensus.Constants.genesis_state_timestamp now
      in
      Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
        ~metadata:
          [ ( "time_till_genesis"
            , `Int (Int64.to_int_exn (Time.Span.to_ms time_till_genesis)) ) ]
        "Node started before genesis: waiting $time_till_genesis milliseconds \
         before running transition router" ;
      let seconds_to_wait = 30 in
      let milliseconds_to_wait = Int64.of_int_exn (seconds_to_wait * 1000) in
      let rec wait_loop tm =
        if Int64.(tm <= zero) then ()
        else (
          Core.Unix.sleep seconds_to_wait ;
          let tm_remaining = Int64.(tm - milliseconds_to_wait) in
          Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
            "Still waiting $tm_remaining milliseconds before running \
             transition router"
            ~metadata:[("tm_remaining", `Int (Int64.to_int_exn tm_remaining))] ;
          wait_loop tm_remaining )
      in
      wait_loop @@ Time.Span.to_ms time_till_genesis

  let run ~logger ~trust_system ~verifier ~network ~time_controller
      ~frontier_broadcast_pipe:(frontier_r, frontier_w) ~ledger_db
      ~network_transition_reader ~proposer_transition_reader
      ~most_recent_valid_block:( most_recent_valid_block_reader
                               , most_recent_valid_block_writer ) frontier =
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
    wait_till_genesis ~logger ~time_controller ;
    let ( valid_protocol_state_transition_reader
        , valid_protocol_state_transition_writer ) =
      create_bufferred_pipe ~name:"valid transitions" ()
    in
    Initial_validator.run ~logger ~trust_system ~verifier
      ~transition_reader:network_transition_reader
      ~valid_transition_writer:valid_protocol_state_transition_writer ;
    upon
      (initialize ~logger ~network ~verifier ~trust_system ~frontier
         ~time_controller ~ledger_db ~frontier_w ~proposer_transition_reader
         ~clear_reader ~verified_transition_writer ~transition_reader_ref
         ~transition_writer_ref ~most_recent_valid_block_writer) (fun () ->
        let valid_protocol_state_transition_reader, valid_transition_reader =
          Strict_pipe.Reader.Fork.two valid_protocol_state_transition_reader
        in
        Strict_pipe.Reader.iter valid_transition_reader
          ~f:(fun enveloped_transition ->
            let transition =
              Envelope.Incoming.data enveloped_transition
              |> fst |> With_hash.data
            in
            let current_consensus_state =
              External_transition.consensus_state
                (Broadcast_pipe.Reader.peek most_recent_valid_block_reader)
            in
            if
              Consensus.Hooks.select ~existing:current_consensus_state
                ~candidate:External_transition.(consensus_state transition)
                ~logger
              = `Take
            then
              Broadcast_pipe.Writer.write most_recent_valid_block_writer
                transition
            else Deferred.unit )
        |> don't_wait_for ;
        Strict_pipe.Reader.iter_without_pushback
          valid_protocol_state_transition_reader
          ~f:(fun enveloped_transition ->
            let transition =
              Envelope.Incoming.data enveloped_transition
              |> fst |> With_hash.data
            in
            ( match Broadcast_pipe.Reader.peek frontier_r with
            | Some frontier ->
                if is_transition_for_bootstrap ~logger ~frontier transition
                then (
                  Strict_pipe.Writer.kill !transition_writer_ref ;
                  Strict_pipe.Writer.write clear_writer `Clear
                  |> don't_wait_for ;
                  start_bootstrap_controller ~logger ~trust_system ~verifier
                    ~network ~time_controller ~proposer_transition_reader
                    ~verified_transition_writer ~clear_reader
                    ~transition_reader_ref ~transition_writer_ref ~ledger_db
                    ~frontier_w frontier )
            | None ->
                () ) ;
            Strict_pipe.Writer.write !transition_writer_ref
              enveloped_transition )
        |> don't_wait_for ) ;
    verified_transition_reader
end

include Make (struct
  include Transition_frontier.Inputs
  module Transition_frontier = Transition_frontier
  module Network = Coda_networking
  module Transition_frontier_controller = Transition_frontier_controller
  module Bootstrap_controller = Bootstrap_controller
  module Best_tip_prover = Best_tip_prover
end)
