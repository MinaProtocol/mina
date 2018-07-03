open Core
open Nanobit_base

module Completed_work = struct
  type t =
    { fee : Currency.Fee.t
    ; worker : Public_key.Compressed.t
    ; proof : Proof.t
    }
end

(* Essentially Ledger_builder_witness *)
module Ledger_builder_diff = struct
  type t =
    { prev_hash : Ledger_builder_hash.t
    ; payments : Transaction.t
    ; work_done : Completed_work.t list
    ; creator : Public_key.t
    }
end

module Statement = struct
  type t =
    { source : Ledger_hash.t
    ; target : Ledger_hash.t
    ; fee_excess : Currency.Amount.Signed.t
    ; proof_type : [ `Merge | `Base ]
    }
end

module With_statement = struct
  type 'a t = 'a * Statement.t
end

type job =
  (Transaction_snark.t With_statement.t, Transaction.t With_statement.t) Parallel_scan.State.Job.t

type t =
  { parallel_scan :
      ( Transaction_snark.t With_statement.t,
        Transaction_snark.t With_statement.t,
        Transaction.t With_statement.t
      ) Parallel_scan.State.t
  }

module Snark_pool : sig
  type t

  val request_proof : Statement.t -> (Proof.t * Fee.t * Public_key.t) option
end = struct
end

type t

(* What you call when you win a block *)
(* Pull some transactions from the transaction pool. They give you some fee budget.
   Pull as many SNARKs as you can from the pool.. *)
(* Don't implement, defer to Ledger_builder_controller.t *)
let create_diff : t -> Snark_pool.t -> Transaction_pool.t -> Ledger_builder_diff.t = failwith "TODO"

let statement_of_job : job -> Statement.t option = function
  | Base (Some (_, statement)) -> statement
  | Merge_up (Some (_, statement)) -> statement
  | Merge (Some (_, stmt1), Some (_, stmt2)) ->
    assert (Ledger_hash.equal stmt1.target stmt2.source);
    { source = stmt1.source
    ; target = stmt2.target
    ; fee_excess =
        Currency.Amount.Signed.add stmt1.fee_excess stmt2.fee_excess
        |> Option.value_exn 
    ; proof_type = `Merge
    }
;;

module Ledger_proof = struct
  type t =
    { next_ledger_hash : Ledger_hash.t
    ; proof : Proof.t
    }
end

let apply_diff : t -> Ledger_builder_diff.t -> Ledger_proof.t option Or_error.t =
  let check b label =
    if not b then Or_error.error_string label else Ok ()
  in
  let open Or_error.Let_syntax in
  fun t diff ->
    let%bind () =
      check (not (Ledger_builder_hash.equal diff.prev_hash (Ledger_builder.hash t)))
        "bad hash"
    in
    let delta = 
      List.sum diff.payments ~f:(fun txn -> txn.payload.fee)
      - List.sum diff.completed_work ~f:(fun work -> work.fee)
    in
    let%bind () = check (delta >= 0) "fees suffice" in
    let%bind () =
      let%bind next_jobs =
        Parallel_scan.next_k_jobs
          t.parallel_scan
          (List.length diff.completed_work)
      in
      Or_error.try_with (fun () ->
        List.iter2_exn next_jobs diff.completed_work ~f:(fun job work ->
          let statement = Option.value_exn (statement_of_job job) in
          assert (
            Transaction_snark.verify (
              Transaction_snark.create
                ~proof:work.proof
                ~source:statement.source
                ~target:statement.target
                ~fee_excess:statement.fee_excess
                ~proof_type:statement.proof_type))))
    in
    let%bind () =
      (* Actually apply the work *)
      return ()
    in
    let%bind () =
      (* Enqueue the payments in diff.payments to the parallel_scan *)
      (* Also you enqueue fee transfers corresponding the work  *)
      let fee_transfers =
        List.map diff.completed_work ~f:(fun work ->
          (work.worker, work.fee))
        |> Fee_transfer.of_single_list
      in
      enqueue diff.payments;
      enqueue fee_transfers;
    in
    return the proof and the next hash (which you can get from the statment)

