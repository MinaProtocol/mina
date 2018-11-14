[%%import
"../../config.mlh"]

[%%if
tracing]

open Core
open Async
module Scheduler = Async_kernel_scheduler

type event_kind =
  | New_thread
  | Thread_switch
  | Cycle_end
  | Pid_is
  | Event
  | Start
  | End

let buf = Bigstring.create 128

let emitk (k : event_kind) pos =
  let num =
    match k with
    | New_thread -> 0
    | Thread_switch -> 1
    | Cycle_end -> 3
    | Pid_is -> 4
    | Event -> 5
    | Start -> 6
    | End -> 7
  in
  Bigstring.set_uint8 buf ~pos num ;
  pos + 1

let emiti (i : int) pos =
  Bigstring.set_uint64_le buf ~pos i ;
  pos + 8

let emits (s : string) pos =
  let sl = String.length s in
  let pos = emiti sl pos in
  Bigstring.From_string.blit ~src:s ~src_pos:0 ~len:sl ~dst:buf ~dst_pos:pos ;
  pos + sl

let emitt pos =
  let ts = Time_stamp_counter.to_time_ns (Time_stamp_counter.now ()) in
  emiti (Core.Time_ns.to_int63_ns_since_epoch ts |> Int63.to_int_exn) pos

let finish wr final_len = Writer.write_bigstring wr ~pos:0 ~len:final_len buf

let trace_new_thread' wr (name : string) (ctx : Execution_context.t) =
  emitk New_thread 0 |> emitt |> emiti ctx.tid |> emits name |> finish wr

let trace_thread_switch' wr (new_ctx : Execution_context.t) =
  emitk Thread_switch 0 |> emitt |> emiti new_ctx.tid |> finish wr

let tid = ref 1

let trace_event' wr (name : string) =
  emitk Event 0 |> emitt |> emits name |> finish wr

let trace_event_impl = ref (fun _ -> ())

let trace_event name = !trace_event_impl name

let trace_task (name : string) (f : unit -> 'a) =
  let new_ctx =
    Execution_context.with_tid
      (Scheduler.current_execution_context (Scheduler.t ()))
      !tid
  in
  tid := !tid + 1 ;
  !Async_kernel.Tracing.fns.trace_new_thread name new_ctx ;
  match Scheduler.within_context new_ctx f with
  | Error () ->
      failwith "traced task failed, exception reported to parent monitor"
  | Ok x -> x

let trace_recurring_task (name : string) (f : unit -> 'a) =
  trace_task ("R&" ^ name) (fun () ->
      trace_event "started another" ;
      f () )

let measure' wr (name : string) (f : unit -> 'a) : 'a =
  emitk Start 0 |> emitt |> emits name |> finish wr ;
  let res = f () in
  emitk End 0 |> emitt |> finish wr ;
  res

let measure_impl = ref (fun _ f -> f ())

(* the two things we set measure_impl to are fine *)

let measure name (f : unit -> 'a) : 'a =
  (Obj.magic !measure_impl : string -> (unit -> 'a) -> 'a) name f

let start_tracing wr =
  emitk Pid_is 0 |> emiti (Unix.getpid () |> Pid.to_int) |> finish wr ;
  Async_kernel.Tracing.fns :=
    { trace_thread_switch= trace_thread_switch' wr
    ; trace_new_thread= trace_new_thread' wr } ;
  trace_event_impl := trace_event' wr ;
  measure_impl := measure' wr ;
  let sch = Scheduler.t () in
  Scheduler.set_on_end_of_cycle sch (fun () ->
      sch.cycle_started <- true ;
      if sch.current_execution_context.tid <> 0 then
        emitk Cycle_end 0 |> emitt |> finish wr )

[%%else]

let[@inline] measure _ f = f ()

let[@inline] trace_event _ = ()

let[@inline] trace_recurring_task _ f = f ()

let[@inline] trace_task _ f = f ()

let[@inline] start_tracing _ = ()

[%%endif]
