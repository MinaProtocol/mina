open Network_peer
open Core_kernel
open Async
open Pipe_lib.Strict_pipe
open Mina_base
open Mina_state

type block_or_header =
  [ `Block of Mina_block.Stable.Latest.t Envelope.Incoming.t
  | `Header of Mina_block.Header.Stable.Latest.t Envelope.Incoming.t ]

type stream_msg =
  block_or_header
  * [ `Time_received of Block_time.t ]
  * [ `Valid_cb of Mina_net2.Validation_callback.t ]

type block_sink_config =
  { logger : Logger.t
  ; slot_duration_ms : Block_time.Span.t
  ; on_push : unit -> unit Deferred.t
  ; time_controller : Block_time.Controller.t
  ; log_gossip_heard : bool
  ; consensus_constants : Consensus.Constants.t
  ; genesis_constants : Genesis_constants.t
  ; constraint_constants : Genesis_constants.Constraint_constants.t
  }

type t =
  | Sink of
      { writer : (stream_msg, synchronous, unit Deferred.t) Writer.t
      ; rate_limiter : Network_pool.Rate_limiter.t
      ; logger : Logger.t
      ; on_push : unit -> unit Deferred.t
      ; time_controller : Block_time.Controller.t
      ; log_gossip_heard : bool
      ; consensus_constants : Consensus.Constants.t
      ; genesis_constants : Genesis_constants.t
      ; constraint_constants : Genesis_constants.Constraint_constants.t
      }
  | Void

type Structured_log_events.t +=
  | Block_received of { state_hash : State_hash.t; sender : Envelope.Sender.t }
  [@@deriving register_event { msg = "Received a block from $sender" }]

