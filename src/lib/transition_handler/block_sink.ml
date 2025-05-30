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
      } ->
      O1trace.sync_thread "handle_block_gossip"
      @@ fun () ->
      let%bind () = on_push () in
      Mina_metrics.(Counter.inc_one Network.gossip_messages_received) ;
      let processing_start_time =
        Block_time.(now time_controller |> to_time_exn)
      in
      let sender, header, txs_opt =
        match b_or_h with
        | `Block { Envelope.Incoming.data = block; sender; _ } ->
            let transactions =
              Mina_block.Stable.Latest.transactions ~constraint_constants block
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
      let open Mina_transaction in
      let txs_meta =
        Option.value_map ~default:[]
          ~f:(fun txs ->
            [ ( "transactions"
              , `List (List.map ~f:Transaction.yojson_summary_with_status txs)
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
              ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ] ) ;
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
          Network_pool.Rate_limiter.add rate_limiter sender ~now:(Time.now ())
            ~score:1
        with
        | `Capacity_exceeded ->
            Internal_tracing.with_state_hash state_hash
            @@ fun () ->
            [%log internal] "Failure"
              ~metadata:[ ("reason", `String "Capacity_exceeded") ] ;
            [%log warn] "$sender has sent many blocks. This is very unusual."
              ~metadata:[ ("sender", Envelope.Sender.to_yojson sender) ] ;
            Mina_net2.Validation_callback.fire_if_not_already_fired cb `Reject ;
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
                                 ~f:User_command.Well_formedness_error.to_yojson )
                          )
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
