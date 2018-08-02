open Core_kernel
open Async_kernel
open Protocols
open Coda_pow

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

module Make (Inputs : Inputs.S) : sig
  open Inputs

  include Coda_pow.Ledger_builder_intf
          with type diff := Inputs.Ledger_builder_diff.t
           and type valid_diff :=
                      Inputs.Ledger_builder_diff.
                      With_valid_signatures_and_proofs.t
           and type ledger_hash := Inputs.Ledger_hash.t
           and type ledger_builder_hash := Inputs.Ledger_builder_hash.t
           and type public_key := Inputs.Public_key.t
           and type ledger := Inputs.Ledger.t
           and type transaction_with_valid_signature :=
                      Inputs.Transaction.With_valid_signature.t
           and type statement := Inputs.Completed_work.Statement.t
           and type completed_work := Inputs.Completed_work.Checked.t
           and type ledger_proof := Inputs.Ledger_proof.t
           and type ledger_builder_aux_hash := Inputs.Ledger_builder_aux_hash.t
           and type sparse_ledger := Inputs.Sparse_ledger.t
           and type ledger_proof_statement := Inputs.Ledger_proof_statement.t
           and type super_transaction := Inputs.Super_transaction.t
end = struct
  open Inputs

  type 'a with_statement = 'a * Ledger_proof_statement.t
  [@@deriving sexp, bin_io]

  module Super_transaction_with_witness = struct
    type t =
      { transaction: Super_transaction.t
      ; statement: Ledger_proof_statement.t
      ; witness: Inputs.Sparse_ledger.t }
    [@@deriving sexp, bin_io]
  end

  (* TODO: This is redundant right now, the transaction snark has the statement
   inside of it. *)
  module Snark_with_statement = struct
    type t = Ledger_proof.t with_statement [@@deriving sexp, bin_io]
  end

  type job =
    ( Ledger_proof.t with_statement
    , Super_transaction_with_witness.t )
    Parallel_scan.Available_job.t
  [@@deriving sexp_of]

  type parallel_scan_completed_job =
    (*For the parallel scan*)
    Ledger_proof.t with_statement Parallel_scan.State.Completed_job.t
  [@@deriving sexp, bin_io]

  module Aux = struct
    type t =
      ( Ledger_proof.t with_statement
      , Super_transaction_with_witness.t )
      Parallel_scan.State.t
    [@@deriving sexp, bin_io]

    let hash_to_string scan_state =
      let h =
        Parallel_scan.State.hash scan_state
          (Binable.to_string (module Snark_with_statement))
          (Binable.to_string (module Super_transaction_with_witness))
      in
      h#result

    let hash t = Ledger_builder_aux_hash.of_bytes (hash_to_string t)
  end

  type scan_state = Aux.t [@@deriving sexp, bin_io]

  type t =
    { scan_state:
        scan_state
        (* Invariant: this is the ledger after having applied all the transactions in
    the above state. *)
    ; ledger: Ledger.t
    ; public_key: Public_key.t }
  [@@deriving sexp, bin_io]

  let merge_statement (s1: Ledger_proof_statement.t)
      (s2: Ledger_proof_statement.t) =
    let open Or_error.Let_syntax in
    let%map fee_excess =
      Fee.Signed.add s1.fee_excess s2.fee_excess |> option "Error adding fees"
    in
    { Ledger_proof_statement.source= s1.source
    ; target= s2.target
    ; fee_excess
    ; proof_type= `Merge }

  let random_work_spec_chunk t =
    let module A = Parallel_scan.Available_job in
    let jobs = Parallel_scan.next_jobs ~state:t.scan_state in
    let n = List.length jobs in
    if n = 0 then None
    else
      (* TODO: Should we break these up in such a way that the following
       * situation can't happen:
       * A gets 0,1 ; B gets 1,2
       * Essentially you "can't" buy B if you buy A
       *)
      let i = Random.int n in
      (* TODO: This assertion will always pass once we implement #305 *)
      assert (n > 1) ;
      let chunk = [List.nth_exn jobs i; List.nth_exn jobs ((i + 1) % n)] in
      Some
        (List.map chunk ~f:(function
          | A.Base d ->
              Snark_work_lib.Work.Single.Spec.Transition
                (d.statement, d.transaction, d.witness)
          | A.Merge ((p1, s1), (p2, s2)) ->
              let merged = merge_statement s1 s2 |> Or_error.ok_exn in
              Snark_work_lib.Work.Single.Spec.Merge (merged, p1, p2) ))

  let aux {scan_state; _} = scan_state

  let make ~public_key ~ledger ~aux = {public_key; ledger; scan_state= aux}

  let copy {scan_state; ledger; public_key} =
    { scan_state= Parallel_scan.State.copy scan_state
    ; ledger= Ledger.copy ledger
    ; public_key }

  let hash {scan_state; ledger; public_key= _} : Ledger_builder_hash.t =
    let h = Cryptokit.Hash.sha3 256 in
    h#add_string (Ledger_hash.to_bytes (Ledger.merkle_root ledger)) ;
    h#add_string (Aux.hash_to_string scan_state) ;
    Ledger_builder_hash.of_bytes h#result

  let ledger {ledger; _} = ledger

  let create ~ledger ~self : t =
    let open Config in
    { scan_state= Parallel_scan.start ~parallelism_log_2
    ; ledger
    ; public_key= self }

  let of_aux_and_ledger ~self ledger scan_state =
    (* TODO: Actually check the validity? *)
    {scan_state; ledger; public_key= self}

  let statement_of_job : job -> Ledger_proof_statement.t option = function
    | Base {statement; _} -> Some statement
    | Merge ((_, stmt1), (_, stmt2)) ->
        let open Option.Let_syntax in
        let%bind () =
          Option.some_if (Ledger_hash.equal stmt1.target stmt2.source) ()
        in
        let%map fee_excess =
          Fee.Signed.add stmt1.fee_excess stmt2.fee_excess
        in
        { Ledger_proof_statement.source= stmt1.source
        ; target= stmt2.target
        ; fee_excess
        ; proof_type= `Merge }

  let completed_work_to_scanable_work (job: job) (proof: Ledger_proof.t) :
      parallel_scan_completed_job Or_error.t =
    match job with
    | Base {statement; _} -> Ok (Lifted (proof, statement))
    | Merge ((t, s), (t', s')) ->
        let open Or_error.Let_syntax in
        let%map fee_excess =
          Fee.Signed.add s.fee_excess s'.fee_excess
          |> option "Error adding fees"
        in
        Parallel_scan.State.Completed_job.Merged
          ( proof
          , { Ledger_proof_statement.source= s.source
            ; target= s'.target
            ; fee_excess
            ; proof_type= `Merge } )

  let verify ~message job proof =
    match statement_of_job job with
    | None -> return false
    | Some statement -> Ledger_proof.verify proof statement ~message

  let fill_in_completed_work (state: scan_state) (works: Completed_work.t list)
      : Ledger_proof.t with_statement option Or_error.t =
    let open Or_error.Let_syntax in
    let%bind next_jobs =
      Parallel_scan.next_k_jobs ~state
        ~k:(List.length works * Completed_work.proofs_length)
    in
    let%bind scanable_work_list =
      map2_or_error next_jobs
        (List.concat_map works (fun work -> work.proofs))
        ~f:completed_work_to_scanable_work
    in
    Parallel_scan.fill_in_completed_jobs state scanable_work_list

  let enqueue_data_with_rollback state data : unit Result_with_rollback.t =
    Result_with_rollback.of_or_error @@ Parallel_scan.enqueue_data state data

  let sum_fees xs ~f =
    with_return (fun {return} ->
        Ok
          (List.fold ~init:Fee.Unsigned.zero xs ~f:(fun acc x ->
               match Fee.Unsigned.add acc (f x) with
               | None -> return (Or_error.error_string "Fee overflow")
               | Some res -> res )) )

  let apply_super_transaction_and_get_statement ledger s =
    let open Or_error.Let_syntax in
    let%bind fee_excess = Super_transaction.fee_excess s in
    let source = Ledger.merkle_root ledger in
    let%map undo = Ledger.apply_super_transaction ledger s in
    ( undo
    , { Ledger_proof_statement.source
      ; target= Ledger.merkle_root ledger
      ; fee_excess= Fee.Signed.of_unsigned fee_excess
      ; proof_type= `Base } )

  let apply_super_transaction_and_get_witness ledger s =
    let public_keys = function
      | Super_transaction.Fee_transfer t -> Fee_transfer.receivers t
      | Transaction t ->
          let t = (t :> Transaction.t) in
          [Transaction.sender t; Transaction.receiver t]
    in
    let open Or_error.Let_syntax in
    let%map undo, statement =
      apply_super_transaction_and_get_statement ledger s
    in
    let witness = Sparse_ledger.of_ledger_subset_exn ledger (public_keys s) in
    (undo, {Super_transaction_with_witness.transaction= s; witness; statement})

  let update_ledger_and_get_statements ledger ts =
    let undo_transactions undos =
      List.iter undos ~f:(fun u -> Or_error.ok_exn (Ledger.undo ledger u))
    in
    let rec go processed acc = function
      | [] ->
          Deferred.return
            { Result_with_rollback.result= Ok (List.rev acc)
            ; rollback= Call (fun () -> undo_transactions processed) }
      | t :: ts ->
        match apply_super_transaction_and_get_witness ledger t with
        | Error e ->
            undo_transactions processed ;
            Result_with_rollback.error e
        | Ok (undo, res) -> go (undo :: processed) (res :: acc) ts
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

  let create_fee_transfers completed_works delta public_key =
    let singles =
      (if Fee.Unsigned.(equal zero delta) then [] else [(public_key, delta)])
      @ List.map completed_works ~f:(fun {Completed_work.fee; prover} ->
            (prover, fee) )
    in
    Or_error.try_with (fun () ->
        Public_key.Map.of_alist_reduce singles ~f:(fun f1 f2 ->
            Option.value_exn (Fee.Unsigned.add f1 f2) )
        (* TODO: This creates a weird incentive to have a small public_key *)
        |> Map.to_alist ~key_order:`Increasing
        |> Fee_transfer.of_single_list )

  let fee_remainder (payments: Transaction.With_valid_signature.t list)
      completed_works =
    let open Or_error.Let_syntax in
    let%bind budget =
      sum_fees payments ~f:(fun t -> Transaction.fee (t :> Transaction.t))
    in
    let%bind work_fee =
      sum_fees completed_works ~f:(fun {Completed_work.fee; _} -> fee)
    in
    option "budget did not suffice" (Fee.Unsigned.sub budget work_fee)

  (* TODO: This must be updated when we add coinbases *)
  (* TODO: when we move to a disk-backed db, this should call "Ledger.commit_changes" at the end. *)
  let apply_diff t (diff: Ledger_builder_diff.t) =
    let open Result_with_rollback.Let_syntax in
    let%bind payments =
      List.fold_until diff.transactions ~init:[]
        ~f:(fun acc t ->
          match Transaction.check t with
          | Some t -> Continue (t :: acc)
          | None ->
              (* TODO: punish *)
              Stop (Or_error.error_string "Bad signature") )
        ~finish:Or_error.return
      |> Result_with_rollback.of_or_error
    in
    let completed_works = diff.completed_works in
    let%bind () =
      let curr_hash = hash t in
      check
        (sprintf
           !"bad prev_hash: Expected %{sexp:Ledger_builder_hash.t}, got \
             %{sexp:Ledger_builder_hash.t}"
           curr_hash diff.prev_hash)
        (Ledger_builder_hash.equal diff.prev_hash (hash t))
      |> Result_with_rollback.of_or_error
    in
    let%bind delta =
      fee_remainder payments completed_works
      |> Result_with_rollback.of_or_error
    in
    let%bind fee_transfers =
      create_fee_transfers completed_works delta t.public_key
      |> Result_with_rollback.of_or_error
    in
    let super_transactions =
      List.map payments ~f:(fun t -> Super_transaction.Transaction t)
      @ List.map fee_transfers ~f:(fun t -> Super_transaction.Fee_transfer t)
    in
    let%bind new_data =
      update_ledger_and_get_statements t.ledger super_transactions
    in
    let%bind () = check_completed_works t completed_works in
    let%bind res_opt =
      (* TODO: Add rollback *)
      let r = fill_in_completed_work t.scan_state completed_works in
      Or_error.iter_error r ~f:(fun e ->
          (* TODO: Pass a logger here *)
          eprintf !"Unexpected error: %s %{sexp:Error.t}\n%!" __LOC__ e ) ;
      Result_with_rollback.of_or_error r
    in
    let%map () =
      (* TODO: Add rollback *)
      enqueue_data_with_rollback t.scan_state new_data
    in
    Option.map res_opt ~f:(fun (snark, _stmt) -> snark)

  let apply t witness = Result_with_rollback.run (apply_diff t witness)

  let apply_diff_unchecked t
      (diff: Ledger_builder_diff.With_valid_signatures_and_proofs.t) =
    let payments = diff.transactions in
    let completed_works =
      List.map ~f:Completed_work.forget diff.completed_works
    in
    let delta = Or_error.ok_exn (fee_remainder payments completed_works) in
    let fee_transfers =
      Or_error.ok_exn (create_fee_transfers completed_works delta t.public_key)
    in
    let super_transactions =
      List.map payments ~f:(fun t -> Super_transaction.Transaction t)
      @ List.map fee_transfers ~f:(fun t -> Super_transaction.Fee_transfer t)
    in
    let new_data =
      List.map super_transactions ~f:(fun s ->
          let _undo, t =
            Or_error.ok_exn
              (apply_super_transaction_and_get_witness t.ledger s)
          in
          t )
    in
    let res_opt =
      Or_error.ok_exn (fill_in_completed_work t.scan_state completed_works)
    in
    Or_error.ok_exn
      (Parallel_scan.enqueue_data ~state:t.scan_state ~data:new_data) ;
    res_opt

  let free_space t : int = Parallel_scan.free_space t.scan_state

  let sequence_chunks_of seq ~n =
    Sequence.unfold_step ~init:([], 0, seq) ~f:(fun (acc, i, seq) ->
        if i = n then Yield (List.rev acc, ([], 0, seq))
        else
          match Sequence.next seq with
          | None -> Done
          | Some (x, seq) -> Skip (x :: acc, i + 1, seq) )

  let split_n_filter_map seq n ~f =
    let rec go i acc seq =
      if i = n then (List.rev acc, seq)
      else
        match Sequence.next seq with
        | None -> (List.rev acc, seq)
        | Some (x, seq') ->
          match f x with
          | None -> go i acc seq'
          | Some y -> go (i + 1) (y :: acc) seq'
    in
    go 0 [] seq

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
      type t = {fee_transfers: Public_key.Set.t; transactions: int}
      [@@deriving sexp]

      let count {fee_transfers; transactions} =
        (* This is ceil(Set.length fee_transfers / 2) *)
        transactions + ((Set.length fee_transfers + 1) / 2)

      let add_transaction t = {t with transactions= t.transactions + 1}

      let add_fee_transfer t public_key =
        {t with fee_transfers= Set.add t.fee_transfers public_key}

      let ( + ) t1 t2 =
        { fee_transfers= Set.union t1.fee_transfers t2.fee_transfers
        ; transactions= t1.transactions + t2.transactions }

      let empty = {transactions= 0; fee_transfers= Public_key.Set.empty}
    end

    type t =
      { budget: Fee.Unsigned.t
      ; queue_consumption: Queue_consumption.t
      ; available_queue_space: int
      ; transactions: (Transaction.With_valid_signature.t * Ledger.Undo.t) list
      ; completed_works: Completed_work.Checked.t list }
    [@@deriving sexp]

    let add_transaction t ((txv: Transaction.With_valid_signature.t), undo) =
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
      else
        Ok
          { t with
            budget
          ; queue_consumption
          ; transactions= (txv, undo) :: t.transactions }

    let add_work t (wc: Completed_work.Checked.t) =
      let open Or_error.Let_syntax in
      let w = Completed_work.forget wc in
      let%bind budget = option "overflow" (Fee.Unsigned.sub t.budget w.fee) in
      let queue_consumption =
        Queue_consumption.add_fee_transfer t.queue_consumption w.prover
      in
      if Queue_consumption.count queue_consumption > t.available_queue_space
      then Or_error.error_string "Insufficient space"
      else
        Ok
          { t with
            budget; queue_consumption; completed_works= wc :: t.completed_works
          }

    let empty ~available_queue_space =
      { available_queue_space
      ; queue_consumption= Queue_consumption.empty
      ; budget= Fee.Unsigned.zero
      ; transactions= []
      ; completed_works= [] }
  end

  let fold_until_error xs ~init ~f =
    List.fold_until xs ~init
      ~f:(fun acc x ->
        match f acc x with Ok acc -> Continue acc | Error _ -> Stop acc )
      ~finish:Fn.id

  let fold_sequence_until_error seq ~init ~f =
    let rec go (processed, acc) seq =
      let finish () =
        match processed with
        | `Processed_none -> `Processed_none
        | `At_least_one -> `Processed_at_least_one (acc, seq)
      in
      match Sequence.next seq with
      | None -> finish ()
      | Some (x, seq') ->
        match f acc x with
        | `Ok acc -> go (`At_least_one, acc) seq'
        | `Error e -> finish ()
        | `Skip -> go (processed, acc) seq'
    in
    go (`Processed_none, init) seq

  let uncons_exn = function [] -> failwith "uncons_exn" | x :: xs -> (x, xs)

  let create_diff t
      ~(transactions_by_fee: Transaction.With_valid_signature.t Sequence.t)
      ~(get_completed_work:
         Completed_work.Statement.t -> Completed_work.Checked.t option) =
    (* TODO: Don't copy *)
    let curr_hash = hash t in
    let t = copy t in
    let ledger = ledger t in
    let or_error = function Ok x -> `Ok x | Error e -> `Error e in
    let add_work resources work_to_do =
      fold_sequence_until_error work_to_do ~init:resources ~f:
        (fun resources w ->
          match get_completed_work w with
          | Some w ->
              (* TODO: There is a subtle error here.
               You should not add work if it would cause the person's
               balance to overflow *)
              or_error (Resources.add_work resources w)
          | None -> `Error (Error.of_string "Work not found") )
    in
    let add_transactions resources transactions_to_do =
      fold_sequence_until_error transactions_to_do ~init:resources ~f:
        (fun resources txn ->
          match Ledger.apply_super_transaction ledger (Transaction txn) with
          | Error _ -> `Skip
          | Ok undo ->
            match Resources.add_transaction resources (txn, undo) with
            | Ok resources -> `Ok resources
            | Error e ->
                Or_error.ok_exn (Ledger.undo ledger undo) ;
                `Error e )
    in
    let rec add_many_work ~adding_transactions_failed resources ts_seq ws_seq =
      match add_work resources ws_seq with
      | `Processed_at_least_one (resources, ws_seq) ->
          add_many_transaction ~adding_work_failed:false resources ts_seq
            ws_seq
      | `Processed_none ->
          if adding_transactions_failed then resources
          else
            add_many_transaction ~adding_work_failed:true resources ts_seq
              ws_seq
    and add_many_transaction ~adding_work_failed resources ts_seq ws_seq =
      match add_transactions resources ts_seq with
      | `Processed_at_least_one (resources, ts_seq) ->
          add_many_work ~adding_transactions_failed:false resources ts_seq
            ws_seq
      | `Processed_none ->
          if adding_work_failed then resources
          else
            add_many_work ~adding_transactions_failed:true resources ts_seq
              ws_seq
    in
    let resources, t_rest =
      let resources = Resources.empty ~available_queue_space:(free_space t) in
      let ts_with_undos, t_rest =
        split_n_filter_map transactions_by_fee resources.available_queue_space
          ~f:(fun txn ->
            match Ledger.apply_super_transaction ledger (Transaction txn) with
            | Error _ -> None
            | Ok undo -> Some (txn, undo) )
      in
      let ts, undos = List.unzip ts_with_undos in
      let resources, undos_of_unapplied =
        fold_until_error ts ~init:(resources, undos) ~f:
          (fun (res, remaining_undos) txn ->
            let undo, remaining_undos = uncons_exn remaining_undos in
            match Resources.add_transaction res (txn, undo) with
            | Error e -> Error e
            | Ok res -> Ok (res, remaining_undos) )
      in
      List.iter (List.rev undos_of_unapplied) ~f:(fun u ->
          Or_error.ok_exn (Ledger.undo ledger u) ) ;
      (resources, t_rest)
    in
    let resources =
      add_many_work ~adding_transactions_failed:false resources t_rest
        (work_to_do t.scan_state)
    in
    let transactions =
      List.rev_map resources.transactions ~f:(fun (t, u) ->
          Or_error.ok_exn (Ledger.undo ledger u) ;
          t )
    in
    let diff =
      { (* We have to reverse here because we only know they work in THIS order *)
      Ledger_builder_diff.With_valid_signatures_and_proofs.transactions
      ; completed_works= List.rev resources.completed_works
      ; creator= t.public_key
      ; prev_hash= curr_hash }
    in
    let ledger_proof = apply_diff_unchecked t diff in
    (diff, `Hash_after_applying (hash t), `Ledger_proof ledger_proof)
end

let%test_module "ledger_builder" =
  ( module struct
    
  end )
