open Core_kernel
open Async_kernel
open Protocols

let option lab =
  Option.value_map ~default:(Or_error.error_string lab) ~f:(fun x -> Ok x)

let check label b = if not b then Or_error.error_string label else Ok ()

let map2_or_error xs ys ~f =
  let rec go xs ys acc =
    match xs, ys with
    | [], [] -> Ok (List.rev acc)
    | x :: xs, y :: ys ->
      begin match f x y with
      | Error e -> Error e
      | Ok z ->
        go xs ys (z :: acc)
      end
    | _, _ -> Or_error.error_string "Length mismatch"
  in
  go xs ys []

module Make (Inputs : Inputs.S) :
  Coda_pow.Ledger_builder_intf
  with type diff := Inputs.Ledger_builder_diff.t
   and type ledger_builder_hash := Inputs.Ledger_builder_hash.t
   and type public_key := Inputs.Public_key.Compressed.t
   and type ledger := Inputs.Ledger.t
   and type transaction_snark := Inputs.Transaction_snark.t
   and type transaction_with_valid_signature :=
              Inputs.Transaction.With_valid_signature.t
   and type completed_work := Inputs.Completed_work.t
   and type statement := Inputs.Completed_work.Statement.t =
struct
  open Inputs

  type 'a with_statement = 'a * Transaction_snark.Statement.t
  [@@deriving sexp, bin_io]

