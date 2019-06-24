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
    ; mutable target_hash: Frontier.Hash.t }

  let create base_hash = {diff_array= DynArray.create (); target_hash= base_hash}

  let check_for_overflow t =
    if DynArray.length t.diff_array > Capacity.max then
      failwith "persistence buffer overflow"

  let should_flush t =
    DynArray.length t.diff_array >= Capacity.flush

  let rec flush t ~worker =
    let diffs = DynArray.to_list t.diff_array in
    DynArray.clear t.diff_array;
    DynArray.compact t.diff_array;
    don't_wait_for (
      match%map Worker.dispatch worker (diffs, t.target_hash) with
      | Error err ->
          failwiths
            "failed to dispatch work to transition frontier persistence sync worker"
            err Error.sexp_of_t
      | Ok () -> (if should_flush t then flush t ~worker))

  let write t ~diff ~hash_transition ~worker =
    let open Frontier.Hash in
    (if not (Frontier.Hash.equal t.target_hash hash_transition.source) then
      failwith "invalid hash transition received by persistence buffer");
    t.target_hash <- hash_transition.target;
    DynArray.add t.diff_array diff;
    if should_flush t && not (Worker.is_working worker) then
      flush t ~worker
    else
      check_for_overflow t
end
