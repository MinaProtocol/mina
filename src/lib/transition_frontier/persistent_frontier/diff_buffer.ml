(* TODO: flush on timeout interval in addition to meeting flush capacity *)
open Async_kernel
open Core_kernel

module Capacity = struct
  let flush = 30
  let max = flush * 4
end

module Make (Inputs : Intf.Inputs_with_worker_intf) = struct
  open Inputs

  type work =
    { diffs: Frontier.Diff.Lite.E.t list
    ; target_hash: Frontier.Hash.t }

  type t =
    { diff_array: Frontier.Diff.Lite.E.t DynArray.t
    ; worker: Worker.t
    ; mutable target_hash: Frontier.Hash.t }

  let create ~base_hash ~worker =
    { diff_array= DynArray.create ()
    ; worker
    ; target_hash= base_hash }

  let check_for_overflow t =
    if DynArray.length t.diff_array > Capacity.max then
      failwith "persistence buffer overflow"

  let should_flush t =
    DynArray.length t.diff_array >= Capacity.flush

  let rec flush t =
    let diffs = DynArray.to_list t.diff_array in
    DynArray.clear t.diff_array;
    DynArray.compact t.diff_array;
    don't_wait_for (
      let%map () = Worker.dispatch t.worker (diffs, t.target_hash) in
      (if should_flush t then flush t))

  let write t ~diffs ~hash_transition =
    let open Frontier.Hash in
    (if not (Frontier.Hash.equal t.target_hash hash_transition.source) then
      failwith "invalid hash transition received by persistence buffer");
    t.target_hash <- hash_transition.target;
    List.iter diffs ~f:(DynArray.add t.diff_array);
    if should_flush t && not (Worker.is_working t.worker) then
      flush t
    else
      check_for_overflow t

  let close_and_finish_copy _ = failwith "TODO"
end
