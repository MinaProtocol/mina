open Core
open Async
open Webkit_trace_event
module Scheduler = Async_kernel_scheduler

let current_wr = ref None

let emit_event' =
  let buf = Bigstring.create 512 in
  fun wr event ->
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

let new_thread_event ?(include_name = false) thread_key tid event_kind =
  { (new_event event_kind) with
    tid
  ; name = (if include_name then String.concat ~sep:"/" thread_key else "")
  }

(*

let trace name f =
  let new_ctx =
    O1trace.Thread_registry.assign_tid name
      (Scheduler.current_execution_context ())
  in
  log_thread_existence name new_ctx.tid ;
  match Scheduler.within_context new_ctx f with
  | Error () ->
      failwithf
        "traced task `%s` failed, exception reported to parent monitor" name
        ()
  | Ok x ->
      x

let trace_event (name : string) =
  Option.iter !current_wr ~f:(fun wr ->
      emit_event wr { (new_event Event) with name })

let recurring_prefix x = "R&" ^ x

let _trace_recurring name f = trace (recurring_prefix name) f

let _trace_recurring_task (name : string) (f : unit -> unit Deferred.t) =
  trace_task (recurring_prefix name) (fun () ->
      trace_event "started another" ;
      f ())

let measure (name : string) (f : unit -> 'a) : 'a =
  match !current_wr with
  | Some wr ->
      emit_event wr { (new_event Measure_start) with name } ;
      let res = f () in
      emit_event wr (new_event Measure_end) ;
      res
  | None ->
      f ()
*)

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
      emit_event (new_thread_event fiber.key fiber.id Thread_switch) )

  let on_job_exit _fiber _time_elapsed = ()

  let on_new_fiber (fiber : O1trace.Thread.Fiber.t) =
    emit_event
      (new_thread_event ~include_name:true fiber.key fiber.id New_thread)

  let on_cycle_end () = emit_event (new_event Cycle_end)
end

let start_tracing wr =
  if Option.is_some !current_wr then (* log an error, do nothing *)
    ()
  else (
    current_wr := Some wr ;
    (* FIXME: these handlers cannot be removed without further
       changes to async_kernel. Instead, we will leak a ref and
       accumulate a bunch of NOOPs every time we call [stop_tracing] *)
    emit_event (new_event Pid_is) ;
    O1trace.Thread.iter_fibers ~f:(fun fiber ->
        emit_event
          (new_thread_event ~include_name:true fiber.key fiber.id New_thread) ) ;
    O1trace.Plugins.enable_plugin (module T) )

let stop_tracing () =
  if Option.is_none !current_wr then (* log an error, do nothing *)
    ()
  else (
    emit_event (new_event Trace_end) ;
    current_wr := None ;
    O1trace.Plugins.disable_plugin (module T) )
