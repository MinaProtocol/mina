open Core
open Async
open Webkit_trace_event
module Scheduler = Async_kernel_scheduler

let buf = Bigstring.create 512

let emit_event w event =
  try Webkit_trace_event_binary_output.emit_event ~buf w event
  with exn ->
    Writer.writef w "failed to write o1trace event: %s\n" (Exn.to_string exn)

let timestamp () =
  Time_stamp_counter.now () |> Time_stamp_counter.to_int63 |> Int63.to_int_exn

let current_wr = ref None

let our_pid = Unix.getpid () |> Pid.to_int

let new_event (k : event_kind) : event =
  { name = ""
  ; categories = []
  ; phase = k
  ; timestamp = timestamp ()
  ; pid = our_pid
  ; tid = 0
  }

let log_thread_existence name tid =
  Option.iter !current_wr ~f:(fun wr ->
      emit_event wr { (new_event New_thread) with name; tid })

module Implementation = struct
  module Hooks = struct
    let trace_thread_switch _ (new_ctx : Execution_context.t) =
      Option.iter !current_wr ~f:(fun wr ->
          emit_event wr { (new_event Thread_switch) with tid = new_ctx.tid })
  end

  let trace_event (name : string) =
    Option.iter !current_wr ~f:(fun wr ->
        emit_event wr { (new_event Event) with name })

  let trace (name : string) (f : unit -> 'a) =
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

  let trace_task (name : string) (f : unit -> unit Deferred.t) =
    don't_wait_for (trace name f)

  let recurring_prefix x = "R&" ^ x

  let trace_recurring name f = trace (recurring_prefix name) f

  let trace_recurring_task (name : string) (f : unit -> unit Deferred.t) =
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
end

let start_tracing wr =
  current_wr := Some wr ;
  let sch = Scheduler.t () in
  Scheduler.Expert.set_on_end_of_cycle (fun () ->
      if not sch.cycle_started then
        emit_event wr
          { (new_event Cycle_end) with tid = sch.current_execution_context.tid } ;
      sch.cycle_started <- true) ;
  emit_event wr (new_event Pid_is) ;
  O1trace.Thread_registry.iter_threads ~f:log_thread_existence ;
  emit_event wr
    { (new_event Thread_switch) with tid = sch.current_execution_context.tid } ;
  O1trace.set_implementation (module Implementation)

let stop_tracing () =
  let sch = Scheduler.t () in
  Scheduler.Expert.set_on_end_of_cycle Fn.id ;
  Option.iter !current_wr ~f:(fun wr ->
      emit_event wr
        { (new_event Trace_end) with tid = sch.current_execution_context.tid }) ;
  current_wr := None ;
  O1trace.set_implementation (module O1trace.No_trace)
