open Async_kernel
open Core_kernel
open Pipe_lib.Strict_pipe
open Mina_base
open Mina_state
open Cache_lib
open Network_peer

let validate_block ~consensus_constants ~logger ~frontier
    ~unprocessed_block_cache
    (enveloped_block :
      Mina_block.initial_valid_block Envelope.Incoming.t) =
  let open Result.Let_syntax in
  let block =
    Envelope.Incoming.data enveloped_block
    |> Mina_block.Validation.block_with_hash
  in
  let block_hash = With_hash.hash block in
  let consensus_state =
    With_hash.map block ~f:(fun b ->
      b
      |> Mina_block.header
      |> Mina_block.Header.protocol_state
      |> Protocol_state.consensus_state)
  in
  let root_breadcrumb = Transition_frontier.root frontier in
  let%bind () =
    Option.fold
      (Transition_frontier.find frontier block_hash)
      ~init:Result.(Ok ())
      ~f:(fun _ _ -> Result.Error (`In_frontier block_hash))
  in
  let%bind () =
    Option.fold
      (Unprocessed_block_cache.final_state unprocessed_block_cache
         enveloped_block)
      ~init:Result.(Ok ())
      ~f:(fun _ final_state -> Result.Error (`In_process final_state))
  in
  let%map () =
    Result.ok_if_true
      (Consensus.Hooks.equal_select_status `Take
         (Consensus.Hooks.select ~constants:consensus_constants
            ~logger:
              (Logger.extend logger
                 [ ("selection_context", `String "Transition_handler.Validator")
                 ])
            ~existing:
              (Transition_frontier.Breadcrumb.consensus_state_with_hash
                 root_breadcrumb)
            ~candidate:consensus_state))
      ~error:`Disconnected
  in
  (* we expect this to be Ok since we just checked the cache *)
  Unprocessed_block_cache.register_exn unprocessed_block_cache
    enveloped_block

let run ~logger ~consensus_constants ~trust_system ~time_controller ~frontier
    ~block_reader
    ~(valid_block_writer :
       ( ( Mina_block.initial_valid_block Envelope.Incoming.t
         , State_hash.t )
         Cached.t
       , drop_head buffered
       , unit )
       Writer.t) ~unprocessed_block_cache =
  let module Lru = Core_extended_cache.Lru in
  don't_wait_for
    (Reader.iter block_reader ~f:(fun block_env ->
         let { With_hash.hash = block_hash; data = block }, _ =
           Envelope.Incoming.data block_env
         in
         let sender = Envelope.Incoming.sender block_env in
         let protocol_state = Mina_block.Header.protocol_state @@ Mina_block.header block in
         match
           validate_block ~consensus_constants ~logger ~frontier
             ~unprocessed_block_cache block_env
         with
         | Ok cached_block ->
             let%map () =
               Trust_system.record_envelope_sender trust_system logger sender
                 ( Trust_system.Actions.Sent_useful_gossip
                 , Some
                     ( "block $state_hash"
                     , [ ("state_hash", State_hash.to_yojson block_hash)
                       ; ("block", Mina_block.to_yojson block)
                       ] ) )
             in
             let block_time =
               protocol_state
               |> Protocol_state.blockchain_state
               |> Blockchain_state.timestamp
               |> Block_time.to_time
             in
             Perf_histograms.add_span ~name:"accepted_transition_remote_latency"
               (Core_kernel.Time.diff
                  Block_time.(now time_controller |> to_time)
                  block_time) ;
             Writer.write valid_block_writer cached_block
         | Error (`In_frontier _) | Error (`In_process _) ->
             Trust_system.record_envelope_sender trust_system logger sender
               ( Trust_system.Actions.Sent_old_gossip
               , Some
                   ( "block with state hash $state_hash"
                   , [ ("state_hash", State_hash.to_yojson block_hash)
                     ; ("block", Mina_block.to_yojson block)
                     ] ) )
         | Error `Disconnected ->
             Mina_metrics.(Counter.inc_one Rejected_blocks.worse_than_root) ;
             [%log error]
               ~metadata:
                 [ ("state_hash", State_hash.to_yojson block_hash)
                 ; ("reason", `String "not selected over current root")
                 ; ( "protocol_state"
                   , Protocol_state.value_to_yojson protocol_state)
                 ]
               "Validation error: block with state hash \
                $state_hash was rejected for reason $reason" ;
             Trust_system.record_envelope_sender trust_system logger sender
               ( Trust_system.Actions.Disconnected_chain
               , Some
                   ( "received block that was not connected to our chain \
                      from $sender"
                   , [ ( "sender"
                       , Envelope.Sender.to_yojson
                           (Envelope.Incoming.sender block_env) )
                     ; ("block", Mina_block.to_yojson block)
                     ] ) )))