(* TODO: This is redundant right now, the transaction snark has the statement
   inside of it. *)
  module Snark_with_statement = struct
    type t = Transaction_snark.t with_statement [@@deriving sexp, bin_io]
  end

  module Super_transaction_with_statement = struct
    type t = Super_transaction.t with_statement [@@deriving sexp, bin_io]
  end

  type job =
    ( Transaction_snark.t with_statement
    , Super_transaction.t with_statement )
    Parallel_scan.State.Job.t
  [@@deriving sexp_of]

  type parallel_scan_completed_job =
    (*For the parallel scan*)
    ( Transaction_snark.t with_statement
    , Transaction_snark.t with_statement )
    Parallel_scan.State.Completed_job.t
  [@@deriving sexp, bin_io]

  type scan_state =
    ( Transaction_snark.t with_statement
    , Transaction_snark.t with_statement
    , Super_transaction.t with_statement )
    Parallel_scan.State.t
  [@@deriving sexp, bin_io]

  type t =
    { scan_state: scan_state
        (* Invariant: this is the ledger after having applied all the transactions in
    the above state. *)
    ; ledger: Ledger.t
    ; public_key: Public_key.Compressed.t }
  [@@deriving sexp, bin_io]

  let copy {scan_state; ledger; public_key} =
    { scan_state= Parallel_scan.State.copy scan_state
    ; ledger= Ledger.copy ledger
    ; public_key }

  let hash { scan_state; ledger; public_key=_} : Ledger_builder_hash.t =
    let h =
      Parallel_scan.State.hash scan_state
        (Binable.to_string (module Snark_with_statement))
        (Binable.to_string (module Snark_with_statement))
        (Binable.to_string (module Super_transaction_with_statement))
    in
    h#add_string (Ledger_hash.to_bits (Ledger.merkle_root ledger));
    Ledger_builder_hash.of_bits h#result

  let ledger { ledger; _ } = ledger

  let create ~ledger ~self : t =
    let open Config in
    { scan_state =
        Parallel_scan.start ~parallelism_log_2 ~init:(failwith "TODO")
          ~seed:(failwith "TODO")
    ; ledger
    ; public_key = self
    }

  let statement_of_job : job -> Transaction_snark.Statement.t option = function
    | Base (Some (_, statement)) -> Some statement
    | Merge_up (Some (_, statement)) -> Some statement
    | Merge (Some (_, stmt1), Some (_, stmt2)) ->
        let open Option.Let_syntax in
        let%bind () =
          Option.some_if (Ledger_hash.equal stmt1.target stmt2.source) ()
        in
        let%map fee_excess =
          Fee.Signed.add stmt1.fee_excess stmt2.fee_excess
        in
        { Transaction_snark.Statement.source= stmt1.source
        ; target= stmt2.target
        ; fee_excess
        ; proof_type= `Merge }
    | _ -> None

  let completed_work_to_scanable_work (job: job) (proof: Transaction_snark.t) :
      parallel_scan_completed_job Or_error.t =
    match job with
    | Base (Some (t, s)) -> Ok (Lifted (proof, s))
    | Merge_up (Some (t, s)) -> Ok (Merged_up (proof, s))
    | Merge (Some (t, s), Some (t', s')) ->
        let open Or_error.Let_syntax in
        let%map fee_excess =
          Fee.Signed.add s.fee_excess s'.fee_excess
          |> option "Error adding fees"
        in
        Parallel_scan.State.Completed_job.Merged
          ( proof
          , { Transaction_snark.Statement.source= s.source
            ; target= s'.target
            ; fee_excess
            ; proof_type= `Merge } )
    | _ -> Error (Error.of_thunk (fun () -> sprintf "Invalid job"))

  let verify ~message job proof =
    match statement_of_job job with
    | None -> return false
    | Some statement -> Transaction_snark.verify proof statement ~message

  let fill_in_completed_work
        (state: scan_state)
        (works: Completed_work.t list)
      : Transaction_snark.t with_statement option Result_with_rollback.t
      =
    Result_with_rollback.of_or_error
      (let open Or_error.Let_syntax in
      let next_jobs =
        Parallel_scan.next_k_jobs ~state
          ~k:(List.length works * Completed_work.proofs_length)
      in
      match next_jobs with
      | Error e -> Error e
      | Ok jobs ->
          let%bind scanable_work_list =
            map2_or_error jobs (List.concat_map works (fun work -> work.proofs))
                ~f:completed_work_to_scanable_work
          in
          Parallel_scan.fill_in_completed_jobs state scanable_work_list
     )

  let enqueue_data_with_rollback state data : unit Result_with_rollback.t =
    Result_with_rollback.of_or_error @@ Parallel_scan.enqueue_data state data

  let sum_fees xs ~f =
    with_return (fun {return} ->
        Ok
          (List.fold ~init:Fee.Unsigned.zero xs ~f:(fun acc x ->
               match Fee.Unsigned.add acc (f x) with
               | None -> return (Or_error.error_string "Fee overflow")
               | Some res -> res )) )

  let update_ledger_and_get_statements ledger ts =
    let undo_transactions =
      List.iter ~f:(fun t ->
          Or_error.ok_exn (Ledger.undo_super_transaction ledger t) )
    in
    let rec go processed acc = function
      | [] ->
          Deferred.return
            { Result_with_rollback.result= Ok (List.rev acc)
            ; rollback= Call (fun () -> undo_transactions processed) }
      | t :: ts ->
          let source = Ledger.merkle_root ledger in
          match Ledger.apply_super_transaction ledger t with
          | Error e ->
              undo_transactions processed ;
              Result_with_rollback.error e
          | Ok () ->
              let target = Ledger.merkle_root ledger in
              let stmt : Transaction_snark.Statement.t =
                { source
                ; target
                ; fee_excess= Super_transaction.fee_excess t
                ; proof_type= `Base }
              in
              go (t :: processed) ((t, stmt) :: acc) ts
    in
    go [] [] ts

  let chunks_of xs ~n = List.groupi xs ~break:(fun i _ _ -> i mod n = 0)

  let check_completed_works t (completed_works: Completed_work.t list) =
    Result_with_rollback.with_no_rollback
      Deferred.Or_error.Let_syntax.(
        match
          Parallel_scan.next_k_jobs ~state:t.scan_state
            ~k:(List.length completed_works * Completed_work.proofs_length)
          |> Or_error.map ~f:(chunks_of ~n:Completed_work.proofs_length)
        with
        | Error e -> Deferred.return (Error e)
        | Ok jobses ->
            Deferred.List.for_all (List.zip_exn jobses completed_works) ~f:
              (fun (jobs, work) ->
                let message = (work.fee, work.prover) in
                Deferred.List.for_all (List.zip_exn jobs work.proofs) ~f:
                  (fun (job, proof) -> verify ~message job proof ) )
            |> Deferred.map ~f:(check "proofs did not verify"))

  let apply_diff t (diff: Ledger_builder_diff.t) =
    let payments = diff.transactions in
    let completed_works = diff.completed_works in
    let open Result_with_rollback.Let_syntax in
    let%bind () =
      check "bad hash"
        (not (Ledger_builder_hash.equal diff.prev_hash (hash t)))
      |> Result_with_rollback.of_or_error
    in
    let%bind delta =
      Result_with_rollback.of_or_error
        (let open Or_error.Let_syntax in
        let%bind budget =
          sum_fees payments ~f:(fun t -> Transaction.fee (t :> Transaction.t))
        in
        let%bind work_fee =
          sum_fees completed_works ~f:(fun {fee; _} -> fee)
        in
        option "budget did not suffice" (Fee.Unsigned.sub budget work_fee))
    in
    let fee_transfers =
      (*create fee transfers to pay the workers*)
      let singles =
        ( if Fee.Unsigned.(equal zero delta) then []
        else [(t.public_key, delta)] )
        @ List.map completed_works ~f:(fun {fee; prover} -> (prover, fee))
      in
      Fee_transfer.of_single_list singles
    in
    let super_transactions =
      List.map payments ~f:(fun t -> Super_transaction.Transaction t)
      @ List.map fee_transfers ~f:(fun t -> Super_transaction.Fee_transfer t)
    in
    let%bind new_data =
      update_ledger_and_get_statements t.ledger super_transactions
    in
    let%bind () = check_completed_works t completed_works in
    let%bind res_opt = fill_in_completed_work t.scan_state completed_works in
    let%map () = enqueue_data_with_rollback t.scan_state new_data in
    match res_opt with None -> None | Some (snark, stmt) -> Some snark

  let apply t witness = Result_with_rollback.run (apply_diff t witness)

  let free_space scan_state : int = Parallel_scan.free_space scan_state

  let sequence_chunks_of seq ~n =
    Sequence.unfold_step ~init:([], 0, seq) ~f:(fun (acc, i, seq) ->
        if i = n then Yield (List.rev acc, ([], 0, seq))
        else
          match Sequence.next seq with
          | None -> Done
          | Some (x, seq) -> Skip (x :: acc, i + 1, seq) )

  let work_to_do scan_state : Transaction_snark.Statement.t Sequence.t =
    match Parallel_scan.next_jobs scan_state with
    | Error e -> failwith @@ Error.to_string_hum e
    | Ok work_list ->
        Sequence.of_list
        @@ List.map work_list (fun maybe_work ->
               match statement_of_job maybe_work with
               | None -> failwith "Error extracting statement from job"
               | Some work -> work )

  (* First, if there's any free space on the queue, put transactions there *)
  let create_diff t
      ~(transactions_by_fee: Transaction.With_valid_signature.t Sequence.t)
      ~(get_completed_work:
         Completed_work.Statement.t -> Completed_work.t option) =
    let take_until_budget_exceeded_or_work_absent budget0 work_to_do =
      Sequence.fold_until work_to_do ~init:(budget0, [])
        ~f:(fun (budget, ws) stmt ->
          match get_completed_work stmt with
          | None -> Stop (budget, ws)
          | Some w ->
            match Fee.Unsigned.sub budget w.Completed_work.fee with
            | None -> Stop (budget, ws)
            | Some budget' -> Continue (budget', w :: ws) )
        ~finish:Fn.id
    in
    let rec go budget payments works
        (transactions_by_fee: Transaction.With_valid_signature.t Sequence.t)
        work_to_do =
      match (Sequence.next transactions_by_fee, Sequence.next work_to_do) with
      | None, Some _ ->
          (* Now we take work as our budget permits *)
          let budget', additional_works =
            take_until_budget_exceeded_or_work_absent budget work_to_do
          in
          (budget', payments, additional_works @ works)
      | Some _, None | None, None ->
          (* No work to do. *)
          (budget, payments, works)
      | Some (t, transactions_by_fee), Some (stmt, work_to_do) ->
        match get_completed_work stmt with
        | None -> (budget, payments, works)
        | Some work ->
          match
            Fee.Unsigned.add budget (Transaction.fee (t :> Transaction.t))
          with
          (* You could actually go a bit further in this case by using
             cheaper transacitons that don't cause an overflow, but
             we omit this for now. *)
          | None ->
              (* Now we take work as our budget permits *)
              let budget', additional_works =
                take_until_budget_exceeded_or_work_absent budget work_to_do
              in
              (budget', payments, additional_works @ works)
          | Some budget_after_t ->
            match Fee.Unsigned.sub budget_after_t work.fee with
            (* The work was too expensive, so we are done *)
            | None -> (budget, payments, works)
            | Some budget' ->
                go budget' (t :: payments) (work :: works) transactions_by_fee
                  work_to_do
    in
    (* First, we can add as many transactions as there is space on the
       queue (up to the max fee) *)
    let initial_budget, initial_payments, transactions_by_fee =
      let free_space = free_space t.scan_state in
      let rec go total_fee acc i
          (ts: Transaction.With_valid_signature.t Sequence.t) =
        if Int.( = ) i free_space then (total_fee, acc, ts)
        else
          match Sequence.next ts with
          | None -> (total_fee, acc, Sequence.empty)
          | Some (t, ts') ->
            match
              Fee.Unsigned.add total_fee (Transaction.fee (t :> Transaction.t))
            with
            | None -> (total_fee, acc, Sequence.empty)
            | Some total_fee' -> go total_fee' (t :: acc) (i + 1) ts'
      in
      go Fee.Unsigned.zero [] 0 transactions_by_fee
    in
    let _left_over_fees, payments, works =
      go initial_budget initial_payments [] transactions_by_fee
        (sequence_chunks_of (work_to_do t.scan_state)
           Completed_work.proofs_length)
    in
    { Ledger_builder_diff.transactions= payments
    ; completed_works= works
    ; creator= t.public_key
    ; prev_hash= hash t }
end

let%test_module "ledger_builder" =
  ( module struct
    
  end )
