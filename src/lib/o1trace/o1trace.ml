open Core
open Async
include Intf

type thread_timer =
  { mutable elapsed : Time.Span.t; mutable last_start_time : Time.t option }
[@@deriving sexp_of]

let thread_timer : thread_timer Type_equal.Id.t =
  Type_equal.Id.create ~name:"thread_timer" sexp_of_thread_timer

module Thread_registry = struct
  let next_tid = ref 1

  let tid_names = Int.Table.create ()

  let assign_tid name ctx =
    let ctx' = Execution_context.with_tid ctx !next_tid in
    Hashtbl.set tid_names ~key:!next_tid ~data:name ;
    incr next_tid ;
    ctx'

  let get_thread_name tid = Hashtbl.find tid_names tid

  let iter_threads ~f =
    Hashtbl.iteri tid_names ~f:(fun ~key ~data -> f data key)
end

module Thread_timers = struct
  let thread_timers = String.Table.create ()

  let register name =
    match Hashtbl.find thread_timers name with
    | Some timer ->
        timer
    | None ->
        let timer = { elapsed = Time.Span.zero; last_start_time = None } in
        Hashtbl.add_exn thread_timers ~key:name ~data:timer ;
        timer

  let get_elapsed_time name = (Hashtbl.find_exn thread_timers name).elapsed

  let iter_timed_threads ~f = Hashtbl.iter_keys thread_timers ~f
end

module No_trace = struct
  module Hooks = struct
    let trace_thread_switch _ _ = ()
  end

  let measure _ f = f ()

  let trace _ f = f ()

  let trace_event _ = ()

  let trace_recurring = trace

  let trace_task _ f = don't_wait_for (f ())

  let trace_recurring_task = trace_task
end

let implementation = ref (module No_trace : S_with_hooks)

let set_implementation x = implementation := x

let measure name f =
  let (module M) = !implementation in
  M.measure name f

let trace_event name =
  let (module M) = !implementation in
  M.trace_event name

let trace name f =
  let (module M) = !implementation in
  M.trace name f

let trace_recurring name f =
  let (module M) = !implementation in
  M.trace_recurring name f

let trace_recurring_task name f =
  let (module M) = !implementation in
  M.trace_recurring_task name f

let trace_task name f =
  let (module M) = !implementation in
  M.trace_task name f

let forget_tid f =
  let new_ctx =
    Execution_context.with_tid Scheduler.(current_execution_context ()) 0
  in
  let res = Scheduler.within_context new_ctx f |> Result.ok in
  Option.value_exn res

(* execution timing *)

let time_execution (name : string) (f : unit -> 'a) =
  let timer = Thread_timers.register name in
  let ctx = Scheduler.current_execution_context () in
  let ctx = Execution_context.with_local ctx thread_timer (Some timer) in
  let ctx = if ctx.tid = 0 then Thread_registry.assign_tid name ctx else ctx in
  match Scheduler.within_context ctx f with
  | Error () ->
      failwithf "timing task `%s` failed, exception reported to parent monitor"
        name ()
  | Ok x ->
      x

(* scheduler hooks *)

let trace_thread_switch (old_ctx : Execution_context.t)
    (new_ctx : Execution_context.t) =
  let now = lazy (Time.now ()) in
  Option.iter (Execution_context.find_local old_ctx thread_timer)
    ~f:(fun timer ->
      let last_start_time = Option.value_exn timer.last_start_time in
      let elapsed_this_execution =
        Time.abs_diff (Lazy.force now) last_start_time
      in
      timer.elapsed <- Time.Span.(timer.elapsed + elapsed_this_execution) ;
      timer.last_start_time <- None) ;
  Option.iter (Execution_context.find_local new_ctx thread_timer)
    ~f:(fun timer -> timer.last_start_time <- Some (Lazy.force now)) ;
  let (module M) = !implementation in
  M.Hooks.trace_thread_switch old_ctx new_ctx

let () = Async_kernel.Tracing.fns := { trace_thread_switch }
