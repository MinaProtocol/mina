open Async_kernel
open Core_kernel
open Pipe_lib.Strict_pipe
open Mina_base
open Mina_state
open Cache_lib
open Network_peer

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t
end

let verify_header_is_relevant ~context:(module Context : CONTEXT) ~frontier
    header_with_hash =
  let module Context = struct
    include Context

    let logger =
      Logger.extend logger
        [ ("selection_context", `String "Transition_handler.Validator") ]
  end in
  let transition_hash =
    State_hash.With_state_hashes.state_hash header_with_hash
  in
  [%log' internal Context.logger] "Validate_transition" ;
  let get_consensus_constants h =
    Mina_block.Header.protocol_state h |> Protocol_state.consensus_state
  in
  let blockchain_length =
    With_hash.data header_with_hash |> Mina_block.Header.blockchain_length
  in
  let root_breadcrumb = Transition_frontier.root frontier in
  [%log' internal Context.logger] "@block_metadata"
    ~metadata:
      [ ("blockchain_length", Mina_numbers.Length.to_yojson blockchain_length) ] ;
  [%log' internal Context.logger] "Check_transition_not_in_frontier" ;
  let open Result.Let_syntax in
  let%bind () =
    Option.fold
      (Transition_frontier.find frontier transition_hash)
      ~init:Result.(Ok ())
      ~f:(fun _ _ -> Result.Error (`In_frontier transition_hash))
  in
  [%log' internal Context.logger] "Check_transition_not_in_process" ;
  Result.ok_if_true
    (Consensus.Hooks.equal_select_status `Take
       (Consensus.Hooks.select
          ~context:(module Context)
          ~existing:
            (Transition_frontier.Breadcrumb.consensus_state_with_hashes
               root_breadcrumb )
          ~candidate:(With_hash.map ~f:get_consensus_constants header_with_hash) ) )
    ~error:`Disconnected

let verify_transition_is_relevant ~context:(module Context : CONTEXT) ~frontier
    ~unprocessed_transition_cache enveloped_transition =
  let open Result.Let_syntax in
  let transition =
    Envelope.Incoming.data enveloped_transition
    |> Mina_block.Validation.block_with_hash
  in
  let%bind () =
    Option.fold
      (Unprocessed_transition_cache.final_state unprocessed_transition_cache
         enveloped_transition )
      ~init:Result.(Ok ())
      ~f:(fun _ final_state -> Result.Error (`In_process final_state))
  in
  [%log' internal Context.logger] "Check_transition_can_be_connected" ;
  let header_with_hash = With_hash.map ~f:Mina_block.header transition in
  let%map () =
    verify_header_is_relevant
      ~context:(module Context)
      ~frontier header_with_hash
  in
  [%log' internal Context.logger] "Register_transition_for_processing" ;
  (* we expect this to be Ok since we just checked the cache *)
  Unprocessed_transition_cache.register_exn unprocessed_transition_cache
    enveloped_transition

let verify_transition_or_header_is_relevant ~context:(module Context : CONTEXT)
    ~frontier ~unprocessed_transition_cache b_or_h =
  match b_or_h with
  | `Block b ->
      Result.map ~f:(fun x -> `Block x)
      @@ verify_transition_is_relevant
           ~context:(module Context)
           ~frontier ~unprocessed_transition_cache b
  | `Header h ->
      let header_with_hash, _ = Envelope.Incoming.data h in
      Result.map ~f:(fun _ -> `Header h)
      @@ verify_header_is_relevant
           ~context:(module Context)
           ~frontier header_with_hash

let run ~context:(module Context : CONTEXT) ~trust_system ~time_controller
    ~frontier ~transition_reader
    ~(valid_transition_writer :
       ( [ `Block of
           ( Mina_block.initial_valid_block Envelope.Incoming.t
           , State_hash.t )
           Cached.t
         | `Header of Mina_block.initial_valid_header Envelope.Incoming.t ]
         * [ `Valid_cb of Mina_net2.Validation_callback.t option ]
       , drop_head buffered
       , unit )
       Writer.t ) ~unprocessed_transition_cache =
  let open Context in
  let module Lru = Core_extended_cache.Lru in
  let outdated_root_cache = Lru.create ~destruct:None 1000 in
  O1trace.background_thread "validate_blocks_against_frontier" (fun () ->
      Reader.iter transition_reader ~f:(fun (b_or_h, `Valid_cb vc) ->
          let header_with_hash, sender =
            match b_or_h with
            | `Block b ->
                let block_with_hash, _ = Envelope.Incoming.data b in
                ( With_hash.map ~f:Mina_block.header block_with_hash
                , Envelope.Incoming.sender b )
            | `Header h ->
                let header_with_hash, _ = Envelope.Incoming.data h in
                (header_with_hash, Envelope.Incoming.sender h)
          in
          let header = With_hash.data header_with_hash in
          let transition_hash =
            State_hash.With_state_hashes.state_hash header_with_hash
          in
          Internal_tracing.Context_call.with_call_id
            ~tag:"transition_handler_validator"
          @@ fun () ->
          Internal_tracing.with_state_hash transition_hash
          @@ fun () ->
          match
            verify_transition_or_header_is_relevant
              ~context:(module Context)
              ~frontier ~unprocessed_transition_cache b_or_h
          with
          | Ok b_or_h' ->
              let%map () =
                Trust_system.record_envelope_sender trust_system logger sender
                  ( Trust_system.Actions.Sent_useful_gossip
                  , Some
                      ( "external transition $state_hash"
                      , [ ("state_hash", State_hash.to_yojson transition_hash)
                        ; ("header", Mina_block.Header.to_yojson header)
                        ] ) )
              in
              let transition_time =
                Mina_block.Header.protocol_state header
                |> Protocol_state.blockchain_state |> Blockchain_state.timestamp
                |> Block_time.to_time_exn
              in
              Perf_histograms.add_span
                ~name:"accepted_transition_remote_latency"
                (Core_kernel.Time.diff
                   Block_time.(now time_controller |> to_time_exn)
                   transition_time ) ;
              [%log internal] "Validate_transition_done" ;
              Writer.write valid_transition_writer (b_or_h', `Valid_cb vc)
          | Error (`In_frontier _) | Error (`In_process _) ->
              [%log internal] "Failure"
                ~metadata:[ ("reason", `String "In_frontier or In_process") ] ;
              (* Send_old_gossip isn't necessary true, there is a possibility of race condition when the
                 process retrieved the transition via catchup mechanism slightly before the gossip reached *)
              Trust_system.record_envelope_sender trust_system logger sender
                ( Trust_system.Actions.Sent_old_gossip
                , Some
                    ( "external transition with state hash $state_hash"
                    , [ ("state_hash", State_hash.to_yojson transition_hash)
                      ; ("header", Mina_block.Header.to_yojson header)
                      ] ) )
          | Error `Disconnected ->
              [%log internal] "Failure"
                ~metadata:[ ("reason", `String "Disconnected") ] ;
              Mina_metrics.(Counter.inc_one Rejected_blocks.worse_than_root) ;
              let protocol_state = Mina_block.Header.protocol_state header in
              [%log error]
                ~metadata:
                  [ ("state_hash", State_hash.to_yojson transition_hash)
                  ; ("reason", `String "not selected over current root")
                  ; ( "protocol_state"
                    , Mina_block.Header.protocol_state header
                      |> Protocol_state.value_to_yojson )
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
                    , [ ("sender", Envelope.Sender.to_yojson sender)
                      ; ("header", Mina_block.Header.to_yojson header)
                      ] ) ) ) )
