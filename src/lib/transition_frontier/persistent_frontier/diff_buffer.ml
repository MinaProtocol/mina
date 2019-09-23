(* TODO: flush on timeout interval in addition to meeting flush capacity *)
open Async_kernel
open Core_kernel
open Frontier_base

module Capacity = struct
  let flush = 30

  let max = flush * 4
end

type work = {diffs: Diff.Lite.E.t list; target_hash: Frontier_hash.t}

type t =
  { diff_array: Diff.Lite.E.t DynArray.t
  ; worker: Worker.t
  ; mutable target_hash: Frontier_hash.t
  ; mutable flush_job: unit Deferred.t option
  ; mutable closed: bool }

let create ~base_hash ~worker =
  { diff_array= DynArray.create ()
  ; worker
  ; target_hash= base_hash
  ; flush_job= None
  ; closed= false }

let check_for_overflow t =
  if DynArray.length t.diff_array > Capacity.max then
    failwith "persistence buffer overflow"

let should_flush t = DynArray.length t.diff_array >= Capacity.flush

let flush t =
  let rec flush_job t =
    let diffs = DynArray.to_list t.diff_array in
    DynArray.clear t.diff_array ;
    DynArray.compact t.diff_array ;
    let%bind () = Worker.dispatch t.worker (diffs, t.target_hash) in
    if should_flush t then flush_job t
    else (
      t.flush_job <- None ;
      Deferred.unit )
  in
  assert (t.flush_job = None) ;
  if DynArray.length t.diff_array > 0 then t.flush_job <- Some (flush_job t)

let write t ~diffs ~hash_transition =
  let open Frontier_hash in
  if t.closed then failwith "attempt to write to diff buffer after closed" ;
  if not (Frontier_hash.equal t.target_hash hash_transition.source) then
    failwith "invalid hash transition received by persistence buffer" ;
  t.target_hash <- hash_transition.target ;
  List.iter diffs ~f:(DynArray.add t.diff_array) ;
  if should_flush t && t.flush_job = None then flush t
  else check_for_overflow t

let close_and_finish_copy t =
  t.closed <- false ;
  let%bind () = Option.value t.flush_job ~default:Deferred.unit in
  flush t ;
  Option.value t.flush_job ~default:Deferred.unit
