open Pipe_lib
open Async_kernel
open Network_peer
open Core_kernel

module type BC_ext = sig
  include Intf.Broadcast_callback

  val is_expired : t -> bool

  val error : Error.t -> t -> unit Deferred.t
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
        BC.drop Diff.empty (Diff.reject_overloaded_diff diff) cb

  let verify_impl ~logger ~trace_label resource_pool rl env cb :
      Diff.verified Envelope.Incoming.t option Deferred.t =
    let handle_diffs_thread_label = "handle_" ^ trace_label ^ "_diffs" in

    let verify_diffs_thread_label = "verify_" ^ trace_label ^ "_diffs" in
    O1trace.sync_thread handle_diffs_thread_label (fun () ->
        if BC.is_expired cb then Deferred.return None
        else
          let summary = `String (Diff.summary @@ Envelope.Incoming.data env) in
          [%log' debug logger] "Verifying $diff from $sender"
            ~metadata:
              [ ("diff", summary)
              ; ("sender", Envelope.Sender.to_yojson env.sender)
              ] ;
          match
            Rate_limiter.add rl env.sender ~now:(Time.now ())
              ~score:(Diff.score env.data)
          with
          | `Capacity_exceeded ->
              [%log' debug logger]
                ~metadata:
                  [ ("sender", Envelope.Sender.to_yojson env.sender)
                  ; ("diff", summary)
                  ]
                "exceeded capacity from $sender" ;
              BC.error (Error.of_string "exceeded capacity") cb
              >>| fun _ -> None
          | `Within_capacity ->
              O1trace.thread verify_diffs_thread_label (fun () ->
                  match%bind Diff.verify resource_pool env with
                  | Error err ->
                      [%log' debug logger]
                        "Refusing to rebroadcast $diff. Verification error: \
                         $error"
                        ~metadata:
                          [ ("diff", summary)
                          ; ("error", Error_json.error_to_yojson err)
                          ] ;
                      (*reject incoming messages*)
                      BC.error err cb >>| fun _ -> None
                  | Ok verified_diff ->
                      [%log' debug logger] "Verified diff: $verified_diff"
                        ~metadata:
                          [ ( "verified_diff"
                            , Diff.verified_to_yojson
                              @@ Envelope.Incoming.data verified_diff )
                          ; ( "sender"
                            , Envelope.Sender.to_yojson
                              @@ Envelope.Incoming.sender verified_diff )
                          ] ;
                      Deferred.return (Some verified_diff)))

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
        } ->
        O1trace.sync_thread (sprintf "handle_%s_gossip" trace_label)
        @@ fun () ->
        let%bind () = on_push () in
        let env' = Msg.convert msg in
        let cb' = Msg.convert_callback cb in
        ( match cb' with
        | BC.External cb'' ->
            Diff.update_metrics env' cb''
              (Option.some_if log_gossip_heard logger)
        | _ ->
            () ) ;
        if Throttle.num_jobs_waiting_to_start throttle > max_waiting_jobs then
          [%log warn] "Ignoring push to %s: throttle is full" trace_label
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
                       (Strict_pipe.Writer.write w m'))) ;
        Deferred.unit
    | Void ->
        Deferred.unit

  let create ?(on_push = Fn.const Deferred.unit) ?(log_gossip_heard = false)
      ~wrap ~unwrap ~trace_label ~logger pool =
    let r, writer =
      Strict_pipe.create ~name:"verified network pool diffs"
        (Buffered
           ( `Capacity verified_pipe_capacity
           , `Overflow (Call (on_overflow ~unwrap logger)) ))
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
          * ((BC.resource_pool_diff * BC.rejected_diff) Or_error.t -> unit) =
  Base (Diff) (BC)
    (struct
      type raw_msg = BC.resource_pool_diff

      type raw_callback =
        (BC.resource_pool_diff * BC.rejected_diff) Or_error.t -> unit

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
