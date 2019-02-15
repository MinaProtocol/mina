[%%import
"../../config.mlh"]

[%%if
tracing]

open Core
open Async
open Webkit_trace_event
module Scheduler = Async_kernel_scheduler

let buf = Bigstring.create 128

let emit_event = Output.Binary.emit_event ~buf

let timestamp () =
  Time_stamp_counter.now () |> Time_stamp_counter.to_time_ns
  |> Core.Time_ns.to_int63_ns_since_epoch |> Int63.to_int_exn

let current_wr = ref None

let our_pid = Unix.getpid () |> Pid.to_int

let next_tid = ref 1

let tid_names = ref []

let remember_tid name tid = tid_names := (name, tid) :: !tid_names

let new_event (k : event_kind) : event =
  { name= ""
  ; categories= []
  ; phase= k
  ; timestamp= timestamp ()
  ; pid= our_pid
  ; tid= 0 }

let log_thread_existence name tid =
  Option.iter !current_wr ~f:(fun wr ->
      emit_event wr {(new_event New_thread) with name; tid} )

let trace_new_thread (name : string) (tid : int) =
  remember_tid name tid ;
  log_thread_existence name tid

let trace_thread_switch (new_ctx : Execution_context.t) =
  Option.iter !current_wr ~f:(fun wr ->
      emit_event wr {(new_event Thread_switch) with tid= new_ctx.tid} )

let () =
  Async_kernel.Tracing.fns :=
    { trace_thread_switch
    ; trace_new_thread= (fun name ctx -> trace_new_thread name ctx.tid) }

let trace_event (name : string) =
  Option.iter !current_wr ~f:(fun wr ->
      emit_event wr {(new_event Event) with name} )

let trace_task (name : string) (f : unit -> 'a) =
  let new_ctx =
    Execution_context.with_tid
      Scheduler.(t () |> current_execution_context)
      !next_tid
  in
  next_tid := !next_tid + 1 ;
  trace_new_thread name new_ctx.tid ;
  match Scheduler.within_context new_ctx f with
  | Error () ->
      failwith "traced task failed, exception reported to parent monitor"
  | Ok x -> x

let trace_recurring_task (name : string) (f : unit -> 'a) =
  trace_task ("R&" ^ name) (fun () ->
      trace_event "started another" ;
      f () )

let measure (name : string) (f : unit -> 'a) : 'a =
  match !current_wr with
  | Some wr ->
      emit_event wr {(new_event Measure_start) with name} ;
      let res = f () in
      emit_event wr (new_event Measure_end) ;
      res
  | None -> f ()

let forget_tid (f : unit -> 'a) =
  let new_ctx =
    Execution_context.with_tid Scheduler.(t () |> current_execution_context) 0
  in
  let res = Scheduler.within_context new_ctx f |> Result.ok in
  Option.value_exn res

let start_tracing wr =
  current_wr := Some wr ;
  let sch = Scheduler.t () in
  Scheduler.set_on_end_of_cycle sch (fun () ->
      if not sch.cycle_started then
        emit_event wr
          {(new_event Cycle_end) with tid= sch.current_execution_context.tid} ;
      sch.cycle_started <- true ) ;
  emit_event wr (new_event Pid_is) ;
  List.iter !tid_names ~f:(fun (name, tid) -> log_thread_existence name tid) ;
  emit_event wr
    {(new_event Thread_switch) with tid= sch.current_execution_context.tid}

let stop_tracing () =
  let sch = Scheduler.t () in
  Scheduler.set_on_end_of_cycle sch Fn.id ;
  Option.iter !current_wr ~f:(fun wr ->
      emit_event wr
        {(new_event Trace_end) with tid= sch.current_execution_context.tid} ) ;
  current_wr := None

[%%else]

let[@inline] measure _ f = f ()

let[@inline] trace_event _ = ()

let[@inline] trace_recurring_task _ f = f ()

let[@inline] trace_task _ f = f ()

let[@inline] start_tracing _ = ()

let[@inline] stop_tracing () = ()

let[@inline] forget_tid f = f ()

[%%endif]
