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
module Make (Transaction : sig
  type t [@@deriving compare, bin_io, sexp]

  module With_valid_signature : sig
    type nonrec t = private t

    include Comparable with type t := t
  end

  val check : t -> With_valid_signature.t option
end) =
struct
  type pool =
    { heap: Transaction.With_valid_signature.t Fheap.t
    ; set: Transaction.With_valid_signature.Set.t }

  type t = pool ref

  let create () =
    ref
      { heap= Fheap.create ~cmp:Transaction.With_valid_signature.compare
      ; set= Transaction.With_valid_signature.Set.empty }

  let add' t txn = {heap= Fheap.add t.heap txn; set= Set.add t.set txn}

  let add t_ref txn = t_ref := add' !t_ref txn

  let transactions t = Sequence.unfold ~init:!t.heap ~f:Fheap.pop

  module Diff = struct
    type t = Transaction.t list [@@deriving bin_io, sexp]

    (* TODO: Check signatures *)
    let apply t_ref txns =
      let t0 = !t_ref in
      let t, res =
        List.fold txns ~init:(t0, []) ~f:(fun (t, acc) txn ->
            match Transaction.check txn with
            | None -> (* TODO Punish *)
                      (t, acc)
            | Some txn ->
                if Set.mem t.set txn then (t, acc)
                else (add' t txn, (txn :> Transaction.t) :: acc) )
      in
      t_ref := t ;
      match res with
      | [] -> Deferred.Or_error.error_string "No new transactions"
      | xs -> Deferred.Or_error.return xs
  end

  (* TODO: Actually back this by the file-system *)
  let load ~disk_location = return (create ())
end
