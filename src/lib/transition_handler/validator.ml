open Async_kernel
open Core_kernel
open Pipe_lib.Strict_pipe
open Mina_base
open Mina_state
open Cache_lib
open Mina_block
open Network_peer

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t
end

let validate_transition ~context:(module Context : CONTEXT) ~frontier
    ~unprocessed_transition_cache enveloped_transition =
  let logger = Context.logger in
  let open Result.Let_syntax in
  let transition =
    Envelope.Incoming.data enveloped_transition
    |> Mina_block.Validation.block_with_hash
  in
  let transition_hash = State_hash.With_state_hashes.state_hash transition in
  [%log internal] "Validate_transition" ;
  let root_breadcrumb = Transition_frontier.root frontier in
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
  let%map () =
    Result.ok_if_true
      (Consensus.Hooks.equal_select_status `Take
         (Consensus.Hooks.select
            ~context:(module Context)
            ~existing:
              (Transition_frontier.Breadcrumb.consensus_state_with_hashes
                 root_breadcrumb )
            ~candidate:(With_hash.map ~f:Mina_block.consensus_state transition) ) )
      ~error:`Disconnected
  in
  [%log internal] "Register_transition_for_processing" ;
  (* we expect this to be Ok since we just checked the cache *)
  Unprocessed_transition_cache.register_exn unprocessed_transition_cache
    enveloped_transition

let run ~context:(module Context : CONTEXT) ~trust_system ~time_controller
    ~frontier ~transition_reader
    ~(valid_transition_writer :
       ( [ `Block of
           ( Mina_block.initial_valid_block Envelope.Incoming.t
           , State_hash.t )
           Cached.t ]
         * [ `Valid_cb of Mina_net2.Validation_callback.t option ]
       , drop_head buffered
       , unit )
       Writer.t ) ~unprocessed_transition_cache =
  let open Context in
  let module Lru = Core_extended_cache.Lru in
  O1trace.background_thread "validate_blocks_against_frontier" (fun () ->
      Reader.iter transition_reader
        ~f:(fun (`Block transition_env, `Valid_cb vc) ->
          let transition_with_hash, _ = Envelope.Incoming.data transition_env in
          let transition_hash =
            State_hash.With_state_hashes.state_hash transition_with_hash
          in
          Internal_tracing.Context_call.with_call_id
            ~tag:"transition_handler_validator"
          @@ fun () ->
          Internal_tracing.with_state_hash transition_hash
          @@ fun () ->
          let transition = With_hash.data transition_with_hash in
          let sender = Envelope.Incoming.sender transition_env in
          match
            validate_transition
              ~context:(module Context)
              ~frontier ~unprocessed_transition_cache transition_env
          with
          | Ok cached_transition ->
              let%map () =
                Trust_system.record_envelope_sender trust_system logger sender
                  ( Trust_system.Actions.Sent_useful_gossip
                  , Some
                      ( "external transition $state_hash"
                      , [ ("state_hash", State_hash.to_yojson transition_hash)
                        ; ("transition", Mina_block.to_yojson transition)
                        ] ) )
              in
              let transition_time =
                Mina_block.header transition
                |> Header.protocol_state |> Protocol_state.blockchain_state
                |> Blockchain_state.timestamp |> Block_time.to_time_exn
              in
              Perf_histograms.add_span
                ~name:"accepted_transition_remote_latency"
                (Core_kernel.Time.diff
                   Block_time.(now time_controller |> to_time_exn)
                   transition_time ) ;
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
              [%log error]
                ~metadata:
                  [ ("state_hash", State_hash.to_yojson transition_hash)
                  ; ("reason", `String "not selected over current root")
                  ; ( "protocol_state"
                    , Header.protocol_state (Mina_block.header transition)
                      |> Protocol_state.value_to_yojson )
                  ]
                "Validation error: external transition with state hash \
                 $state_hash was rejected for reason $reason" ;
              Trust_system.record_envelope_sender trust_system logger sender
                ( Trust_system.Actions.Disconnected_chain
                , Some
                    ( "received transition that was not connected to our chain \
                       from $sender"
                    , [ ( "sender"
                        , Envelope.Sender.to_yojson
                            (Envelope.Incoming.sender transition_env) )
                      ; ("transition", Mina_block.to_yojson transition)
                      ] ) ) ) )
