open Core_kernel
open Async_kernel

type t =
  { mutable timeout : unit Block_time.Timeout.t option
  ; mutable unpaused : unit Ivar.t
  ; time_controller : Block_time.Controller.t
  }

let create time_controller =
  { time_controller; unpaused = Ivar.create_full (); timeout = None }

let pause t = t.unpaused <- Ivar.create ()

let unpause t = Ivar.fill t.unpaused ()

let cancel t =
  match t.timeout with
  | Some timeout ->
      Block_time.Timeout.cancel t.time_controller timeout () ;
      t.timeout <- None
  | None ->
      ()

let schedule t time ~f =
  let remaining_time =
    Option.map t.timeout ~f:Block_time.Timeout.remaining_time
  in
  cancel t ;
  let span_till_time =
    Block_time.diff time (Block_time.now t.time_controller)
  in
  let wait_span =
    match remaining_time with
    | Some remaining
      when Block_time.Span.(remaining > Block_time.Span.of_ms Int64.zero) ->
        let min a b = if Block_time.Span.(a < b) then a else b in
        min remaining span_till_time
    | None | Some _ ->
        span_till_time
  in
  let timeout =
    Block_time.Timeout.create t.time_controller wait_span ~f:(fun _ ->
        don't_wait_for
          (let%map () = Ivar.read t.unpaused in
           t.timeout <- None ;
           f () ) )
  in
  t.timeout <- Some timeout
