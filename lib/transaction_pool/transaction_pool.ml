open Core_kernel
open Async_kernel

(*
 * TODO: Remove could be really slow, we need to deal with this:
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
 *
 * For now we are removing lazily when we look for the next transactions
 *)
module Make (Txn : sig
  type t [@@deriving compare]
end) =
struct
  type t = Txn.t Fheap.t

  let empty = Fheap.create ~cmp:Txn.compare

  let add t txn = Fheap.add t txn

  let transactions t = Sequence.unfold ~init:t ~f:Fheap.pop

  (* TODO: Actually back this by the file-system *)
  let load ~disk_location = return empty
end
