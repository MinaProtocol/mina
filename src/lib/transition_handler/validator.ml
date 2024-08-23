open Async_kernel
open Core_kernel
open Pipe_lib.Strict_pipe
open Mina_base
open Mina_state
open Cache_lib
open Mina_block
open Network_peer
open Core_extended_cache

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t
end

let is_header_relevant_against_root ~context:(module Context : CONTEXT) ~root
    header_with_hash =
  let module Context = struct
    include Context

    let logger =
      Logger.extend logger
        [ ("selection_context", `String "Transition_handler.Validator") ]
  end in
  let get_consensus_constants h =
    Mina_block.Header.protocol_state h |> Protocol_state.consensus_state
  in
  Consensus.Hooks.equal_select_status `Take
    (Consensus.Hooks.select
       ~context:(module Context)
       ~existing:
         (Transition_frontier.Breadcrumb.consensus_state_with_hashes root)
       ~candidate:(With_hash.map ~f:get_consensus_constants header_with_hash) )

let validate_transition ~context:(module Context : CONTEXT) ~frontier
    ~unprocessed_transition_cache ~slot_tx_end ~slot_chain_end
    enveloped_transition =
  let logger = Context.logger in
  let open Result.Let_syntax in
  let transition =
    Envelope.Incoming.data enveloped_transition
    |> Mina_block.Validation.block_with_hash
  in
  let transition_hash = State_hash.With_state_hashes.state_hash transition in
  [%log internal] "Validate_transition" ;
  let root_breadcrumb = Transition_frontier.root frontier in
  let transition_data = With_hash.data transition in
  let block_slot =
    Consensus.Data.Consensus_state.curr_global_slot
    @@ Protocol_state.consensus_state @@ Header.protocol_state
    @@ Mina_block.header transition_data
  in
  let%bind () =
    match slot_chain_end with
    | Some slot_chain_end
      when Mina_numbers.Global_slot_since_hard_fork.(
             block_slot >= slot_chain_end) ->
        [%log info] "Block after slot_chain_end, rejecting" ;
        Result.fail `Block_after_after_stop_slot
    | None | Some _ ->
        Result.return ()
  in
  let%bind () =
    match slot_tx_end with
    | Some slot_tx_end
      when Mina_numbers.Global_slot_since_hard_fork.(block_slot >= slot_tx_end)
      ->
        [%log info] "Block after slot_tx_end, validating it is empty" ;
        let staged_ledger_diff =
          Body.staged_ledger_diff @@ body transition_data
        in
        Result.ok_if_true
          ( Staged_ledger_diff.compare Staged_ledger_diff.empty_diff
              staged_ledger_diff
          = 0 )
          ~error:`Non_empty_staged_ledger_diff_after_stop_slot
    | None | Some _ ->
        Result.(Ok ())
  in
  let blockchain_length =
    Envelope.Incoming.data enveloped_transition
    |> Mina_block.Validation.block |> Mina_block.blockchain_length
  in
  [%log internal] "@block_metadata"
    ~metadata:
      [ ("blockchain_length", Mina_numbers.Length.to_yojson blockchain_length) ] ;
  [%log internal] "Check_transition_not_in_frontier" ;
  let%bind () =
    Option.fold
      (Transition_frontier.find frontier transition_hash)
      ~init:Result.(Ok ())
      ~f:(fun _ _ -> Result.Error (`In_frontier transition_hash))
  in
  [%log internal] "Check_transition_not_in_process" ;
  let%bind () =
    Option.fold
      (Unprocessed_transition_cache.final_state unprocessed_transition_cache
         enveloped_transition )
      ~init:Result.(Ok ())
      ~f:(fun _ final_state -> Result.Error (`In_process final_state))
  in
  [%log internal] "Check_transition_can_be_connected" ;
  let module Context = struct
    include Context

    let logger =
      Logger.extend logger
        [ ("selection_context", `String "Transition_handler.Validator") ]
  end in
  let get_consensus_constants h =
    Mina_block.Header.protocol_state h |> Protocol_state.consensus_state
  in
  Consensus.Hooks.equal_select_status `Take
    (Consensus.Hooks.select
       ~context:(module Context)
       ~existing:
         (Transition_frontier.Breadcrumb.consensus_state_with_hashes root)
       ~candidate:(With_hash.map ~f:get_consensus_constants header_with_hash) )

let verify_header_is_relevant ~context:(module Context : CONTEXT) ~frontier
    header_with_hash =
  [%log' internal Context.logger] "Validate_transition" ;
  let blockchain_length =
    With_hash.data header_with_hash |> Mina_block.Header.blockchain_length
  in
  [%log' internal Context.logger] "@block_metadata"
    ~metadata:
      [ ("blockchain_length", Mina_numbers.Length.to_yojson blockchain_length) ] ;
  [%log' internal Context.logger] "Check_transition_not_in_frontier" ;
  let transition_hash =
    State_hash.With_state_hashes.state_hash header_with_hash
  in
  let root = Transition_frontier.root frontier in
  let%bind.Result () =
    Option.fold
      (Transition_frontier.find frontier transition_hash)
      ~init:Result.(Ok ())
      ~f:(fun _ _ -> Result.Error (`In_frontier transition_hash))
  in
  [%log' internal Context.logger] "Check_transition_preferred_over_root" ;
  Result.ok_if_true
    (is_header_relevant_against_root
       ~context:(module Context)
       ~root header_with_hash )
    ~error:`Disconnected

let verify_transition_is_relevant ~context:(module Context : CONTEXT) ~frontier
    ~unprocessed_transition_cache env =
  let open Result.Let_syntax in
  let%bind () =
    Option.fold
      (Unprocessed_transition_cache.final_state unprocessed_transition_cache env)
      ~init:Result.(Ok ())
      ~f:(fun _ final_state -> Result.Error (`In_process final_state))
  in
  [%log' internal Context.logger] "Check_transition_can_be_connected" ;
  let header_with_hash =
    With_hash.map ~f:Mina_block.header
      (Mina_block.Validation.block_with_hash @@ Envelope.Incoming.data env)
  in
  let%map () =
    verify_header_is_relevant
      ~context:(module Context)
      ~frontier header_with_hash
  in
  [%log' internal Context.logger] "Register_transition_for_processing" ;
  (* we expect this to be Ok since we just checked the cache *)
  Unprocessed_transition_cache.register_exn unprocessed_transition_cache env

let verify_transition_or_header_is_relevant ~context:(module Context : CONTEXT)
    ~frontier ~unprocessed_transition_cache ~gd_map b_or_h =
  match b_or_h with
  | `Block b ->
      let env =
        Option.value_map
          (String.Map.min_elt gd_map)
          ~f:(fun (_, Transition_frontier.Gossip.{ received_at; sender; _ }) ->
            { Network_peer.Envelope.Incoming.data = b; received_at; sender } )
          ~default:(Network_peer.Envelope.Incoming.local b)
      in
      Result.map ~f:(fun x ->
          `Block (Cache_lib.Cached.transform ~f:(const b) x) )
      @@ verify_transition_is_relevant
           ~context:(module Context)
           ~frontier ~unprocessed_transition_cache env
  | `Header h ->
      Result.map ~f:(fun _ -> `Header h)
      @@ verify_header_is_relevant
           ~context:(module Context)
           ~frontier
           (Mina_block.Validation.header_with_hash h)

let record_transition_is_irrelevant ~logger ~trust_system ~frontier
    ~outdated_root_cache ~senders ~error header_with_hash =
  let transition_hash =
    State_hash.With_state_hashes.state_hash header_with_hash
  in
  let header = With_hash.data header_with_hash in
  match error with
  | `In_frontier _ | `In_process _ ->
      [%log internal] "Failure"
        ~metadata:[ ("reason", `String "In_frontier or In_process") ] ;
      (* Send_old_gossip isn't necessary true, there is a possibility of race condition when the
         process retrieved the transition via catchup mechanism slightly before the gossip reached *)
      Deferred.List.iter senders ~f:(fun sender ->
          Trust_system.record_envelope_sender trust_system logger sender
            ( Trust_system.Actions.Sent_old_gossip
            , Some
                ( "external transition with state hash $state_hash"
                , [ ("state_hash", State_hash.to_yojson transition_hash)
                  ; ("header", Mina_block.Header.to_yojson header)
                  ] ) ) )
  | `Disconnected ->
      [%log internal] "Failure" ~metadata:[ ("reason", `String "Disconnected") ] ;
      Mina_metrics.(Counter.inc_one Rejected_blocks.worse_than_root) ;
      let protocol_state = Mina_block.Header.protocol_state header in
      [%log error]
        ~metadata:
          [ ("state_hash", State_hash.to_yojson transition_hash)
          ; ("reason", `String "not selected over current root")
          ; ("protocol_state", Protocol_state.value_to_yojson protocol_state)
          ]
        "Validation error: external transition with state hash $state_hash was \
         rejected for reason $reason" ;
      let is_in_root_history =
        let open Transition_frontier.Extensions in
        get_extension (Transition_frontier.extensions frontier) Root_history
        |> Root_history.mem
      in
      let parent_hash = Protocol_state.previous_state_hash protocol_state in
      let action =
        if
          is_in_root_history transition_hash
          || Option.is_some (Lru.find outdated_root_cache transition_hash)
        then Trust_system.Actions.Sent_old_gossip
        else if
          is_in_root_history parent_hash
          || Option.is_some (Lru.find outdated_root_cache parent_hash)
        then (
          Lru.add outdated_root_cache ~key:transition_hash ~data:() ;
          Sent_useless_gossip )
        else Disconnected_chain
      in
      Deferred.List.iter senders ~f:(fun sender ->
          Trust_system.record_envelope_sender trust_system logger sender
            ( action
            , Some
                ( "received transition that was not connected to our chain \
                   from $sender"
                , [ ("sender", Envelope.Sender.to_yojson sender)
                  ; ("header", Mina_block.Header.to_yojson header)
                  ] ) ) )

let record_transition_is_relevant ~logger ~trust_system ~senders
    ~time_controller header_with_hash =
  let transition_hash =
    State_hash.With_state_hashes.state_hash header_with_hash
  in
  let header = With_hash.data header_with_hash in
  let%map () =
    Deferred.List.iter senders ~f:(fun sender ->
        Trust_system.record_envelope_sender trust_system logger sender
          ( Trust_system.Actions.Sent_useful_gossip
          , Some
              ( "external transition $state_hash"
              , [ ("state_hash", State_hash.to_yojson transition_hash)
                ; ("header", Mina_block.Header.to_yojson header)
                ] ) ) )
  in
  let transition_time =
    Mina_block.Header.protocol_state header
    |> Protocol_state.blockchain_state |> Blockchain_state.timestamp
    |> Block_time.to_time_exn
  in
  Perf_histograms.add_span ~name:"accepted_transition_remote_latency"
    (Core_kernel.Time.diff
       Block_time.(now time_controller |> to_time_exn)
       transition_time )

let run ~context:(module Context : CONTEXT) ~trust_system ~time_controller
    ~frontier ~transition_reader ~valid_transition_writer
    ~unprocessed_transition_cache =
  let open Context in
  let outdated_root_cache = Lru.create ~destruct:None 1000 in
  O1trace.background_thread "validate_blocks_against_frontier" (fun () ->
      Reader.iter transition_reader ~f:(fun (b_or_h, `Gossip_map gd_map) ->
          let senders = Transition_frontier.Gossip.senders gd_map in
          let header_with_hash =
            match b_or_h with
            | `Block b ->
                With_hash.map ~f:Mina_block.header
                  (Mina_block.Validation.block_with_hash b)
            | `Header h ->
                Mina_block.Validation.header_with_hash h
          in
          let transition_hash =
            State_hash.With_state_hashes.state_hash header_with_hash
          in
          Internal_tracing.Context_call.with_call_id
            ~tag:"transition_handler_validator"
          @@ fun () ->
          Internal_tracing.with_state_hash transition_hash
          @@ fun () ->
          let transition = With_hash.data transition_with_hash in
          let sender = Envelope.Incoming.sender transition_env in
          let slot_tx_end =
            Runtime_config.slot_tx_end_or_default
              precomputed_values.Precomputed_values.runtime_config
          in
          let slot_chain_end =
            Runtime_config.slot_chain_end_or_default
              precomputed_values.runtime_config
          in
          match
            verify_transition_or_header_is_relevant
              ~context:(module Context)
              ~frontier ~unprocessed_transition_cache ~slot_tx_end
              ~slot_chain_end transition_env ~gd_map b_or_h
          with
          | Ok b_or_h' ->
              let%map () =
                record_transition_is_relevant ~logger ~trust_system ~senders
                  ~time_controller header_with_hash
              in
              [%log internal] "Validate_transition_done" ;
              Writer.write valid_transition_writer
                (`Block cached_transition, `Valid_cb vc)
          | Error (`In_frontier _) | Error (`In_process _) ->
              [%log internal] "Failure"
                ~metadata:[ ("reason", `String "In_frontier or In_process") ] ;
              Trust_system.record_envelope_sender trust_system logger sender
                ( Trust_system.Actions.Sent_old_gossip
                , Some
                    ( "external transition with state hash $state_hash"
                    , [ ("state_hash", State_hash.to_yojson transition_hash)
                      ; ("transition", Mina_block.to_yojson transition)
                      ] ) )
          | Error `Disconnected ->
              [%log internal] "Failure"
                ~metadata:[ ("reason", `String "Disconnected") ] ;
              Mina_metrics.(Counter.inc_one Rejected_blocks.worse_than_root) ;
              let protocol_state =
                Mina_block.Header.protocol_state (Mina_block.header transition)
              in
              [%log error]
                ~metadata:
                  [ ("state_hash", State_hash.to_yojson transition_hash)
                  ; ("reason", `String "not selected over current root")
                  ; ( "protocol_state"
                    , Protocol_state.value_to_yojson protocol_state )
                  ]
                "Validation error: external transition with state hash \
                 $state_hash was rejected for reason $reason" ;
              let is_in_root_history =
                let open Transition_frontier.Extensions in
                get_extension
                  (Transition_frontier.extensions frontier)
                  Root_history
                |> Root_history.mem
              in
              let parent_hash =
                Protocol_state.previous_state_hash protocol_state
              in
              let action =
                if
                  is_in_root_history transition_hash
                  || Option.is_some
                       (Lru.find outdated_root_cache transition_hash)
                then Trust_system.Actions.Sent_old_gossip
                else if
                  is_in_root_history parent_hash
                  || Option.is_some (Lru.find outdated_root_cache parent_hash)
                then (
                  Lru.add outdated_root_cache ~key:transition_hash ~data:() ;
                  Sent_useless_gossip )
                else Disconnected_chain
              in
              Trust_system.record_envelope_sender trust_system logger sender
                ( action
                , Some
                    ( "received transition that was not connected to our chain \
                       from $sender"
                    , [ ( "sender"
                        , Envelope.Sender.to_yojson
                            (Envelope.Incoming.sender transition_env) )
                      ; ("transition", Mina_block.to_yojson transition)
                      ] ) )
          | Error `Non_empty_staged_ledger_diff_after_stop_slot ->
              [%log error]
                ~metadata:
                  [ ("state_hash", State_hash.to_yojson transition_hash)
                  ; ( "reason"
                    , `String "not empty staged ledger diff after slot_tx_end"
                    )
                  ; ( "block_slot"
                    , Mina_numbers.Global_slot_since_hard_fork.to_yojson
                      @@ Consensus.Data.Consensus_state.curr_global_slot
                      @@ Protocol_state.consensus_state @@ Header.protocol_state
                      @@ Mina_block.header @@ transition )
                  ]
                "Validation error: external transition with state hash \
                 $state_hash was rejected for reason $reason" ;
              Deferred.unit
          | Error `Block_after_after_stop_slot ->
              [%log error]
                ~metadata:
                  [ ("state_hash", State_hash.to_yojson transition_hash)
                  ; ("reason", `String "block after slot_chain_end")
                  ; ( "block_slot"
                    , Mina_numbers.Global_slot_since_hard_fork.to_yojson
                      @@ Consensus.Data.Consensus_state.curr_global_slot
                      @@ Protocol_state.consensus_state @@ Header.protocol_state
                      @@ Mina_block.header @@ transition )
                  ]
                "Validation error: external transition with state hash \
                 $state_hash was rejected for reason $reason" ;
              Deferred.unit ) )
