open Core_kernel
open Async_kernel
open Protocols

let option lab =
  Option.value_map ~default:(Or_error.error_string lab) ~f:(fun x -> Ok x)

let check label b = if not b then Or_error.error_string label else Ok ()

let map2_or_error xs ys ~f =
  let rec go xs ys acc =
    match (xs, ys) with
    | [], [] -> Ok (List.rev acc)
    | x :: xs, y :: ys -> (
      match f x y with Error e -> Error e | Ok z -> go xs ys (z :: acc) )
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
    { scan_state:
        scan_state
        (* Invariant: this is the ledger after having applied all the transactions in
    the above state. *)
    ; ledger: Ledger.t
    ; public_key: Public_key.Compressed.t }
  [@@deriving sexp, bin_io]

  let copy {scan_state; ledger; public_key} =
    { scan_state= Parallel_scan.State.copy scan_state
    ; ledger= Ledger.copy ledger
    ; public_key }

  let hash {scan_state; ledger; public_key= _} : Ledger_builder_hash.t =
    let h =
      Parallel_scan.State.hash scan_state
        (Binable.to_string (module Snark_with_statement))
        (Binable.to_string (module Snark_with_statement))
        (Binable.to_string (module Super_transaction_with_statement))
    in
    h#add_string (Ledger_hash.to_bits (Ledger.merkle_root ledger)) ;
    Ledger_builder_hash.of_bits h#result

  let ledger {ledger; _} = ledger

  let create ~ledger ~self : t =
    let open Config in
    { scan_state=
        Parallel_scan.start ~parallelism_log_2 ~init:(failwith "TODO")
          ~seed:(failwith "TODO")
    ; ledger
    ; public_key= self }

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

  let fill_in_completed_work (state: scan_state) (works: Completed_work.t list)
      : Transaction_snark.t with_statement option Or_error.t =
    (let open Or_error.Let_syntax in
    let%bind next_jobs =
      Parallel_scan.next_k_jobs ~state
        ~k:(List.length works * Completed_work.proofs_length)
    in
    let%bind scanable_work_list =
      map2_or_error next_jobs
        (List.concat_map works (fun work -> work.proofs))
        ~f:completed_work_to_scanable_work
    in
    Parallel_scan.fill_in_completed_jobs state scanable_work_list)

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
      (let open Deferred.Or_error.Let_syntax in
      let%bind jobses =
        Deferred.return
          (let open Or_error.Let_syntax in
          let%map jobs =
            Parallel_scan.next_k_jobs ~state:t.scan_state
              ~k:(List.length completed_works * Completed_work.proofs_length)
          in
          chunks_of jobs ~n:Completed_work.proofs_length)
      in
      Deferred.List.for_all (List.zip_exn jobses completed_works) ~f:
        (fun (jobs, work) ->
          let message = (work.fee, work.prover) in
          Deferred.List.for_all (List.zip_exn jobs work.proofs) ~f:
            (fun (job, proof) -> verify ~message job proof ) )
      |> Deferred.map ~f:(check "proofs did not verify"))

  (* TODO: This must be updated when we add coinbases *)
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
    let%bind fee_transfers =
      (*create fee transfers to pay the workers*)
      let singles =
        ( if Fee.Unsigned.(equal zero delta) then []
        else [(t.public_key, delta)] )
        @ List.map completed_works ~f:(fun {fee; prover} -> (prover, fee))
      in
      Or_error.try_with (fun () ->
        Public_key.Compressed.Map.of_alist_reduce singles ~f:(fun f1 f2 ->
          Option.value_exn (Fee.Unsigned.add f1 f2))
        |> Map.to_alist ~key_order:`Increasing (* TODO: This creates a weird incentive to have a small pubkey *)
        |> Fee_transfer.of_single_list)
      |> Result_with_rollback.of_or_error
    in
    let super_transactions =
      List.map payments ~f:(fun t -> Super_transaction.Transaction t)
      @ List.map fee_transfers ~f:(fun t -> Super_transaction.Fee_transfer t)
    in
    let%bind new_data =
      update_ledger_and_get_statements t.ledger super_transactions
    in
    let%bind () =
      check_completed_works t completed_works
    in
    let%bind res_opt =
      (* TODO: Add rollback *)
      let r =
        fill_in_completed_work
          t.scan_state completed_works
      in
      Or_error.iter_error r ~f:(fun e ->
        (* TODO: Pass a logger here *)
        eprintf !"Unexpected error: %s %{sexp:Error.t}\n%!"
          __LOC__ e);
      Result_with_rollback.of_or_error r
    in
    let%map () =
      (* TODO: Add rollback *)
      enqueue_data_with_rollback t.scan_state new_data
    in
    match res_opt with
    | None -> None
    | Some (snark, stmt) -> Some snark

  let apply t witness = Result_with_rollback.run (apply_diff t witness)

  let free_space t : int = Parallel_scan.free_space t.scan_state

  let sequence_chunks_of seq ~n =
    Sequence.unfold_step ~init:([], 0, seq) ~f:(fun (acc, i, seq) ->
        if i = n then Yield (List.rev acc, ([], 0, seq))
        else
          match Sequence.next seq with
          | None -> Done
          | Some (x, seq) -> Skip (x :: acc, i + 1, seq) )

  (* TODO: Make this actually return a sequence *)
  let work_to_do scan_state : Completed_work.Statement.t Sequence.t =
    let work_list = Parallel_scan.next_jobs scan_state in
    sequence_chunks_of ~n:Completed_work.proofs_length
    @@ Sequence.of_list
    @@ List.map work_list (fun maybe_work ->
           match statement_of_job maybe_work with
           | None -> assert false
           | Some work -> work )

  module Resources = struct
    module Queue_consumption = struct
      type t =
        { fee_transfers : Public_key.Compressed.Set.t
        ; transactions : int
        }

      let count { fee_transfers; transactions } =
        (* This is ceil(Set.length fee_transfers / 2) *)
        transactions + ((Set.length fee_transfers + 1) / 2)

      let add_transaction t = { t with transactions = t.transactions + 1 }

      let add_fee_transfer t public_key =
        { t with fee_transfers = Set.add t.fee_transfers public_key }

      let (+) t1 t2 =
        { fee_transfers = Set.union t1.fee_transfers t2.fee_transfers
        ; transactions = t1.transactions + t2.transactions
        }

      let empty = { transactions = 0; fee_transfers = Public_key.Compressed.Set.empty }
    end

    type t =
      { budget : Fee.Unsigned.t
      ; queue_consumption : Queue_consumption.t
      ; available_queue_space : int
      ; transactions : Transaction.With_valid_signature.t list
      ; completed_works : Completed_work.t list
      }

    let add_transaction t (txv : Transaction.With_valid_signature.t) =
      let tx = (txv :> Transaction.t) in
      let open Or_error.Let_syntax in
      let%bind budget =
        option "overflow" (Fee.Unsigned.add t.budget (Transaction.fee tx))
      in
      let queue_consumption =
        Queue_consumption.add_transaction t.queue_consumption
      in
      if Queue_consumption.count queue_consumption > t.available_queue_space
      then Or_error.error_string "Insufficient space"
      else Ok { t with budget; queue_consumption; transactions = txv :: t.transactions }

    let add_work t (w : Completed_work.t) =
      let open Or_error.Let_syntax in
      let%bind budget =
        option "overflow" (Fee.Unsigned.sub t.budget w.fee)
      in
      let queue_consumption =
        Queue_consumption.add_fee_transfer t.queue_consumption w.prover
      in
      if Queue_consumption.count queue_consumption > t.available_queue_space
      then Or_error.error_string "Insufficient space"
      else Ok { t with budget; queue_consumption; completed_works = w :: t.completed_works }

    let empty ~available_queue_space =
      { available_queue_space
      ; queue_consumption = Queue_consumption.empty
      ; budget= Fee.Unsigned.zero
      ; transactions = []
      ; completed_works = []
      }
  end

  let fold_until_error xs ~init ~f =
    List.fold_until xs ~init ~f:(fun acc x ->
      match f acc x with
      | Ok acc -> Continue acc
      | Error _ -> Stop acc)
      ~finish:Fn.id

  let fold_sequence_until_error seq ~init ~f =
    let rec go (processed, acc) seq =
      let finish () =
        begin match processed with
        | `Processed_none -> `Processed_none
        | `At_least_one -> `Processed_at_least_one (acc, seq)
        end
      in
      match Sequence.next seq with
      | None -> finish ()
      | Some (x, seq') ->
        begin match f acc x with
        | `Ok acc -> go (`At_least_one, acc) seq'
        | `Error e -> finish ()
        | `Skip -> go (processed, acc) seq'
        end
    in
    go (`Processed_none, init) seq

  let create_diff t
      ~(transactions_by_fee: Transaction.With_valid_signature.t Sequence.t)
      ~(get_completed_work:
         Completed_work.Statement.t -> Completed_work.t option) =
    (* TODO: Don't copy *)
    let ledger = Ledger.copy t.ledger in
    let or_error = function
      | Ok x -> `Ok x
      | Error e -> `Error e
    in
    let add_work resources work_to_do =
      fold_sequence_until_error work_to_do
        ~init:resources ~f:(fun resources w ->
          match get_completed_work w with
          | Some w ->
            (* TODO: There is a subtle error here.
               You should not add work if it would cause the person's
               balance to overflow *)
            or_error (Resources.add_work resources w)
          | None ->
            `Error (Error.of_string "Work not found"))
    in
    let add_transactions resources transactions_to_do =
      fold_sequence_until_error transactions_to_do
        ~init:resources ~f:(fun resources txn ->
          match Ledger.apply_transaction ledger txn with
          | Error _ -> `Skip
          | Ok () ->
            begin match Resources.add_transaction resources txn with
            | Ok resources -> `Ok resources
            | Error e ->
              Or_error.ok_exn (Ledger.undo_transaction ledger txn);
              `Error e
            end)
    in
    let rec add_many_work ~adding_transactions_failed resources ts_seq ws_seq =
      match add_work resources ws_seq with
      | `Processed_at_least_one (resources, ws_seq) ->
        add_many_transaction ~adding_work_failed:false resources ts_seq ws_seq
      | `Processed_none ->
        if adding_transactions_failed
        then resources
        else
          add_many_transaction ~adding_work_failed:true resources ts_seq ws_seq
    and add_many_transaction ~adding_work_failed resources ts_seq ws_seq =
      match add_transactions resources ts_seq with
      | `Processed_at_least_one (resources, ts_seq) ->
        add_many_work ~adding_transactions_failed:false resources ts_seq ws_seq
      | `Processed_none ->
        if adding_work_failed
        then resources
        else
          add_many_work ~adding_transactions_failed:true resources ts_seq ws_seq
    in
    let resources, t_rest  =
      let resources =
        Resources.empty
          ~available_queue_space:(free_space t)
      in
      let ts, t_rest =
        Sequence.split_n transactions_by_fee
          resources.available_queue_space
      in
      let resources =
        fold_until_error ts ~init:resources ~f:Resources.add_transaction
      in
      resources, t_rest
    in
    let resources =
      add_many_work ~adding_transactions_failed:false resources
        t_rest (work_to_do t.scan_state)
    in
    { Ledger_builder_diff.transactions=
        (* We have to reverse here because we only know they work in THIS order *)
        List.rev resources.transactions
    ; completed_works=
        List.rev resources.completed_works
    ; creator= t.public_key
    ; prev_hash= hash t
    }
end

let%test_module "ledger_builder" =
  ( module struct
    
  end )
