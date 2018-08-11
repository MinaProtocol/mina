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
    let single_spec (job: job) =
      match job with
      | A.Base d ->
          Snark_work_lib.Work.Single.Spec.Transition
            (d.statement, d.transaction, d.witness)
      | A.Merge ((p1, s1), (p2, s2)) ->
          let merged = merge_statement s1 s2 |> Or_error.ok_exn in
          Snark_work_lib.Work.Single.Spec.Merge (merged, p1, p2)
    in
    let n = List.length jobs in
    match jobs with
    | [] -> None
    | [j] -> Some [single_spec j]
    | _ ->
        (* TODO: Should we break these up in such a way that the following
       * situation can't happen:
       * A gets 0,1 ; B gets 1,2
       * Essentially you "can't" buy B if you buy A
       *)
        let i = Random.int n in
        let chunk = [List.nth_exn jobs i; List.nth_exn jobs ((i + 1) % n)] in
        Some (List.map chunk ~f:single_spec)

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

  (*let of_aux_and_ledger ~self ledger scan_state =
    (* TODO: Actually check the validity? *)
    {scan_state; ledger; public_key= self} *)

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
    | Merge ((_, s), (_, s')) ->
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

  let total_proofs (works: Completed_work.t list) =
    List.sum (module Int) works ~f:(fun w -> List.length w.proofs)

  let fill_in_completed_work (state: scan_state) (works: Completed_work.t list)
      : Ledger_proof.t with_statement option Or_error.t =
    let open Or_error.Let_syntax in
    let%bind next_jobs =
      Parallel_scan.next_k_jobs ~state
        ~k:(total_proofs works )
    in
    let%bind scanable_work_list =
      map2_or_error next_jobs
        (List.concat_map works ~f:(fun work -> work.proofs))
        ~f:completed_work_to_scanable_work
    in
    Parallel_scan.fill_in_completed_jobs ~state ~completed_jobs:scanable_work_list

  let enqueue_data_with_rollback state data : unit Result_with_rollback.t =
    Result_with_rollback.of_or_error @@ Parallel_scan.enqueue_data ~state ~data

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


  (*let chunks_of_jobs jobs (works: Completed_work.t list) =
    let jobses, _ =
      List.fold works ~init:([], jobs) ~f:(fun (jobses, jobs) _ ->
      let js, rem = List.split_n jobs Completed_work.proofs_length in
      (js :: jobses, rem))
      (*if List.empty jobs then (jobses, [])
          else
            ( List.take jobs (List.length w.proofs) :: jobses
            , List.drop jobs (List.length w.proofs) ) )*)
    in
    List.rev jobses*)

    

  let check_completed_works t (completed_works: Completed_work.t list) =
    Result_with_rollback.with_no_rollback
      (let open Deferred.Or_error.Let_syntax in
      let%bind jobses =
        Deferred.return
          (let open Or_error.Let_syntax in
          let%map jobs =
            Parallel_scan.next_k_jobs ~state:t.scan_state
              ~k:
                (total_proofs completed_works)
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
      @ List.map completed_works ~f:(fun {Completed_work.fee; prover;_} ->
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

  let free_space t : int = Parallel_scan.free_space ~state:t.scan_state

  let sequence_chunks_of seq ~n =
    Sequence.unfold_step ~init:([], 0, seq) ~f:(fun (acc, i, seq) ->
      if i = n then Yield (List.rev acc, ([], 0, seq))
      else
        match Sequence.next seq with
        | None          -> Done
        | Some (x, seq) -> 
          (*allow chunks of 1 proof as well*)
          match Sequence.next seq with
          | None ->  Yield (List.rev (x::acc), ([], 0, seq))
          | _    ->  Skip (x :: acc, i + 1, seq))


        (*if i > 0 && i < n && Sequence.length seq = 0 then
          Yield (List.rev acc, ([], n + 1, seq))
        else if i = n then Yield (List.rev acc, ([], 0, seq))
        else
          match Sequence.next seq with
          | None -> Done
          | Some (x, seq) -> Skip (x :: acc, i + 1, seq)*)

  (*let split_n_filter_map seq n ~f =
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
    go 0 [] seq*)

  (* TODO: Make this actually return a sequence *)
  let work_to_do scan_state : Completed_work.Statement.t Sequence.t =
    let work_list = Parallel_scan.next_jobs ~state:scan_state in
    sequence_chunks_of ~n:Completed_work.proofs_length
    @@ Sequence.of_list
    @@ List.map work_list ~f:(fun maybe_work ->
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

      (*let ( + ) t1 t2 =
        { fee_transfers= Set.union t1.fee_transfers t2.fee_transfers
        ; transactions= t1.transactions + t2.transactions }*)

      let init ~self = {transactions= 0; fee_transfers= Public_key.Set.singleton self}
    end

    type t =
      { budget: Fee.Signed.t
      ; queue_consumption: Queue_consumption.t
      ; available_queue_space: int
      ; max_throughput: int
      ; work_done: int
      ; transactions: (Transaction.With_valid_signature.t * Ledger.Undo.t) list
      ; completed_works: Completed_work.Checked.t list }
    [@@deriving sexp]

    let space_available t =
      Queue_consumption.count t.queue_consumption < t.max_throughput

    let budget_non_neg t = Fee.Signed.sgn t.budget = Sgn.Pos

    let add_transaction t ((txv: Transaction.With_valid_signature.t), undo) =
      let tx = (txv :> Transaction.t) in
      let open Or_error.Let_syntax in
      let%bind budget =
        option "overflow"
          (Fee.Signed.add t.budget
             (Fee.Signed.of_unsigned @@ Transaction.fee tx))
      in
      let queue_consumption =
        Queue_consumption.add_transaction t.queue_consumption
      in
      if not (space_available t) then
        Or_error.error_string "Insufficient space"
      else
        Ok
          { t with
            budget
          ; queue_consumption
          ; transactions= (txv, undo) :: t.transactions }

    (*let enough_work_added t new_txns =
      t.work_done
      = (Queue_consumption.count t.queue_consumption + new_txns) * 2*)

    let add_work t (wc: Completed_work.Checked.t) =
      let open Or_error.Let_syntax in
      let w = Completed_work.forget wc in
      let%bind budget =
        option "overflow"
          (Fee.Signed.add t.budget
             (Fee.Signed.negate @@ Fee.Signed.of_unsigned w.fee))
      in
      let queue_consumption =
        Queue_consumption.add_fee_transfer t.queue_consumption w.prover
      in
      Ok
        { t with
          budget
        ; queue_consumption
        ; work_done= t.work_done + List.length w.proofs
        ; completed_works= wc :: t.completed_works }

    let init ~available_queue_space ~max_throughput ~self=
      { available_queue_space
      ; max_throughput
      ; work_done= 0
      ; queue_consumption= Queue_consumption.init ~self
      ; budget= Fee.Signed.zero
      ; transactions= []
      ; completed_works= [] }
  end

  (*let fold_until_error xs ~init ~f =
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
        | `Error _ -> finish ()
        | `Skip -> go (processed, acc) seq'
    in
    go (`Processed_none, init) seq

  let uncons_exn = function [] -> failwith "uncons_exn" | x :: xs -> (x, xs)*)

  let add_work work resources get_completed_work =
    match get_completed_work work with
    | Some w ->
        (* TODO: There is a subtle error here.
               You should not add work if it would cause the person's
               balance to overflow *)
        Resources.add_work resources w
    | None -> Error (Error.of_string "Work not found")

  let add_transaction ledger txn resources =
    match Ledger.apply_super_transaction ledger (Transaction txn) with
    | Error _ -> Ok resources
    | Ok undo ->
      match Resources.add_transaction resources (txn, undo) with
      | Ok resources -> Ok resources
      | Error e ->
          Or_error.ok_exn (Ledger.undo ledger undo) ;
          Error e

  let txns_not_included (valid: Resources.t) (invalid: Resources.t) =
    let diff =
      List.length valid.transactions - List.length invalid.transactions
    in
    if diff > 0 then List.take invalid.transactions diff else []

  let log_error_and_return_value err_val def_val =
    match err_val with
    | Error e ->
        Printf.printf "%s" (Error.to_string_hum e) ;
        def_val
    | Ok value -> value

  let rec check_resources_and_add ws_seq ts_seq get_completed_work ledger
      (valid: Resources.t) (resources: Resources.t) =
    match
      ( Sequence.next ws_seq
      , Sequence.next ts_seq
      , Resources.space_available resources )
    with
    | None, None, _ -> (valid, txns_not_included valid resources)
    | None, Some (t, ts), true ->
        let r_transaction =
          log_error_and_return_value
            (add_transaction ledger t resources)
            resources
        in
        if Resources.budget_non_neg r_transaction then
          check_resources_and_add Sequence.empty ts get_completed_work ledger
            r_transaction r_transaction
        else
          check_resources_and_add Sequence.empty ts get_completed_work ledger
            valid r_transaction
    | Some (w, ws), Some (t, ts), true ->
        let enough_work_added = resources.work_done = (Resources.Queue_consumption.count resources.queue_consumption + 1) * 2 in
        if enough_work_added then
          let r_transaction =
            log_error_and_return_value
              (add_transaction ledger t resources)
              resources
          in
          if Resources.budget_non_neg r_transaction then
            check_resources_and_add
              (Sequence.append (Sequence.singleton w) ws)
              ts get_completed_work ledger r_transaction r_transaction
          else
            check_resources_and_add
              (Sequence.append (Sequence.singleton w) ws)
              ts get_completed_work ledger valid r_transaction
        else
          let r_work =
            log_error_and_return_value
              (add_work w resources get_completed_work)
              resources
          in
          check_resources_and_add ws
            (Sequence.append (Sequence.singleton t) ts)
            get_completed_work ledger valid r_work
    | _, _, _ -> (valid, txns_not_included valid resources)

  let undo_txns ledger txns =
    List.map txns ~f:(fun _ (t, u) ->
        Or_error.ok_exn (Ledger.undo ledger u) ;
        t )

  let process_works_add_txns ws_seq ts_seq ps_free_space max_throughput
      get_completed_work ledger self: Resources.t =
    let resources =
      Resources.init ~available_queue_space:ps_free_space ~max_throughput ~self
    in
    let valid, txns_to_undo =
      check_resources_and_add ws_seq ts_seq get_completed_work ledger resources
        resources
    in
    let _ = undo_txns ledger txns_to_undo in
    valid

  let create_diff t
      ~(transactions_by_fee: Transaction.With_valid_signature.t Sequence.t)
      ~(get_completed_work:
         Completed_work.Statement.t -> Completed_work.Checked.t option) =
    (* TODO: Don't copy *)
    let curr_hash = hash t in
    let t' = copy t in
    let ledger = ledger t' in
    let max_throughput = Int.pow 2 (Inputs.Config.parallelism_log_2 - 1) in
    let resources =
      process_works_add_txns (work_to_do t'.scan_state) transactions_by_fee
        (free_space t') max_throughput get_completed_work ledger t.public_key
    in
    (* We have to reverse here because we only know they work in THIS order *)
    let transactions =
      List.rev_map resources.transactions ~f:(fun (t, u) ->
          Or_error.ok_exn (Ledger.undo ledger u) ;
          t )
    in
    let diff =
      { 
      Ledger_builder_diff.With_valid_signatures_and_proofs.transactions
      ; completed_works= List.rev resources.completed_works
      ; creator= t'.public_key
      ; prev_hash= curr_hash }
    in
    let ledger_proof = apply_diff_unchecked t' diff in
    (diff, `Hash_after_applying (hash t'), `Ledger_proof ledger_proof)
end

let%test_module "test" =
  ( module struct
    module Test_input1 = struct
      open Coda_pow

      module Public_key = String (*struct
        type t = string [@@deriving sexp, bin_io, compare]

        include Comparable.Make (struct
          type t = string [@@deriving sexp, bin_io, compare]
        end)
      end*)

      module Transaction = struct
        type fee = Fee.Unsigned.t [@@deriving sexp, bin_io, compare ]

        type txn_amt = int [@@deriving sexp, bin_io, compare, eq]

        type txn_fee = int [@@deriving sexp, bin_io, compare, eq]

        module T = struct
          type t = txn_amt * txn_fee [@@deriving sexp, bin_io, compare, eq]
        end

        include T

        module With_valid_signature = struct
          type t = T.t [@@deriving sexp, bin_io, compare, eq]
        end

        let check : t -> With_valid_signature.t option = fun i -> Some i

        let fee : t -> Fee.Unsigned.t = fun t -> Fee.Unsigned.of_int (snd t)

        (*Fee excess*)
        let sender _ = "S"

        let receiver _ = "R"
      end

      module Fee_transfer = struct
        type public_key = Public_key.t [@@deriving sexp, bin_io, compare, eq]

        type fee = Fee.Unsigned.t [@@deriving sexp, bin_io, compare, eq]

        type single = public_key * fee [@@deriving bin_io, sexp, compare, eq]

        type t = One of single | Two of single * single
        [@@deriving bin_io, sexp, compare, eq]

        let to_list = function One x -> [x] | Two (x, y) -> [x; y]

        let of_single_list xs =
          let rec go acc = function
            | x1 :: x2 :: xs -> go (Two (x1, x2) :: acc) xs
            | [] -> acc
            | [x] -> One x :: acc
          in
          go [] xs

        let fee_excess t : fee Or_error.t = match t with
          | One (_, fee) -> Ok fee
          | Two ((_, fee1), (_, fee2)) ->
            match Fee.Unsigned.add fee1 fee2 with
            | None -> Or_error.error_string "Fee_transfer.fee_excess: overflow"
            | Some res -> Ok res

        let fee_excess_int t = Fee.Unsigned.to_int (Or_error.ok_exn @@ fee_excess t)

        (*function
          | One (_, fee) -> Ok (Fee.Unsigned.to_int fee)
          | Two ((_, fee1), (_, fee2)) ->
              let f1 = Fee.Unsigned.to_int fee1 in
              let f2 = Fee.Unsigned.to_int fee2 in
              match Some (f1 + f2) with
              | None ->
                  Or_error.error_string "Fee_transfer.fee_excess: overflow"
              | Some res -> Ok res*)

        let receivers t = List.map (to_list t) ~f:(fun (pk, _) -> pk)
      end

      module Super_transaction = struct
        type valid_transaction = Transaction.With_valid_signature.t
        [@@deriving sexp, bin_io, compare, eq]

        type fee_transfer = Fee_transfer.t
        [@@deriving sexp, bin_io, compare, eq]

        type unsigned_fee = Fee.Unsigned.t
        [@@deriving sexp, bin_io, compare]

        type t =
          | Transaction of valid_transaction
          | Fee_transfer of fee_transfer
        [@@deriving sexp, bin_io, compare, eq]

        let fee_excess : t -> unsigned_fee Or_error.t =
         fun t ->
          match t with
          | Transaction t' -> Ok (Transaction.fee t')
          | Fee_transfer f -> Fee_transfer.fee_excess f
      end

      module Ledger_hash = struct
        include String

        let to_bytes : t -> string = fun t -> t
      end

      module Ledger_proof_statement = struct
        type t =
          { source: Ledger_hash.t
          ; target: Ledger_hash.t
          ; fee_excess: Fee.Signed.t
          ; proof_type: [`Base | `Merge] }
        [@@deriving sexp, bin_io, compare, eq]
      end

      module Ledger_proof = struct
        (*A proof here is statement.target*)
        include String

        type statement = Ledger_proof_statement.t

        type ledger_hash = Ledger_hash.t

        let verify (_:t) (_:statement)  ~message:_ : bool Deferred.t 
          = return true

        let statement_target : statement -> ledger_hash =
         fun statement -> statement.target
      end

      module Ledger = struct
        type t = int ref [@@deriving sexp, bin_io, compare]

        type ledger_hash = Ledger_hash.t

        type super_transaction = Super_transaction.t [@@deriving sexp]

        let hash : t -> Ppx_hash_lib.Std.Hash.hash_value = fun t -> !t

        let hash_fold_t :
            Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state =
         fun s _ -> s

        module Undo = struct
          type t = super_transaction [@@deriving sexp]
        end

        (*let undo_transaction : t -> valid_transaction -> unit Or_error.t =
         fun t v ->
          t := !t - fst v ;
          Or_error.return ()*)

        let create : unit -> t = fun () -> ref 0

        let copy : t -> t = fun t -> ref !t

        let merkle_root : t -> ledger_hash = fun t -> Int.to_string !t

        (*let apply_transaction : t -> valid_transaction -> unit Or_error.t =
         fun t v ->
          t := !t + fst v ;
          Or_error.return ()*)

        let apply_super_transaction : t -> Undo.t -> Undo.t Or_error.t =
         fun t s ->
          match s with
          | Transaction t' ->
              t := !t + fst t' ;
              Or_error.return (Super_transaction.Transaction t')
          | Fee_transfer f ->
              let t' = Fee_transfer.fee_excess_int f in
              t := !t + t' ;
              Or_error.return (Super_transaction.Fee_transfer f)

        let undo_super_transaction : t -> super_transaction -> unit Or_error.t =
         fun t s ->
          let v =
            match s with
            | Transaction t' -> fst t'
            | Fee_transfer f -> Fee_transfer.fee_excess_int f
          in
          t := !t - v ;
          Or_error.return ()

        let undo t (txn: Undo.t) = undo_super_transaction t txn
      end

      module Sparse_ledger = struct
        type t = int [@@deriving sexp, bin_io]

        let of_ledger_subset_exn : Ledger.t ->  Public_key.t list -> t =
          fun ledger _ -> !ledger
      end

      module Ledger_builder_aux_hash = struct
        include String

        let of_bytes : string -> t = fun s -> s

      end

      module Ledger_builder_hash = struct
        include String
        
        type ledger_hash = Ledger_hash.t

        type ledger_builder_aux_hash = Ledger_builder_aux_hash.t

        (*module T = struct
          type t = string [@@deriving sexp, bin_io, compare, hash]
        end

        include T

        let equal = String.equal

        include Hashable.Make_binable (T)*)

        let of_bytes : string -> t = fun s -> s

        let of_aux_and_ledger_hash :
            ledger_builder_aux_hash -> ledger_hash -> t =
         fun ah h -> ah ^ h
      end

      module Completed_work = struct
        type proof = Ledger_proof.t [@@deriving sexp, bin_io, compare]

        type statement = Ledger_proof_statement.t
        [@@deriving sexp, bin_io, compare]

        type fee = Fee.Unsigned.t [@@deriving sexp, bin_io, compare]

        type public_key = Public_key.t [@@deriving sexp, bin_io, compare]

        type t = {fee: fee; proofs: proof list; prover: public_key}
        [@@deriving sexp, bin_io, compare]

        module Statement = struct
          type t = statement list [@@deriving sexp, bin_io, compare]
        end

        module Checked = struct
          type t = {fee: fee; proofs: proof list; prover: public_key}
          [@@deriving sexp, bin_io, compare]
        end

        let check : t -> Statement.t -> Checked.t option Deferred.t =
         fun {fee= f; proofs= p; prover= pr} _ ->
          Deferred.return @@ Some {Checked.fee= f; proofs= p; prover= pr}

        let proofs_length = 2

        let forget : Checked.t -> t =
         fun {Checked.fee= f; proofs= p; prover= pr} ->
          {fee= f; proofs= p; prover= pr}
      end

      module Ledger_builder_diff = struct
        type completed_work = Completed_work.t
        [@@deriving sexp, bin_io, compare]

        type completed_work_checked = Completed_work.Checked.t
        [@@deriving sexp, bin_io, compare]

        type transaction = Transaction.t [@@deriving sexp, bin_io, compare]

        type transaction_with_valid_signature =
          Transaction.With_valid_signature.t
        [@@deriving sexp, bin_io, compare]

        type public_key = Public_key.t [@@deriving sexp, bin_io, compare]

        type ledger_builder_hash = Ledger_builder_hash.t
        [@@deriving sexp, bin_io, compare]

        type t =
          { prev_hash: ledger_builder_hash
          ; completed_works: completed_work list
          ; transactions: transaction list
          ; creator: public_key }
        [@@deriving sexp, bin_io, compare]

        module With_valid_signatures_and_proofs = struct
          type t =
            { prev_hash: ledger_builder_hash
            ; completed_works: completed_work_checked list
            ; transactions: transaction_with_valid_signature list
            ; creator: public_key }
          [@@deriving sexp, bin_io, compare]
        end

        let forget : With_valid_signatures_and_proofs.t -> t =
         fun { With_valid_signatures_and_proofs.prev_hash
             ; completed_works
             ; transactions
             ; creator } ->
          { prev_hash
          ; completed_works= List.map completed_works ~f:Completed_work.forget
          ; transactions= (transactions :> Transaction.t list)
          ; creator }
      end

      module Config = struct
        let parallelism_log_2 = 6
      end
    end

    module Lb = Make (Test_input1)

    let self_pk = "me"

    (*let initial_statement : Test_input1.Ledger_proof_statement.t =
      {source= 0; target= 0; fee_excess= Fee.Signed.zero; proof_type= `Base}

    let seed_statement : Test_input1.Ledger_proof_statement.t =
      { source= 0
      ; target= 1
      ; fee_excess= Fee.Signed.of_unsigned (Fee.Unsigned.of_int 1)
      ; proof_type= `Base }

    let initial_proof : Test_input1.Ledger_proof.t =
      Fee.Unsigned.to_string
      @@ Fee.Signed.magnitude initial_statement.fee_excess*)

    let stmt_to_work (stmts: Test_input1.Completed_work.Statement.t) :
        Test_input1.Completed_work.Checked.t option =
      let proofs = List.map stmts ~f:(fun stmt -> stmt.target) in
      let prover =
        List.fold stmts ~init:"P" ~f:(fun p stmt ->
            p ^ stmt.target )
      in
      Some
        { Test_input1.Completed_work.Checked.fee= Fee.Unsigned.of_int 1
        ; proofs
        ; prover }

    (*let chunks_of xs ~n = List.groupi xs ~break:(fun i _ _ -> i mod n = 0)*)

    let create_and_apply lb txns =
      let diff, _, _ = Lb.create_diff lb ~transactions_by_fee:txns ~get_completed_work:stmt_to_work in
      let%map ledger_proof =
        Lb.apply lb (Test_input1.Ledger_builder_diff.forget diff)
      in
      (ledger_proof, Test_input1.Ledger_builder_diff.forget diff)

    let txns n f g = List.zip_exn (List.init n ~f) (List.init n ~f:g)

    let%test_unit "Max throughput" =
      (*Always at worst case number of provers*)
      let p = Int.pow 2 Test_input1.Config.parallelism_log_2 in
      let g = Int.gen_incl 1 p in
      let initial_ledger = ref 0 in
      let lb = Lb.create ~ledger:initial_ledger ~self:self_pk in
      Quickcheck.test g ~trials:1000 ~f:(fun _ ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              let open Deferred.Let_syntax in
              let old_ledger = !(Lb.ledger lb) in
              let all_ts =
                txns (p / 2) (fun x -> (x + 1) * 100) (fun _ -> 4)
              in
              let%map _, diff =
                create_and_apply lb (Sequence.of_list all_ts)
              in
              let x = List.length diff.transactions in
              assert (x > 0) ;
              let expected_value =
                old_ledger
                + List.fold (List.take all_ts x) ~init:0 ~f:(fun s (t, fee) ->
                      s + t + fee )
              in
              assert (!(Lb.ledger lb) = expected_value) ) )

    let%test_unit "Be able to include random number of transactions" =
      (*Always at worst case number of provers*)
      Backtrace.elide := false ;
      let p = Int.pow 2 Test_input1.Config.parallelism_log_2 in
      let g = Int.gen_incl 1 p in
      let initial_ledger = ref 0 in
      let lb = Lb.create ~ledger:initial_ledger ~self:self_pk in
      Quickcheck.test g ~trials:1000 ~f:(fun i ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              let open Deferred.Let_syntax in
              let old_ledger = !(Lb.ledger lb) in
              let all_ts = txns p (fun x -> (x + 1) * 100) (fun _ -> 4) in
              let ts = List.take all_ts i in
              let%map _, diff =
                create_and_apply lb (Sequence.of_list ts)
              in
              let x = List.length diff.transactions in
              assert (x > 0) ;
              let expected_value =
                old_ledger
                + List.fold (List.take all_ts x) ~init:0 ~f:(fun s (t, fee) ->
                      s + t + fee )
              in
              Printf.printf "Expected value %d \n" expected_value;
              assert (!(Lb.ledger lb) = expected_value) ) )
  end )
