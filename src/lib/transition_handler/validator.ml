open Async_kernel
open Core_kernel
open Pipe_lib.Strict_pipe
open Mina_base
open Mina_state
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
    ~unprocessed_transition_cache env =
  let open Result.Let_syntax in
  let%bind () =
    Option.fold
      (Unprocessed_transition_cache.final_state unprocessed_transition_cache env)
      ~init:Result.(Ok ())
      ~f:(fun _ final_state -> Result.Error (`In_process final_state))
  in
  let header_with_hash =
    With_hash.map ~f:Mina_block.header
      (Mina_block.Validation.block_with_hash @@ Envelope.Incoming.data env)
  in
  let%map () =
    verify_header_is_relevant
      ~context:(module Context)
      ~frontier header_with_hash
  in
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

let record_transition_is_irrelevant ~logger ~trust_system ~senders ~error
    header_with_hash =
  let transition_hash =
    State_hash.With_state_hashes.state_hash header_with_hash
  in
  let header = With_hash.data header_with_hash in
  match error with
  | `In_frontier _ | `In_process _ ->
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
      Mina_metrics.(Counter.inc_one Rejected_blocks.worse_than_root) ;
      [%log error]
        ~metadata:
          [ ("state_hash", State_hash.to_yojson transition_hash)
          ; ("reason", `String "not selected over current root")
          ; ( "protocol_state"
            , Header.protocol_state header |> Protocol_state.value_to_yojson )
          ]
        "Validation error: external transition with state hash $state_hash was \
         rejected for reason $reason" ;
      Deferred.List.iter senders ~f:(fun sender ->
          Trust_system.record_envelope_sender trust_system logger sender
            ( Trust_system.Actions.Disconnected_chain
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
    Header.protocol_state header
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
  let module Lru = Core_extended_cache.Lru in
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
          match
            verify_transition_or_header_is_relevant
              ~context:(module Context)
              ~frontier ~unprocessed_transition_cache ~gd_map b_or_h
          with
          | Ok b_or_h' ->
              let%map () =
                record_transition_is_relevant ~logger ~trust_system ~senders
                  ~time_controller header_with_hash
              in
              Writer.write valid_transition_writer (b_or_h', `Gossip_map gd_map)
          | Error error ->
              record_transition_is_irrelevant ~logger ~trust_system ~senders
                ~error header_with_hash ) )
