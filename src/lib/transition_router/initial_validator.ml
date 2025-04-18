open Core_kernel
open Async_kernel
open Mina_base
open Mina_state
open Signature_lib
open Mina_block
open Network_peer

type validation_error =
  [ `Invalid_time_received of [ `Too_early | `Too_late of int64 ]
  | `Invalid_genesis_protocol_state
  | `Invalid_proof of Error.t
  | `Invalid_delta_block_chain_proof
  | `Verifier_error of Error.t
  | `Mismatched_protocol_version
  | `Invalid_protocol_version ]
[@@deriving sexp_of]

let handle_validation_error ~logger ~rejected_blocks_logger ~time_received
    ~trust_system ~sender ~header_with_hash ~delta (error : validation_error) =
  let open Trust_system.Actions in
  let state_hash = State_hash.With_state_hashes.state_hash header_with_hash in
  let header = With_hash.data header_with_hash in
  let punish action message =
    let message' =
      "external transition with state hash $state_hash"
      ^ Option.value_map message ~default:"" ~f:(fun (txt, _) ->
            sprintf ", %s" txt )
    in
    let metadata =
      ("state_hash", State_hash.to_yojson state_hash)
      :: Option.value_map message ~default:[] ~f:Tuple2.get2
    in
    Trust_system.record_envelope_sender trust_system logger sender
      (action, Some (message', metadata))
  in
  let metadata =
    match error with
    | `Invalid_time_received `Too_early ->
        [ ("reason", `String "invalid time")
        ; ("time_error", `String "too early")
        ]
    | `Invalid_time_received (`Too_late slot_diff) ->
        [ ("reason", `String "invalid time")
        ; ("time_error", `String "too late")
        ; ("slot_diff", `String (Int64.to_string slot_diff))
        ]
    | `Invalid_genesis_protocol_state ->
        [ ("reason", `String "invalid genesis state") ]
    | `Invalid_proof err ->
        [ ("reason", `String "invalid proof")
        ; ( "protocol_state"
          , Header.protocol_state header |> Protocol_state.value_to_yojson )
        ; ("proof", Header.protocol_state_proof header |> Proof.to_yojson)
        ; ("error", Error_json.error_to_yojson err)
        ]
    | `Invalid_delta_block_chain_proof ->
        [ ("reason", `String "invalid delta transition chain proof") ]
    | `Verifier_error err ->
        [ ("reason", `String "verifier error")
        ; ("error", Error_json.error_to_yojson err)
        ]
    | `Mismatched_protocol_version ->
        [ ("reason", `String "protocol version mismatch") ]
    | `Invalid_protocol_version ->
        [ ("reason", `String "invalid protocol version") ]
  in
  let metadata =
    [ ("state_hash", State_hash.to_yojson state_hash)
    ; ( "time_received"
      , `String
          (Time.to_string_abs
             (Block_time.to_time_exn time_received)
             ~zone:Time.Zone.utc ) )
    ]
    @ metadata
  in
  [%log error] ~metadata
    "Validation error: external transition with state hash $state_hash was \
     rejected for reason $reason" ;
  [%log' debug rejected_blocks_logger]
    ~metadata:
      ( ( "protocol_state"
        , Protocol_state.Value.to_yojson (Header.protocol_state header) )
      :: metadata )
    "Validation error: external transition with state hash $state_hash was \
     rejected for reason $reason" ;
  match error with
  | `Verifier_error err ->
      let error_metadata = [ ("error", Error_json.error_to_yojson err) ] in
      [%log error]
        ~metadata:
          (error_metadata @ [ ("state_hash", State_hash.to_yojson state_hash) ])
        "Error in verifier verifying blockchain proof for $state_hash: $error" ;
      Deferred.unit
  | `Invalid_proof _ ->
      Mina_metrics.(Counter.inc_one Rejected_blocks.invalid_proof) ;
      Queue.enqueue Transition_frontier.rejected_blocks
        (state_hash, sender, time_received, `Invalid_proof) ;
      punish Sent_invalid_proof None
  | `Invalid_delta_block_chain_proof ->
      Queue.enqueue Transition_frontier.rejected_blocks
        ( state_hash
        , sender
        , time_received
        , `Invalid_delta_transition_chain_proof ) ;
      punish Sent_invalid_transition_chain_merkle_proof None
  | `Invalid_time_received `Too_early ->
      Mina_metrics.(Counter.inc_one Rejected_blocks.received_early) ;
      Queue.enqueue Transition_frontier.rejected_blocks
        (state_hash, sender, time_received, `Too_early) ;
      punish Gossiped_future_transition None
  | `Invalid_genesis_protocol_state ->
      Queue.enqueue Transition_frontier.rejected_blocks
        (state_hash, sender, time_received, `Invalid_genesis_protocol_state) ;
      punish Has_invalid_genesis_protocol_state None
  | `Invalid_time_received (`Too_late slot_diff) ->
      Mina_metrics.(Counter.inc_one Rejected_blocks.received_late) ;
      Queue.enqueue Transition_frontier.rejected_blocks
        (state_hash, sender, time_received, `Too_late) ;
      punish
        (Gossiped_old_transition (slot_diff, delta))
        (Some
           ( "off by $slot_diff slots"
           , [ ("slot_diff", `String (Int64.to_string slot_diff)) ] ) )
  | `Invalid_protocol_version ->
      Queue.enqueue Transition_frontier.rejected_blocks
        (state_hash, sender, time_received, `Invalid_protocol_version) ;
      punish Sent_invalid_protocol_version None
  | `Mismatched_protocol_version ->
      Queue.enqueue Transition_frontier.rejected_blocks
        (state_hash, sender, time_received, `Mismatched_protocol_version) ;
      punish Sent_mismatched_protocol_version None

module Duplicate_block_detector = struct
  (* maintain a map from block producer key, epoch, slot to state hashes *)

  module Blocks = struct
    module T = struct
      (* order of fields significant, compare by epoch, then slot, then producer *)
      type t =
        { consensus_time : Consensus.Data.Consensus_time.t
        ; block_producer : Public_key.Compressed.t
        }
      [@@deriving sexp, compare]
    end

    include T
    include Comparable.Make (T)
  end

  type t =
    { mutable table : State_hash.t Blocks.Map.t; mutable latest_epoch : int }

  let gc_count = ref 0

  (* create dummy block to split map on *)
  let make_splitting_block ~consensus_constants
      ({ consensus_time; block_producer = _ } : Blocks.t) : Blocks.t =
    let block_producer = Public_key.Compressed.empty in
    { consensus_time =
        Consensus.Data.Consensus_time.get_old ~constants:consensus_constants
          consensus_time
    ; block_producer
    }

  (* every gc_interval blocks seen, discard blocks more than gc_width ago *)
  let table_gc ~(precomputed_values : Precomputed_values.t) t block =
    let consensus_constants = precomputed_values.consensus_constants in
    let ( `Acceptable_network_delay _
        , `Gc_width _
        , `Gc_width_epoch _
        , `Gc_width_slot _
        , `Gc_interval gc_interval ) =
      Consensus.Constants.gc_parameters consensus_constants
    in
    gc_count := (!gc_count + 1) mod Unsigned.UInt32.to_int gc_interval ;
    if Int.equal !gc_count 0 then
      let splitting_block = make_splitting_block ~consensus_constants block in
      let _, _, gt_map = Map.split t.table splitting_block in
      t.table <- gt_map

  let create () = { table = Map.empty (module Blocks); latest_epoch = 0 }

  let check ~precomputed_values ~rejected_blocks_logger ~time_received t logger
      header_with_hash =
    let header = header_with_hash.With_hash.data in
    let protocol_state_hash =
      State_hash.With_state_hashes.state_hash header_with_hash
    in
    let open Consensus.Data.Consensus_state in
    let consensus_state =
      Mina_block.Header.protocol_state header |> Protocol_state.consensus_state
    in
    let consensus_time = consensus_time consensus_state in
    let block_producer =
      Consensus.Data.Consensus_state.block_creator consensus_state
    in
    let block = Blocks.{ consensus_time; block_producer } in
    (* try table GC *)
    table_gc ~precomputed_values t block ;
    match Map.find t.table block with
    | None ->
        t.table <- Map.add_exn t.table ~key:block ~data:protocol_state_hash
    | Some hash ->
        if not (State_hash.equal hash protocol_state_hash) then (
          let metadata =
            [ ("block_producer", Public_key.Compressed.to_yojson block_producer)
            ; ( "consensus_time"
              , Consensus.Data.Consensus_time.to_yojson consensus_time )
            ; ("hash", State_hash.to_yojson hash)
            ; ( "current_protocol_state_hash"
              , State_hash.to_yojson protocol_state_hash )
            ; ( "time_received"
              , `String
                  (Time.to_string_abs
                     (Block_time.to_time_exn time_received)
                     ~zone:Time.Zone.utc ) )
            ]
          in
          let msg : (_, unit, string, unit) format4 =
            "Duplicate producer and slot: producer = $block_producer, \
             consensus_time = $consensus_time, previous protocol state hash = \
             $hash, current protocol state hash = $current_protocol_state_hash"
          in
          [%log' debug rejected_blocks_logger] ~metadata msg ;
          [%log error] ~metadata msg )
end

let validate ~proof_cache_db ~logger ~trust_system ~verifier
    ~initialization_finish_signal ~precomputed_values =
  let genesis_state_hash =
    (Precomputed_values.genesis_state_hashes precomputed_values).state_hash
  in
  let genesis_constants =
    Precomputed_values.genesis_constants precomputed_values
  in
  let rejected_blocks_logger =
    Logger.create ~id:Logger.Logger_id.rejected_blocks ()
  in
  let duplicate_checker = Duplicate_block_detector.create () in
  stage (fun ~b_or_h ~time_received ~valid_cb ->
      let header, sender =
        match b_or_h with
        | `Block b_env ->
            ( Mina_block.Stable.Latest.header (Envelope.Incoming.data b_env)
            , Envelope.Incoming.sender b_env )
        | `Header h_env ->
            (Envelope.Incoming.data h_env, Envelope.Incoming.sender h_env)
      in
      let open Deferred.Let_syntax in
      if Ivar.is_full initialization_finish_signal then (
        let blockchain_length =
          Mina_block.Header.blockchain_length header
          |> Mina_numbers.Length.to_int
        in
        Mina_metrics.Transition_frontier
        .update_max_unvalidated_blocklength_observed blockchain_length ;
        ( if not (Mina_net2.Validation_callback.is_expired valid_cb) then (
          let header_hashed =
            With_hash.of_data header
              ~hash_data:
                (Fn.compose Protocol_state.hashes Header.protocol_state)
          in
          Duplicate_block_detector.check ~precomputed_values
            ~rejected_blocks_logger ~time_received duplicate_checker logger
            header_hashed ;
          let computation =
            let open Interruptible.Let_syntax in
            let defer f x =
              Interruptible.uninterruptible @@ Deferred.return (f x)
            in
            let%bind () =
              Interruptible.lift Deferred.unit
                (Mina_net2.Validation_callback.await_timeout valid_cb)
            in
            match%bind
              let open Interruptible.Result.Let_syntax in
              Validation.(
                wrap_header header_hashed
                |> defer
                     (validate_time_received ~precomputed_values ~time_received)
                >>= defer (validate_genesis_protocol_state ~genesis_state_hash)
                >>= Fn.compose Interruptible.uninterruptible
                      (validate_single_proof ~verifier ~genesis_state_hash)
                >>= defer validate_delta_block_chain
                >>= defer validate_protocol_versions)
            with
            | Ok verified_header ->
                [%log internal] "Initial_validation_done" ;
                let body b =
                  Mina_block.Stable.Latest.body b
                  |> Staged_ledger_diff.Body.write_all_proofs_to_disk
                       ~proof_cache_db
                in
                let b_or_h' =
                  match b_or_h with
                  | `Block b_env ->
                      `Block
                        (Envelope.Incoming.map
                           ~f:
                             (Fn.compose
                                (Mina_block.Validation.with_body verified_header)
                                body )
                           b_env )
                  | `Header h_env ->
                      `Header
                        (Envelope.Incoming.map ~f:(Fn.const verified_header)
                           h_env )
                in
                Mina_metrics.Transition_frontier.update_max_blocklength_observed
                  blockchain_length ;
                Queue.enqueue Transition_frontier.validated_blocks
                  ( State_hash.With_state_hashes.state_hash header_hashed
                  , sender
                  , time_received ) ;
                return (Ok (b_or_h', `Valid_cb valid_cb))
            | Error error ->
                Mina_net2.Validation_callback.fire_if_not_already_fired valid_cb
                  `Reject ;
                let%map () =
                  Interruptible.uninterruptible
                  @@ handle_validation_error ~logger ~rejected_blocks_logger
                       ~time_received ~trust_system ~sender
                       ~header_with_hash:header_hashed
                       ~delta:genesis_constants.protocol.delta error
                in
                Error ()
          in
          Interruptible.force computation )
        else Deferred.Result.fail () )
        >>| function
        | Ok (Ok res) ->
            Ok res
        | Ok (Error ()) ->
            Error ()
        | Error () ->
            let state_hash =
              (Header.protocol_state header |> Protocol_state.hashes).state_hash
            in
            let metadata =
              [ ("state_hash", State_hash.to_yojson state_hash)
              ; ( "time_received"
                , `String
                    (Time.to_string_abs
                       (Block_time.to_time_exn time_received)
                       ~zone:Time.Zone.utc ) )
              ]
            in
            [%log error] ~metadata
              "Dropping blocks because libp2p validation expired" ;
            Error () )
      else Deferred.Result.fail () )