let push sink (b_or_h, `Time_received tm, `Valid_cb cb) =
  match sink with
  | Void ->
      Deferred.unit
  | Sink
      { writer
      ; rate_limiter
      ; logger
      ; on_push
      ; time_controller
      ; log_gossip_heard
      ; consensus_constants
      ; genesis_constants
      ; constraint_constants
      } -> (
      O1trace.sync_thread "handle_block_gossip"
      @@ fun () ->
      (* Handle a gossiped block inside an exception boundary. Some
         pre-validation steps apply partial operations to the message (e.g.
         [Mina_block.transactions] ends in [Or_error.ok_exn] on an unparseable
         staged-ledger diff). The timestamp check below handles out-of-range
         timestamps; this outer boundary turns any other pre-validation
         exception into a rejection of the message. *)
      let handle () =
        let%bind () = on_push () in
        Mina_metrics.(Counter.inc_one Network.gossip_messages_received) ;
        let processing_start_time =
          Block_time.(now time_controller |> to_time_exn)
        in
        let sender, header, txs_opt =
          match b_or_h with
          | `Block { Envelope.Incoming.data = block; sender; _ } ->
              let transactions =
                Mina_block.Stable.Latest.transactions ~constraint_constants
                  block
              in
              (sender, Mina_block.Stable.Latest.header block, Some transactions)
          | `Header { Envelope.Incoming.data = header; sender; _ } ->
              (sender, header, None)
        in
        let state_hash =
          (Mina_block.Header.protocol_state header |> Protocol_state.hashes)
            .state_hash
        in
        Internal_tracing.Context_call.with_call_id ~tag:"block_received"
        @@ fun () ->
        Internal_tracing.with_state_hash state_hash
        @@ fun () ->
        (* Check the block timestamp before it enters the pipeline.  Block_time
           is uint64 but to_time_exn converts through int64; any value >= 2^63
           wraps negative and raises.  Check it up front and reject rather than
           let the conversion raise downstream. *)
        let block_timestamp_valid =
          match
            Block_time.to_time_exn
              ( Mina_block.Header.protocol_state header
              |> Protocol_state.blockchain_state |> Blockchain_state.timestamp
              )
          with
          | (_ : Core.Time.t) ->
              true
          | exception _ ->
              false
        in
        if not block_timestamp_valid then (
          [%log warn]
            "Rejecting block $state_hash: timestamp out of representable range"
            ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ] ;
          Mina_net2.Validation_callback.fire_if_not_already_fired cb `Reject ;
          Deferred.unit )
        else
          let open Mina_transaction in
          let txs_meta =
            Option.value_map ~default:[]
              ~f:(fun txs ->
                [ ( "transactions"
                  , `List
                      (List.map ~f:Transaction.yojson_summary_with_status txs)
                  )
                ] )
              txs_opt
          in
          [%log internal] "@block_metadata"
            ~metadata:
              ( ( "blockchain_length"
                , Mina_numbers.Length.to_yojson
                    (Mina_block.Header.blockchain_length header) )
              :: txs_meta ) ;
          [%log internal] "External_block_received" ;
          don't_wait_for
            ( match%map Mina_net2.Validation_callback.await cb with
            | Some `Accept ->
                let processing_time_span =
                  Time.diff
                    Block_time.(now time_controller |> to_time_exn)
                    processing_start_time
                in
                let module Validation_acceptance_time =
                  Mina_metrics.Block_latency.Validation_acceptance_time
                in
                Validation_acceptance_time.update processing_time_span
            | Some _ ->
                ()
            | None ->
                [%log error] "Validation timed out on block $state_hash"
                  ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ]
            ) ;
          Perf_histograms.add_span ~name:"external_transition_latency"
            (Core.Time.abs_diff
               Block_time.(now time_controller |> to_time_exn)
               ( Mina_block.Header.protocol_state header
               |> Protocol_state.blockchain_state |> Blockchain_state.timestamp
               |> Block_time.to_time_exn ) ) ;
          Mina_metrics.(Gauge.inc_one Network.new_state_received) ;
          ( if log_gossip_heard then
            let metadata =
              match b_or_h with
              | `Block { Envelope.Incoming.data = block; _ } ->
                  [ ( "block"
                    , Mina_block.to_logging_yojson
                      @@ Mina_block.Stable.Latest.header block )
                  ]
              | `Header { Envelope.Incoming.data = header; _ } ->
                  [ ("header", Mina_block.Header.to_yojson header) ]
            in
            [%str_log info] ~metadata (Block_received { state_hash; sender }) ) ;
          Mina_net2.Validation_callback.set_message_type cb `Block ;
          Mina_metrics.(Counter.inc_one Network.Block.received) ;
          let%bind () =
            match
              Network_pool.Rate_limiter.add rate_limiter sender
                ~now:(Time.now ()) ~score:1
            with
            | `Capacity_exceeded ->
                Internal_tracing.with_state_hash state_hash
                @@ fun () ->
                [%log internal] "Failure"
                  ~metadata:[ ("reason", `String "Capacity_exceeded") ] ;
                [%log warn]
                  "$sender has sent many blocks. This is very unusual."
                  ~metadata:[ ("sender", Envelope.Sender.to_yojson sender) ] ;
                Mina_net2.Validation_callback.fire_if_not_already_fired cb
                  `Reject ;
                Deferred.unit
            | `Within_capacity ->
                Writer.write writer (b_or_h, `Time_received tm, `Valid_cb cb)
          in
          let exists_well_formedness_errors =
            match txs_opt with
            | None ->
                (* It's a header *)
                (* TODO make sure this check is executed at a later point when body is received *)
                false
            | Some transactions ->
                List.exists transactions ~f:(fun txn ->
                    match
                      Mina_transaction.Transaction.check_well_formedness
                        ~genesis_constants txn.data
                    with
                    | Ok () ->
                        false
                    | Error errs ->
                        [%log warn]
                          "Rejecting block due to one or more errors in a \
                           transaction"
                          ~metadata:
                            [ ( "errors"
                              , `List
                                  (List.map errs
                                     ~f:
                                       User_command.Well_formedness_error
                                       .to_yojson ) )
                            ] ;
                        true )
          in
          if exists_well_formedness_errors then
            Mina_net2.Validation_callback.fire_if_not_already_fired cb `Reject ;
          let lift_consensus_time =
            Fn.compose Unsigned.UInt32.to_int
              Consensus.Data.Consensus_time.to_uint32
          in
          let tn_production_consensus_time =
            Consensus.Data.Consensus_state.consensus_time
            @@ Protocol_state.consensus_state
            @@ Mina_block.Header.protocol_state header
          in
          let tn_production_slot =
            lift_consensus_time tn_production_consensus_time
          in
          let tn_production_time =
            Consensus.Data.Consensus_time.to_time ~constants:consensus_constants
              tn_production_consensus_time
          in
          let tm_slot =
            lift_consensus_time
              (Consensus.Data.Consensus_time.of_time_exn
                 ~constants:consensus_constants tm )
          in
          let module Gossip_slots = Mina_metrics.Block_latency.Gossip_slots in
          Gossip_slots.update (Float.of_int (tm_slot - tn_production_slot)) ;
          let module Gossip_time = Mina_metrics.Block_latency.Gossip_time in
          Gossip_time.update
            Block_time.(Span.to_time_span @@ diff tm tn_production_time) ;
          Deferred.unit
      in
      match%map Monitor.try_with ~here:[%here] ~run:`Now ~rest:`Log handle with
      | Ok () ->
          ()
      | Error exn ->
          [%log error]
            "Rejecting gossiped block: uncaught exception during \
             pre-validation handling: $error"
            ~metadata:[ ("error", `String (Exn.to_string exn)) ] ;
          Mina_net2.Validation_callback.fire_if_not_already_fired cb `Reject )

let log_rate_limiter_occasionally rl ~logger ~label =
  let t = Time.Span.of_min 1. in
  every t (fun () ->
      [%log debug]
        ~metadata:[ ("rate_limiter", Network_pool.Rate_limiter.summary rl) ]
        !"%s $rate_limiter" label )

let create
    { logger
    ; slot_duration_ms
    ; on_push
    ; time_controller
    ; log_gossip_heard
    ; consensus_constants
    ; genesis_constants
    ; constraint_constants
    } =
  let rate_limiter =
    Network_pool.Rate_limiter.create
      ~capacity:
        ( (* Max of 20 transitions per slot per peer. *)
          20
        , `Per (Block_time.Span.to_time_span slot_duration_ms) )
  in
  log_rate_limiter_occasionally rate_limiter ~logger ~label:"new_block" ;
  let reader, writer = create Synchronous in
  ( reader
  , Sink
      { writer
      ; rate_limiter
      ; logger
      ; on_push
      ; time_controller
      ; log_gossip_heard
      ; consensus_constants
      ; genesis_constants
      ; constraint_constants
      } )

let void = Void

let%test_module "out-of-range block timestamp is handled gracefully" =
  ( module struct
    open Async

    let logger = Logger.null ()

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    let consensus_constants = precomputed_values.consensus_constants

    let time_controller = Block_time.Controller.basic ~logger

    let header_with_timestamp ts =
      let genesis_state =
        Precomputed_values.genesis_state_with_hashes precomputed_values
      in
      let ps = With_hash.data genesis_state in
      let blockchain_state' =
        Blockchain_state.set_timestamp (Protocol_state.blockchain_state ps) ts
      in
      let ps' =
        Protocol_state.create_value
          ~previous_state_hash:(Protocol_state.previous_state_hash ps)
          ~genesis_state_hash:(Protocol_state.genesis_state_hash ps)
          ~blockchain_state:blockchain_state'
          ~consensus_state:(Protocol_state.consensus_state ps)
          ~constants:(Protocol_state.constants ps)
      in
      Mina_block.Header.create ~protocol_state:ps'
        ~protocol_state_proof:(Lazy.force Proof.blockchain_dummy)
        ~delta_block_chain_proof:(Protocol_state.previous_state_hash ps', [])
        ()

    let make_sink () =
      let reader, sink =
        create
          { logger
          ; slot_duration_ms = consensus_constants.slot_duration_ms
          ; on_push = (fun () -> Deferred.unit)
          ; time_controller
          ; log_gossip_heard = false
          ; consensus_constants
          ; genesis_constants = precomputed_values.genesis_constants
          ; constraint_constants = precomputed_values.constraint_constants
          }
      in
      (* Drain the pipe so push doesn't block on the synchronous write. *)
      don't_wait_for
        (Pipe_lib.Strict_pipe.Reader.iter reader ~f:(fun _ -> Deferred.unit)) ;
      sink

    let push_header_with_timestamp ts =
      let sink = make_sink () in
      let header = header_with_timestamp ts in
      let incoming =
        Envelope.Incoming.wrap ~data:header ~sender:Envelope.Sender.Local
      in
      let cb = Mina_net2.Validation_callback.create_without_expiration () in
      push sink
        ( `Header incoming
        , `Time_received (Block_time.now time_controller)
        , `Valid_cb cb )

    let push_must_not_crash ts =
      Thread_safe.block_on_async_exn (fun () -> push_header_with_timestamp ts)

    let%test_unit "gossip block with timestamp = UInt64.max_int must not crash \
                   the daemon" =
      push_must_not_crash (Block_time.of_uint64 Unsigned.UInt64.max_int)

    let%test_unit "gossip block with timestamp = 2^63 is handled gracefully" =
      push_must_not_crash
        (Block_time.of_uint64
           (Unsigned.UInt64.of_string "9223372036854775808") )

    let%test_unit "gossip block with timestamp = 2^63 - 1 must not crash the \
                   daemon" =
      push_must_not_crash
        (Block_time.of_uint64
           (Unsigned.UInt64.of_string "9223372036854775807") )
  end )

let%test_module "malformed gossiped block is handled gracefully" =
  ( module struct
    open Async

    let logger = Logger.null ()

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    let consensus_constants = precomputed_values.consensus_constants

    let time_controller = Block_time.Controller.basic ~logger

    (* Coinbase pair (One, One) is rejected by [Pre_diff_info.check_coinbase]
       before any coinbase arithmetic, so [get_transactions] returns
       [Coinbase_error] regardless of ledger state. *)
    let malformed_body () =
      let (sl_diff : Staged_ledger_diff.t) =
        { diff =
            ( { completed_works = []
              ; commands = []
              ; coinbase = Staged_ledger_diff.At_most_two.One None
              ; internal_command_statuses = []
              }
            , Some
                { completed_works = []
                ; commands = []
                ; coinbase = Staged_ledger_diff.At_most_one.One None
                ; internal_command_statuses = []
                } )
        }
      in
      Staged_ledger_diff.Body.create sl_diff

    let malformed_block () =
      let genesis_state =
        Precomputed_values.genesis_state_with_hashes precomputed_values
      in
      let protocol_state = With_hash.data genesis_state in
      let header =
        Mina_block.Header.create ~protocol_state
          ~protocol_state_proof:(Lazy.force Proof.blockchain_dummy)
          ~delta_block_chain_proof:
            (Protocol_state.previous_state_hash protocol_state, [])
          ()
      in
      (* block_sink handles the on-disk-proofs [Stable.Latest.t] form *)
      Mina_block.read_all_proofs_from_disk
        (Mina_block.create ~header ~body:(malformed_body ()))

    let make_sink () =
      let reader, sink =
        create
          { logger
          ; slot_duration_ms = consensus_constants.slot_duration_ms
          ; on_push = (fun () -> Deferred.unit)
          ; time_controller
          ; log_gossip_heard = false
          ; consensus_constants
          ; genesis_constants = precomputed_values.genesis_constants
          ; constraint_constants = precomputed_values.constraint_constants
          }
      in
      (* Drain the pipe so a successful (post-fix) push does not block. *)
      don't_wait_for
        (Pipe_lib.Strict_pipe.Reader.iter reader ~f:(fun _ -> Deferred.unit)) ;
      sink

    let%test_unit "gossip block with unparseable staged-ledger diff is handled \
                   gracefully" =
      Thread_safe.block_on_async_exn (fun () ->
          let sink = make_sink () in
          let incoming =
            Envelope.Incoming.wrap ~data:(malformed_block ())
              ~sender:Envelope.Sender.Local
          in
          let cb = Mina_net2.Validation_callback.create_without_expiration () in
          push sink
            ( `Block incoming
            , `Time_received (Block_time.now time_controller)
            , `Valid_cb cb ) )
  end )
