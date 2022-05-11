open Network_peer
open Core_kernel
open Async
open Pipe_lib.Strict_pipe
open Mina_base
open Mina_state

type stream_msg =
  [ `Transition of Mina_block.t Envelope.Incoming.t ]
  * [ `Time_received of Block_time.t ]
  * [ `Valid_cb of Mina_net2.Validation_callback.t ]

type block_sink_config =
  { logger : Logger.t
  ; slot_duration_ms : Block_time.Span.t
  ; on_push : unit -> unit Deferred.t
  ; time_controller : Block_time.Controller.t
  ; log_gossip_heard : bool
  ; consensus_constants : Consensus.Constants.t
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
      }
  | Void

type Structured_log_events.t +=
  | Block_received of { state_hash : State_hash.t; sender : Envelope.Sender.t }
  [@@deriving register_event { msg = "Received a block from $sender" }]

let push sink (`Transition e, `Time_received tm, `Valid_cb cb) =
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
      } ->
      O1trace.sync_thread "handle_block_gossip"
      @@ fun () ->
      let%bind () = on_push () in
      Mina_metrics.(Counter.inc_one Network.gossip_messages_received) ;
      let state = Envelope.Incoming.data e in
      let processing_start_time = Block_time.(now time_controller |> to_time) in
      don't_wait_for
        ( match%map Mina_net2.Validation_callback.await cb with
        | Some `Accept ->
            let processing_time_span =
              Time.diff
                Block_time.(now time_controller |> to_time)
                processing_start_time
            in
            Mina_metrics.Block_latency.(
              Validation_acceptance_time.update processing_time_span)
        | _ ->
            () ) ;
      Perf_histograms.add_span ~name:"external_transition_latency"
        (Core.Time.abs_diff
           Block_time.(now time_controller |> to_time)
           Mina_block.(
             header state |> Header.protocol_state
             |> Protocol_state.blockchain_state |> Blockchain_state.timestamp
             |> Block_time.to_time)) ;
      Mina_metrics.(Gauge.inc_one Network.new_state_received) ;
      if log_gossip_heard then
        [%str_log info]
          ~metadata:[ ("external_transition", Mina_block.to_yojson state) ]
          (Block_received
             { state_hash =
                 Mina_block.(
                   header state |> Header.protocol_state
                   |> Protocol_state.hashes)
                   .state_hash
             ; sender = Envelope.Incoming.sender e
             }) ;
      Mina_net2.Validation_callback.set_message_type cb `Block ;
      Mina_metrics.(Counter.inc_one Network.Block.received) ;
      let sender = Envelope.Incoming.sender e in
      let%bind () =
        match
          Network_pool.Rate_limiter.add rate_limiter sender ~now:(Time.now ())
            ~score:1
        with
        | `Capacity_exceeded ->
            [%log' warn logger]
              "$sender has sent many blocks. This is very unusual."
              ~metadata:[ ("sender", Envelope.Sender.to_yojson sender) ] ;
            Mina_net2.Validation_callback.fire_if_not_already_fired cb `Reject ;
            Deferred.unit
        | `Within_capacity ->
            Writer.write writer (`Transition e, `Time_received tm, `Valid_cb cb)
      in
      let lift_consensus_time =
        Fn.compose Unsigned.UInt32.to_int
          Consensus.Data.Consensus_time.to_uint32
      in
      let tn_production_consensus_time =
        Consensus.Data.Consensus_state.consensus_time
        @@ Protocol_state.consensus_state @@ Mina_block.Header.protocol_state
        @@ Mina_block.header (Envelope.Incoming.data e)
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
             ~constants:consensus_constants tm)
      in
      Mina_metrics.Block_latency.Gossip_slots.update
        (Float.of_int (tm_slot - tn_production_slot)) ;
      Mina_metrics.Block_latency.Gossip_time.update
        Block_time.(Span.to_time_span @@ diff tm tn_production_time) ;
      Deferred.unit

let log_rate_limiter_occasionally rl ~logger ~label =
  let t = Time.Span.of_min 1. in
  every t (fun () ->
      [%log' debug logger]
        ~metadata:[ ("rate_limiter", Network_pool.Rate_limiter.summary rl) ]
        !"%s $rate_limiter" label)

let create
    { logger
    ; slot_duration_ms
    ; on_push
    ; time_controller
    ; log_gossip_heard
    ; consensus_constants
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
      } )

let void = Void
