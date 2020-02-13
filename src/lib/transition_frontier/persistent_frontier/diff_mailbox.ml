(* TODO: flush on timeout interval in addition to meeting flush capacity *)
open Core_kernel
open Coda_base
open Frontier_base
open Otp_lib

module Batching_rules : Batch_mailbox.Rules_intf = struct
  let max_latency =
    Block_time.Span.(Consensus.Constants.block_window_duration * of_ms 5L)

  let flush_capacity = 30

  let max_capacity = flush_capacity * 4
end

module Diff_accumulator :
  Batch_mailbox.Accumulator_intf
  with type data = Diff.Lite.E.t list * Frontier_hash.transition
   and type emission = Diff.Lite.E.t list * Frontier_hash.t
   and type 'a creator = base_hash:Frontier_hash.t -> 'a = struct
  module Base_accumulator = Batch_mailbox.Make_sequential_accumulator (struct
    type t = Diff.Lite.E.t
  end)

  type nonrec t =
    {acc: Base_accumulator.t; mutable target_hash: Frontier_hash.t}

  type nonrec data = Diff.Lite.E.t list * Frontier_hash.transition

  type nonrec emission = Diff.Lite.E.t list * Frontier_hash.t

  type nonrec 'a creator = base_hash:Frontier_hash.t -> 'a

  let create_map f ~base_hash =
    let t = {acc= Base_accumulator.create (); target_hash= base_hash} in
    f t

  let create = create_map Fn.id

  let size {acc; _} = Base_accumulator.size acc

  let add t (diffs, hash_transition) =
    let open Frontier_hash in
    if not (equal t.target_hash hash_transition.source) then
      failwith "invalid hash transition received by persistence buffer" ;
    t.target_hash <- hash_transition.target ;
    List.iter diffs ~f:(Base_accumulator.add t.acc)

  let flush t = (Base_accumulator.flush t.acc, t.target_hash)
end

include Batch_mailbox.Make (Batching_rules) (Diff_accumulator) (Worker)
