open Async_kernel
open Core_kernel
open Pipe_lib.Strict_pipe
open Coda_base
open Coda_state
open Cache_lib
open Coda_transition
open Network_peer

let validate_transition ~consensus_constants ~logger ~frontier
    ~unprocessed_transition_cache
    (enveloped_transition :
      External_transition.Initial_validated.t Envelope.Incoming.t) =
  let open Protocol_state in
  let open Result.Let_syntax in
  let {With_hash.hash= transition_hash; data= transition}, _ =
    Envelope.Incoming.data enveloped_transition
  in
  let protocol_state = External_transition.protocol_state transition in
  let root_protocol_state =
    Transition_frontier.root frontier
    |> Transition_frontier.Breadcrumb.protocol_state
  in
  let%bind () =
    Option.fold (Transition_frontier.find frontier transition_hash)
      ~init:Result.ok_unit ~f:(fun _ _ ->
        Result.Error (`In_frontier transition_hash) )
  in
  let%bind () =
    Option.fold
      (Unprocessed_transition_cache.final_state unprocessed_transition_cache
         enveloped_transition) ~init:Result.ok_unit ~f:(fun _ final_state ->
        Result.Error (`In_process final_state) )
  in
  let%map () =
    Result.ok_if_true
      ( `Take
      = Consensus.Hooks.select ~constants:consensus_constants
          ~logger:
            (Logger.extend logger
               [("selection_context", `String "Transition_handler.Validator")])
          ~existing:(consensus_state root_protocol_state)
          ~candidate:(consensus_state protocol_state) )
      ~error:`Disconnected
  in
  (* we expect this to be Ok since we just checked the cache *)
  Unprocessed_transition_cache.register_exn unprocessed_transition_cache
    enveloped_transition

let run ~logger ~consensus_constants ~trust_system ~time_controller ~frontier
    ~transition_reader
    ~(valid_transition_writer :
       ( ( External_transition.Initial_validated.t Envelope.Incoming.t
         , State_hash.t )
         Cached.t
       , crash buffered
       , unit )
       Writer.t) ~unprocessed_transition_cache =
  let module Lru = Core_extended_cache.Lru in
  don't_wait_for
    (Reader.iter transition_reader ~f:(fun transition_env ->
         let {With_hash.hash= transition_hash; data= transition}, _ =
           Envelope.Incoming.data transition_env
         in
         let sender = Envelope.Incoming.sender transition_env in
         match
           validate_transition ~consensus_constants ~logger ~frontier
             ~unprocessed_transition_cache transition_env
         with
         | Ok cached_transition ->
             let%map () =
               Trust_system.record_envelope_sender trust_system logger sender
                 ( Trust_system.Actions.Sent_useful_gossip
                 , Some
                     ( "external transition $state_hash"
                     , [ ("state_hash", State_hash.to_yojson transition_hash)
                       ; ( "transition"
                         , External_transition.to_yojson transition ) ] ) )
             in
             let transition_time =
               External_transition.protocol_state transition
               |> Protocol_state.blockchain_state |> Blockchain_state.timestamp
               |> Block_time.to_time
             in
             Perf_histograms.add_span
               ~name:"accepted_transition_remote_latency"
               (Core_kernel.Time.diff
                  Block_time.(now time_controller |> to_time)
                  transition_time) ;
             Writer.write valid_transition_writer cached_transition
         | Error (`In_frontier _) | Error (`In_process _) ->
             Trust_system.record_envelope_sender trust_system logger sender
               ( Trust_system.Actions.Sent_old_gossip
               , Some
                   ( "external transition with state hash $state_hash"
                   , [ ("state_hash", State_hash.to_yojson transition_hash)
                     ; ("transition", External_transition.to_yojson transition)
                     ] ) )
         | Error `Disconnected ->
             Trust_system.record_envelope_sender trust_system logger sender
               ( Trust_system.Actions.Disconnected_chain
               , Some
                   ( "received transition that was not connected to our chain \
                      from $sender"
                   , [ ( "sender"
                       , Envelope.Sender.to_yojson
                           (Envelope.Incoming.sender transition_env) )
                     ; ("transition", External_transition.to_yojson transition)
                     ] ) ) ))
