open Core
open Async
open Webkit_trace_event
module Scheduler = Async_kernel_scheduler

let current_wr = ref None

let emit_event =
  let buf = Bigstring.create 512 in
  fun event ->
    Option.iter !current_wr ~f:(fun wr ->
        try Webkit_trace_event_binary_output.emit_event ~buf wr event
        with exn ->
          Writer.writef wr "failed to write o1trace event: %s\n"
            (Exn.to_string exn) )

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

(* This will track ids per thread. If we need to track ids per fiber,
   we will need to feed the fiber id into the plugin hooks. *)
let id_of_thread =
  let ids = String.Table.create () in
  let next_id = ref 0 in
  let alloc_id () =
    let id = !next_id in
    incr next_id ; id
  in
  fun thread_name -> Hashtbl.find_or_add ids thread_name ~default:alloc_id

let new_thread_event ?(include_name = false) thread_name event_kind =
  { (new_event event_kind) with
    tid = id_of_thread thread_name
  ; name = (if include_name then thread_name else "")
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

  let on_job_enter (fiber : O1trace.Thread.Fiber.t) =
    emit_event
      (new_thread_event (O1trace.Thread.name fiber.thread) Thread_switch)

  let on_job_exit _fiber _time_elapsed = ()

  (*
  let on_cycle_end () =
    let sch = Scheduler.t () in
    emit_event (new_thread_event thread_name Cycle_end) ;
  *)
end

let start_tracing wr =
  if Option.is_some !current_wr then (* log an error, do nothing *)
    ()
  else (
    current_wr := Some wr ;
    emit_event (new_event Pid_is) ;
    O1trace.Thread.iter_threads ~f:(fun thread ->
        emit_event
          (new_thread_event ~include_name:true
             (O1trace.Thread.name thread)
             New_thread ) ) ;
    O1trace.Plugins.enable_plugin (module T) )

let stop_tracing () =
  if Option.is_none !current_wr then (* log an error, do nothing *)
    ()
  else (
    emit_event (new_event Trace_end) ;
    current_wr := None ;
    O1trace.Plugins.disable_plugin (module T) )
