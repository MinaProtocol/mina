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
module Make
    (Transaction : Protocols.Minibit_pow.Transaction_intf) (Ledger : sig
        type t

        val apply_transaction :
          t -> Transaction.With_valid_signature.t -> unit Or_error.t

        val undo_transaction : t -> Transaction.t -> unit Or_error.t
    end) =
struct
  module Txn = Transaction.With_valid_signature

  type t = Txn.t Fheap.t

  let empty = Fheap.create ~cmp:(Txn.compare ~seed:(Random.float Float.max_value |> string_of_float))

  let add t txn = Fheap.add t txn

  let get t ~k ~ledger =
    let rec go h i l =
      match (Fheap.top h, Fheap.remove_top h, i) with
      | None, _, _ -> l
      | _, _, 0 -> l
      | Some txn, Some h', i -> (
        match Ledger.apply_transaction ledger txn with
        | Ok () -> go h' (i - 1) (txn :: l)
        | Error e -> go h' (i - 1) l )
      | _, None, _ ->
          failwith "Impossible, top will be none if remove_top is none"
    in
    let txns = go t k [] in
    List.iter txns ~f:(fun txn ->
        Ledger.undo_transaction ledger (txn :> Transaction.t)
        |> Or_error.ok_exn ) ;
    txns

  (* TODO: Actually back this by the file-system *)
  let load ~disk_location = return empty
end
