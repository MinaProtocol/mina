open Network_peer
open Mina_transition
open Core_kernel
open Async
open Pipe_lib.Strict_pipe

type stream_msg =
  External_transition.t Envelope.Incoming.t
  * Block_time.t
  * Mina_net2.Validation_callback.t

type t =
  | Sink of
      { writer : (stream_msg, synchronous, unit Deferred.t) Writer.t
      ; rate_limiter : Rate_limiter.t
      ; logger : Logger.t
      }
  | Void

let push sink (e, tm, cb) =
  match sink with
  | Void ->
      Deferred.unit
  | Sink { writer; rate_limiter; logger; _ } -> (
      let sender = Envelope.Incoming.sender e in
      match
        Rate_limiter.add rate_limiter sender ~now:(Time.now ()) ~score:1
      with
      | `Capacity_exceeded ->
          [%log' warn logger]
            "$sender has sent many blocks. This is very unusual."
            ~metadata:[ ("sender", Envelope.Sender.to_yojson sender) ] ;
          Mina_net2.Validation_callback.fire_if_not_already_fired cb `Reject ;
          Deferred.unit
      | `Within_capacity ->
          Writer.write writer (e, tm, cb) )

let log_rate_limiter_occasionally rl ~logger ~label =
  let t = Time.Span.of_min 1. in
  every t (fun () ->
      [%log' debug logger]
        ~metadata:[ ("rate_limiter", Rate_limiter.summary rl) ]
        !"%s $rate_limiter" label)

let create ~logger ~slot_duration_ms =
  let rate_limiter =
    Rate_limiter.create
      ~capacity:
        ( (* Max of 20 transitions per slot per peer. *)
          20
        , `Per (Block_time.Span.to_time_span slot_duration_ms) )
  in
  log_rate_limiter_occasionally rate_limiter ~logger ~label:"new_block" ;
  let reader, writer = create Synchronous in
  (reader, Sink { writer; rate_limiter; logger })

let void = Void
