open Pipe_lib
open Async_kernel
open Network_peer
open Core_kernel

module type BC_ext = sig
  include Intf.Broadcast_callback

  val is_expired : t -> bool

  val error : Error.t -> t -> unit
end

module type Pool_sink = sig
  include Mina_net2.Sink.S_with_void

  type unwrapped_t

  type pool

  val create :
       ?on_push:(unit -> unit Deferred.t)
    -> ?log_gossip_heard:bool
    -> wrap:(unwrapped_t -> 'wrapped_t)
    -> unwrap:('wrapped_t -> unwrapped_t)
    -> trace_label:string
    -> logger:Logger.t
    -> pool
    -> block_window_duration:Time.Span.t
    -> 'wrapped_t Strict_pipe.Reader.t * t * Rate_limiter.t
end

module Base
    (Diff : Intf.Resource_pool_diff_intf)
    (BC : BC_ext
            with type resource_pool_diff = Diff.t
             and type rejected_diff = Diff.rejected)
    (Msg : sig
      type raw_msg

      type raw_callback

      val convert_callback : raw_callback -> BC.t

      val convert : raw_msg -> Diff.t Envelope.Incoming.t
    end) :
  Pool_sink
    with type pool := Diff.pool
     and type unwrapped_t = Diff.verified Envelope.Incoming.t * BC.t
     and type msg := Msg.raw_msg * Msg.raw_callback = struct
  type unwrapped_t = Diff.verified Envelope.Incoming.t * BC.t

  (* TODO consider moving these constants elsewhere *)
  let max_waiting_jobs = 2048

  let max_concurrent_jobs = 1024

  let verified_pipe_capacity = 1024

  type t =
    | Sink :
        { writer :
            ( 'w
            , Strict_pipe.call Strict_pipe.buffered
            , unit Deferred.t option )
            Strict_pipe.Writer.t
        ; logger : Logger.t
        ; rate_limiter : Rate_limiter.t
        ; pool : Diff.pool
        ; wrap : unwrapped_t -> 'w
        ; trace_label : string
        ; throttle : unit Throttle.t
        ; on_push : unit -> unit Deferred.t
        ; log_gossip_heard : bool
        ; block_window_duration : Time.Span.t
        }
        -> t
    | Void

  let on_overflow ~unwrap logger m =
    match unwrap m with
    | env, cb ->
        Mina_metrics.(
          Counter.inc_one Pipe.Drop_on_overflow.verified_network_pool_diffs) ;
        let diff = Envelope.Incoming.data env in
        [%log' warn logger] "Dropping verified diff $diff due to pipe overflow"
          ~metadata:[ ("diff", Diff.verified_to_yojson diff) ] ;
        BC.drop Diff.empty (Diff.reject_overloaded_diff diff) cb ;
        Deferred.unit

  let verify_impl ~logger ~trace_label resource_pool rl env cb :
      Diff.verified Envelope.Incoming.t option Deferred.t =
    let handle_diffs_thread_label = "handle_" ^ trace_label ^ "_diffs" in

    let verify_diffs_thread_label = "verify_" ^ trace_label ^ "_diffs" in
    O1trace.sync_thread handle_diffs_thread_label (fun () ->
        if BC.is_expired cb then Deferred.return None
        else
          let summary = `String (Diff.summary @@ Envelope.Incoming.data env) in
          let metadata =
            [ ("diff", summary)
            ; ("sender", Envelope.Sender.to_yojson env.sender)
            ]
          in
          [%log debug] "Verifying $diff from $sender" ~metadata ;
          match
            Rate_limiter.add rl env.sender ~now:(Time.now ())
              ~score:(Diff.score env.data)
          with
          | `Capacity_exceeded ->
              [%log debug] ~metadata "exceeded capacity from $sender" ;
              BC.error (Error.of_string "exceeded capacity") cb ;
              Diff.log_internal ~logger "rejected" ~reason:"rate_limit" env ;
              Deferred.return None
          | `Within_capacity ->
              O1trace.thread verify_diffs_thread_label (fun () ->
                  match%map Diff.verify resource_pool env with
                  | Error ver_err ->
                      Diff.log_internal ~logger "rejected"
                        ~reason:
                          (Intf.Verification_error.to_short_string ver_err)
                        env ;
                      let err = Intf.Verification_error.to_error ver_err in
                      [%log debug]
                        "Refusing to rebroadcast $diff. Verification error: \
                         $error"
                        ~metadata:
                          (("error", Error_json.error_to_yojson err) :: metadata) ;
                      (*reject incoming messages*)
                      BC.error err cb ;
                      None
                  | Ok verified_diff ->
                      [%log debug] "Verified diff: $diff" ~metadata ;
                      Some verified_diff ) )

  let push t (msg, cb) =
    match t with
    | Sink
        { writer = w
        ; logger
        ; rate_limiter = rl
        ; pool
        ; wrap
        ; trace_label
        ; throttle
        ; on_push
        ; log_gossip_heard
        ; block_window_duration
        } ->
        O1trace.sync_thread (sprintf "handle_%s_gossip" trace_label)
        @@ fun () ->
        let%bind () = on_push () in
        let env' = Msg.convert msg in
        let cb' = Msg.convert_callback cb in
        Diff.log_internal ~logger "received" env' ;
        ( match cb' with
        | BC.External cb'' ->
            Diff.update_metrics env' cb'' ~log_gossip_heard ~logger ;
            don't_wait_for
              ( match%map
                  Mina_net2.Validation_callback.await ~block_window_duration
                    cb''
                with
              | None ->
                  let diff = Envelope.Incoming.data env' in
                  [%log error]
                    !"Validation timed out on %s"
                    Diff.label
                    ~metadata:[ ("diff", `String (Diff.summary diff)) ]
              | Some _ ->
                  () )
        | _ ->
            () ) ;
        if Throttle.num_jobs_waiting_to_start throttle > max_waiting_jobs then (
          Diff.log_internal ~logger "rejected" ~reason:"throttle_full" env' ;
          [%log warn] "Ignoring push to %s: throttle is full" trace_label )
        else
          don't_wait_for
            (Throttle.enqueue throttle (fun () ->
                 match%bind
                   verify_impl ~logger ~trace_label pool rl env' cb'
                 with
                 | None ->
                     [%log debug] "Received unverified gossip on %s" trace_label
                       ~metadata:
                         [ ("sender", Envelope.Sender.to_yojson env'.sender)
                         ; ( "received_at"
                           , `String (Time.to_string env'.received_at) )
                         ] ;
                     Deferred.unit
                 | Some verified_env ->
                     let m' = wrap (verified_env, cb') in
                     Option.value ~default:Deferred.unit
                       (Strict_pipe.Writer.write w m') ) ) ;
        Deferred.unit
    | Void ->
        Deferred.unit

  let create ?(on_push = Fn.const Deferred.unit) ?(log_gossip_heard = false)
      ~wrap ~unwrap ~trace_label ~logger pool ~block_window_duration =
    let r, writer =
      Strict_pipe.create ~name:"verified network pool diffs"
        (Buffered
           ( `Capacity verified_pipe_capacity
           , `Overflow (Call (on_overflow ~unwrap logger)) ) )
    in

    let rate_limiter =
      Rate_limiter.create
        ~capacity:(Diff.max_per_15_seconds, `Per (Time.Span.of_sec 15.0))
    in
    let throttle =
      Throttle.create ~continue_on_error:true ~max_concurrent_jobs
    in
    ( r
    , Sink
        { writer
        ; logger
        ; rate_limiter
        ; pool
        ; wrap
        ; trace_label
        ; throttle
        ; on_push
        ; log_gossip_heard
        ; block_window_duration
        }
    , rate_limiter )

  let void = Void
end

module Local_sink
    (Diff : Intf.Resource_pool_diff_intf)
    (BC : BC_ext
            with type resource_pool_diff = Diff.t
             and type rejected_diff = Diff.rejected) :
  Pool_sink
    with type pool := Diff.pool
     and type unwrapped_t = Diff.verified Envelope.Incoming.t * BC.t
     and type msg :=
      BC.resource_pool_diff
      * (   ( [ `Broadcasted | `Not_broadcasted ]
            * BC.resource_pool_diff
            * BC.rejected_diff )
            Or_error.t
         -> unit ) =
  Base (Diff) (BC)
    (struct
      type raw_msg = BC.resource_pool_diff

      type raw_callback =
           ( [ `Broadcasted | `Not_broadcasted ]
           * BC.resource_pool_diff
           * BC.rejected_diff )
           Or_error.t
        -> unit

      let convert_callback cb = BC.Local cb

      let convert m = Envelope.Incoming.local m
    end)

module Remote_sink
    (Diff : Intf.Resource_pool_diff_intf)
    (BC : BC_ext
            with type resource_pool_diff = Diff.t
             and type rejected_diff = Diff.rejected) :
  Pool_sink
    with type pool := Diff.pool
     and type unwrapped_t = Diff.verified Envelope.Incoming.t * BC.t
     and type msg :=
      BC.resource_pool_diff Envelope.Incoming.t
      * Mina_net2.Validation_callback.t =
  Base (Diff) (BC)
    (struct
      type raw_msg = BC.resource_pool_diff Envelope.Incoming.t

      type raw_callback = Mina_net2.Validation_callback.t

      let convert_callback cb = BC.External cb

      let convert m = m
    end)
