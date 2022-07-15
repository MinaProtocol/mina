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
  let get_consensus_constants h =
    Header.protocol_state h |> Protocol_state.consensus_state
  in
  let root_breadcrumb = Transition_frontier.root frontier in
  let open Result.Let_syntax in
  let%bind () =
    Option.fold
      (Transition_frontier.find frontier transition_hash)
      ~init:Result.(Ok ())
      ~f:(fun _ _ -> Result.Error (`In_frontier transition_hash))
  in
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
  let header_with_hash = With_hash.map ~f:Mina_block.header transition in
  let%map () =
    verify_header_is_relevant
      ~context:(module Context)
      ~frontier header_with_hash
  in
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
                Header.protocol_state header
                |> Protocol_state.blockchain_state |> Blockchain_state.timestamp
                |> Block_time.to_time_exn
              in
              Perf_histograms.add_span
                ~name:"accepted_transition_remote_latency"
                (Core_kernel.Time.diff
                   Block_time.(now time_controller |> to_time_exn)
                   transition_time ) ;
              Writer.write valid_transition_writer (b_or_h', `Valid_cb vc)
          | Error (`In_frontier _) | Error (`In_process _) ->
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
              Mina_metrics.(Counter.inc_one Rejected_blocks.worse_than_root) ;
              [%log error]
                ~metadata:
                  [ ("state_hash", State_hash.to_yojson transition_hash)
                  ; ("reason", `String "not selected over current root")
                  ; ( "protocol_state"
                    , Header.protocol_state header
                      |> Protocol_state.value_to_yojson )
                  ]
                "Validation error: external transition with state hash \
                 $state_hash was rejected for reason $reason" ;
              Trust_system.record_envelope_sender trust_system logger sender
                ( Trust_system.Actions.Disconnected_chain
                , Some
                    ( "received transition that was not connected to our chain \
                       from $sender"
                    , [ ("sender", Envelope.Sender.to_yojson sender)
                      ; ("header", Mina_block.Header.to_yojson header)
                      ] ) ) ) )
