open Core
open Async
include Intf

type thread_timer =
  { name : string
  ; parent : thread_timer option
  ; mutable elapsed : Time.Span.t
  ; mutable last_start_time : Time.t option
  }
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
  module Maybe_string = Hashable.Make (struct
    type t = string option [@@deriving compare, hash, sexp]
  end)

  let thread_timers : thread_timer Maybe_string.Table.t String.Table.t =
    String.Table.create ()

  let register ~name ~parent =
    if not (Hashtbl.mem thread_timers name) then
      Hashtbl.add_exn thread_timers ~key:name
        ~data:(Maybe_string.Table.create ()) ;
    let subkey = Option.map parent ~f:(fun p -> p.name) in
    let subtable = Hashtbl.find_exn thread_timers name in
    match Hashtbl.find subtable subkey with
    | Some timer ->
        timer
    | None ->
        let timer =
          { name; elapsed = Time.Span.zero; last_start_time = None; parent }
        in
        Hashtbl.add_exn subtable ~key:subkey ~data:timer ;
        timer

  let get_elapsed_time name =
    Hashtbl.find_exn thread_timers name
    |> Hashtbl.data
    |> List.sum (module Time.Span) ~f:(fun t -> t.elapsed)

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
  let ctx = Scheduler.current_execution_context () in
  let parent = Execution_context.find_local ctx thread_timer in

  if
    Option.value_map parent ~default:false ~f:(fun p ->
        String.equal p.name name)
  then f ()
  else
    let rec thread_name timer =
      timer.name
      ^ Option.value_map timer.parent ~default:"" ~f:(fun p ->
            ":" ^ thread_name p)
    in
    let timer = Thread_timers.register ~name ~parent in
    let ctx =
      Execution_context.with_local ctx thread_timer (Some timer)
      |> Thread_registry.assign_tid (thread_name timer)
    in
    match Scheduler.within_context ctx f with
    | Error () ->
        failwithf
          "timing task `%s` failed, exception reported to parent monitor" name
          ()
    | Ok x ->
        x

(* scheduler hooks *)

let trace_log = Out_channel.create "trace"

let trace_thread_switch (old_ctx : Execution_context.t)
    (new_ctx : Execution_context.t) =
  let now = lazy (Time.now ()) in
  let rec update_timer elapsed_this_execution timer =
    timer.elapsed <- Time.Span.(timer.elapsed + elapsed_this_execution) ;
    Option.iter timer.parent ~f:(update_timer elapsed_this_execution)
  in
  Option.iter (Execution_context.find_local old_ctx thread_timer)
    ~f:(fun timer ->
      Out_channel.output_string trace_log (Printf.sprintf "< %s" timer.name) ;
      let last_start_time = Option.value_exn timer.last_start_time in
      let elapsed_this_execution =
        Time.abs_diff (Lazy.force now) last_start_time
      in
      timer.last_start_time <- None ;
      update_timer elapsed_this_execution timer) ;
  Option.iter (Execution_context.find_local new_ctx thread_timer)
    ~f:(fun timer ->
      Out_channel.output_string trace_log (Printf.sprintf "> %s" timer.name) ;
      timer.last_start_time <- Some (Lazy.force now)) ;
  let (module M) = !implementation in
  M.Hooks.trace_thread_switch old_ctx new_ctx

let () = Async_kernel.Tracing.fns := { trace_thread_switch }
