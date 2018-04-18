open Core_kernel
open Async_kernel

(*
 * TODO: Remove is really slow, we need to deal with this:
 *
 *  Reification of in-person discussion:
 *  Let's say our transaction pool has 100M transactions in it
 *  The question is: How often will we be removing transactions?
 *
 * 1. If we want to minimize space, we can remove transactions as soon as we
 *    see that they were used. In this case, we shouldn't use an Fheap as
 *    removing is O(n). We could use a balanced BST instead and remove would be
 *    faster, but we'd sacrifice `get` performance.
 * 2. We could instead just pop from our heap until we get `k` transactions that
 *    are valid on the current state (optionally we could use periodic garbage
 *    collection as well).
 *)
module Make (Transaction : Protocols.Minibit_pow.Transaction_intf) = struct
  module Txn = Transaction.With_valid_signature

  type t = Txn.t Fheap.t

  let empty = Fheap.create ~cmp:Txn.compare

  let add t txn = Fheap.add t txn

  let remove t txn =
    Fheap.of_list ~cmp:Txn.compare begin
      List.filter (Fheap.to_list t) ~f:(fun txn' -> Txn.equal txn txn')
    end

  let get t ~k =
    let rec go h i l =
      match Fheap.top h, Fheap.remove_top h, i with
      | None, _, _ -> l
      | _, _, 0 -> l
      | Some txn, Some h', i -> go h' (i - 1) (txn::l)
      | _, None, _ -> failwith "Impossible, top will be none if remove_top is none"
    in
    go t k []

  (* TODO: Actually back this by the file-system *)
  let load ~disk_location =
    return empty
end

