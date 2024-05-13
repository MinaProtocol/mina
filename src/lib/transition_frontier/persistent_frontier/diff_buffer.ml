(* TODO: flush on timeout interval in addition to meeting flush capacity *)
open Async_kernel
open Core_kernel
open Frontier_base

let max_latency
    { Genesis_constants.Constraint_constants.block_window_duration_ms; _ } =
  Block_time.Span.(
    (block_window_duration_ms |> Int64.of_int |> Block_time.Span.of_ms)
    * of_ms 5L)

module Capacity = struct
  let flush = 30

  let max = flush * 4
end

(* TODO: lift up as Block_time utility *)
module Timer = struct
  open Block_time

  type t =
    { time_controller : Controller.t
    ; f : unit -> unit
    ; span : Span.t
    ; mutable timeout : unit Timeout.t option
    }

  let create ~time_controller ~f span =
    { time_controller; span; f; timeout = None }

  let start t =
    assert (Option.is_none t.timeout) ;
    let rec run_timeout t =
      t.timeout <-
        Some
          (Timeout.create t.time_controller t.span ~f:(fun _ ->
               t.f () ; run_timeout t ) )
    in
    run_timeout t

  let stop t =
    Option.iter t.timeout ~f:(fun timeout ->
        Timeout.cancel t.time_controller timeout () ) ;
    t.timeout <- None

  let reset t = stop t ; start t
end

type work = { diffs : Diff.Lite.E.t list }

module Rev_dyn_array : sig
  type 'a t

  val create : unit -> _ t

  val length : _ t -> int

  val clear : _ t -> unit

  val to_list : 'a t -> 'a list

  val add : 'a t -> 'a -> unit
end = struct
  type 'a t = { mutable length : int; mutable rev_list : 'a list }

  let create () = { length = 0; rev_list = [] }

  let length { length; _ } = length

  let to_list { rev_list; _ } = List.rev rev_list

  let clear t =
    t.length <- 0 ;
    t.rev_list <- []

  let add t x =
    t.length <- t.length + 1 ;
    t.rev_list <- x :: t.rev_list
end

type t =
  { diff_array : Diff.Lite.E.t Rev_dyn_array.t
  ; worker : Worker.t
        (* timer unfortunately needs to be mutable to break recursion *)
  ; mutable timer : Timer.t option
  ; mutable flush_job : unit Deferred.t option
  ; mutable closed : bool
  }

let check_for_overflow t =
  if Rev_dyn_array.length t.diff_array > Capacity.max then
    failwith "persistence buffer overflow"

let should_flush t = Rev_dyn_array.length t.diff_array >= Capacity.flush

let flush t =
  let rec flush_job t =
    let diffs = Rev_dyn_array.to_list t.diff_array in
    Rev_dyn_array.clear t.diff_array ;
    let%bind () = Worker.dispatch t.worker diffs in
    if should_flush t then flush_job t
    else (
      t.flush_job <- None ;
      Deferred.unit )
  in
  assert (Option.is_none t.flush_job) ;
  if Rev_dyn_array.length t.diff_array > 0 then
    t.flush_job <- Some (flush_job t)

let create ~(constraint_constants : Genesis_constants.Constraint_constants.t)
    ~time_controller ~worker =
  let t =
    { diff_array = Rev_dyn_array.create ()
    ; worker
    ; timer = None
    ; flush_job = None
    ; closed = false
    }
  in
  let timer =
    Timer.create ~time_controller
      ~f:(fun () -> if Option.is_none t.flush_job then flush t)
      (max_latency constraint_constants)
  in
  t.timer <- Some timer ;
  t

let write t ~diffs =
  if t.closed then failwith "attempt to write to diff buffer after closed" ;
  List.iter diffs ~f:(Rev_dyn_array.add t.diff_array) ;
  if should_flush t && Option.is_none t.flush_job then flush t
  else check_for_overflow t

let close_and_finish_copy t =
  ( match t.timer with
  | None ->
      failwith "diff buffer timer was never initialized"
  | Some timer ->
      Timer.stop timer ) ;
  t.closed <- true ;
  let%bind () = Option.value t.flush_job ~default:Deferred.unit in
  flush t ;
  Option.value t.flush_job ~default:Deferred.unit
