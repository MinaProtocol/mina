open Core
open Async
open Webkit_trace_event
module Scheduler = Async_kernel_scheduler

let current_wr = ref None

let emitted_since_cycle_ended = ref false

let emit_event' =
  let buf = Bigstring.create 512 in
  fun wr event ->
    emitted_since_cycle_ended := true ;
    try Webkit_trace_event_binary_output.emit_event ~buf wr event
    with exn ->
      Writer.writef wr "failed to write o1trace event: %s\n" (Exn.to_string exn)

let emit_event event =
  Option.iter !current_wr ~f:(fun wr -> emit_event' wr event)

let timestamp () =
  Time_stamp_counter.now () |> Time_stamp_counter.to_int63 |> Int63.to_int_exn

let our_pid = Unix.getpid () |> Pid.to_int

let new_event (k : event_kind) : event =
  { name = ""
  ; categories = []
  ; phase = k
  ; timestamp = timestamp ()
  ; pid = our_pid
  ; tid = 0
  }

let new_thread_event ?(include_name = "") tid event_kind =
  { (new_event event_kind) with tid; name = include_name }

module T = struct
  include
    O1trace.Plugins.Register_plugin
      (struct
        type state = unit [@@deriving sexp_of]

        let name = "Webkit_event"

        let init_state _ = ()
      end)
      ()

  let most_recent_id = ref 0

  let on_job_enter (fiber : O1trace.Thread.Fiber.t) =
    if fiber.id <> !most_recent_id then (
      most_recent_id := fiber.id ;
      emit_event (new_thread_event fiber.id Thread_switch) )

  let on_job_exit _fiber _time_elapsed = ()

  let on_new_fiber (fiber : O1trace.Thread.Fiber.t) =
    let fullname = String.concat ~sep:"/" (O1trace.Thread.Fiber.key fiber) in
    emit_event (new_thread_event ~include_name:fullname fiber.id New_thread)

  let on_cycle_end () =
    if !emitted_since_cycle_ended then emit_event (new_event Cycle_end) ;
    emitted_since_cycle_ended := false
end

let start_tracing wr =
  if Option.is_some !current_wr then (* log an error, do nothing *)
    ()
  else (
    current_wr := Some wr ;
    emit_event (new_event Pid_is) ;
    O1trace.Thread.iter_fibers ~f:T.on_new_fiber ;
    O1trace.Plugins.enable_plugin (module T) )

let stop_tracing () =
  if Option.is_none !current_wr then (* log an error, do nothing *)
    ()
  else (
    emit_event (new_event Trace_end) ;
    current_wr := None ;
    O1trace.Plugins.disable_plugin (module T) )
