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
module Make (Payment : sig
  type t [@@deriving compare, bin_io, sexp]

  module With_valid_signature : sig
    type nonrec t = private t [@@deriving sexp]

    include Comparable with type t := t
  end

  val check : t -> With_valid_signature.t option
end) =
struct
  type pool =
    { heap: Payment.With_valid_signature.t Fheap.t
    ; set: Payment.With_valid_signature.Set.t }

  type t = {mutable pool: pool; log: Logger.t}

  let create ~parent_log =
    { pool=
        { heap= Fheap.create ~cmp:Payment.With_valid_signature.compare
        ; set= Payment.With_valid_signature.Set.empty }
    ; log= Logger.child parent_log __MODULE__ }

  let add' pool txn = {heap= Fheap.add pool.heap txn; set= Set.add pool.set txn}

  let add t txn = t.pool <- add' t.pool txn

  let transactions t = Sequence.unfold ~init:t.pool.heap ~f:Fheap.pop

  module Diff = struct
    type t = Payment.t list [@@deriving bin_io, sexp]

    let summary t =
      Printf.sprintf "Transaction diff of length %d" (List.length t)

    (* TODO: Check signatures *)
    let apply t txns =
      let pool0 = t.pool in
      let pool', res =
        List.fold txns ~init:(pool0, []) ~f:(fun (pool, acc) txn ->
            match Payment.check txn with
            | None ->
                Logger.faulty_peer t.log "Transaction doesn't check" ;
                (pool, acc)
            | Some txn ->
                if Set.mem pool.set txn then (
                  Logger.debug t.log
                    !"Skipping txn %{sexp: Payment.With_valid_signature.t} \
                      because I've already seen it"
                    txn ;
                  (pool, acc) )
                else (
                  Logger.debug t.log
                    !"Adding %{sexp: Payment.With_valid_signature.t} to my \
                      pool locally, and scheduling for rebroadcast"
                    txn ;
                  (add' pool txn, (txn :> Payment.t) :: acc) ) )
      in
      t.pool <- pool' ;
      match res with
      | [] -> Deferred.Or_error.error_string "No new transactions"
      | xs -> Deferred.Or_error.return xs
  end

  (* TODO: Actually back this by the file-system *)
  let load ~disk_location:_ ~parent_log = return (create ~parent_log)
end
