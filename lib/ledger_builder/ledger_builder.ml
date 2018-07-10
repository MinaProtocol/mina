open Core_kernel
open Async_kernel
open Protocols

module type Inputs_intf = sig
  module Fee : sig
    module Unsigned : sig
      type t [@@deriving sexp_of, eq]

      val add : t -> t -> t option

      val sub : t -> t -> t option

      val zero : t
    end

    module Signed : sig
      type t [@@deriving sexp_of]

      val add : t -> t -> t option

      val negate : t -> t

      val of_unsigned : Unsigned.t -> t
    end
  end

  module Public_key : Coda_pow.Public_key_intf

  module Transaction :
    Coda_pow.Transaction_intf with type fee := Fee.Unsigned.t

  module Fee_transfer :
    Coda_pow.Fee_transfer_intf
    with type public_key := Public_key.Compressed.t
     and type fee := Fee.Unsigned.t

  module Super_transaction :
    Coda_pow.Super_transaction_intf
    with type valid_transaction := Transaction.With_valid_signature.t
     and type fee_transfer := Fee_transfer.t
     and type signed_fee := Fee.Signed.t

  module Ledger_proof : Coda_pow.Proof_intf

  module Ledger_hash : Coda_pow.Ledger_hash_intf

  module Snark_pool_proof : Coda_pow.Snark_pool_proof_intf

  module Transaction_snark :
    Coda_pow.Transaction_snark_intf
    with type fee := Fee.Signed.t
     and type ledger_hash := Ledger_hash.t
     and type message := Fee.Unsigned.t * Public_key.Compressed.t

  module Ledger :
    Coda_pow.Ledger_intf
    with type ledger_hash := Ledger_hash.t
     and type super_transaction := Super_transaction.t

  module Ledger_builder_hash : Coda_pow.Ledger_builder_hash_intf

  module Completed_work :
    Coda_pow.Completed_work_intf
    with type proof := Transaction_snark.t
     and type statement := Transaction_snark.Statement.t
     and type fee := Fee.Unsigned.t
     and type public_key := Public_key.Compressed.t

  module Ledger_builder_diff :
    Coda_pow.Ledger_builder_diff_intf
    with type completed_work := Completed_work.t
     and type transaction := Transaction.With_valid_signature.t
     and type public_key := Public_key.Compressed.t
     and type ledger_builder_hash := Ledger_builder_hash.t
end

module Make (Inputs : Inputs_intf) :
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
  (* Assume you have

  enqueue_data
  : Paralell_scan.State.t -> Transition,t list -> unit

  complete_jobs
  : Paralell_scan.State.t -> Accum.t list -> unit
  
  Alternatively,
  change the intf of parallel scan to take a function
  check_work : Job.t -> Accum.t -> bool Deferred,t

  and then have in parallel scan

  validate_and_apply_work
  : Parallel_scan.State.t -> Accum.t list -> unit Or_error.t Deferred.t

  *)

  open Inputs

  type 'a with_statement = 'a * Transaction_snark.Statement.t
  [@@deriving sexp, bin_io]

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

  module Job_hash = struct
    type t = job [@@deriving sexp_of]
  end

  let hash t : Ledger_builder_hash.t = failwith "TODO"

  let ledger t = failwith "TODO"

  let max_margin : int = failwith "TODO"

  let margin t : int = failwith "TODO"

  let create ~ledger ~self : t = failwith "TODO"

  (*
  module Spec = struct
    module Accum = struct
      type t = Proof.t With_statement.t [@@deriving sexp_of]

      let ( + ) t t' : t = failwith "TODO"
    end

    module Data = struct
      type t = transaction With_statement.t [@@deriving sexp_of]
    end

    module Output = struct
      type t = Proof.t With_statement.t [@@deriving sexp_of]
    end

    let merge t t' = t'

    let map (x: Data.t) : Accum.t =
      failwith
        "Create a transaction snark from a transaction. Needs to look up some \
         ds that stores all the proofs that the witness has"
  end

  let spec =
    ( module Spec
    : Parallel_scan.Spec_intf with type Data.t = transaction With_statement.t and type 
      Accum.t = Proof.t With_statement.t and type Output.t = Proof.t
                                                             With_statement.t
    ) *)

  let option lab =
    Option.value_map ~default:(Or_error.error_string lab) ~f:(fun x -> Ok x)

  let check label b = if not b then Or_error.error_string label else Ok ()

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

  module Result_with_rollback = struct
    module Rollback = struct
      type t = Do_nothing | Call of (unit -> unit)

      let compose t1 t2 =
        match (t1, t2) with
        | Do_nothing, t | t, Do_nothing -> t
        | Call f1, Call f2 -> Call (fun () -> f1 () ; f2 ())

      let run = function Do_nothing -> () | Call f -> f ()
    end

    module T = struct
      type 'a result = {result: 'a Or_error.t; rollback: Rollback.t}

      type 'a t = 'a result Deferred.t

      let return x = Deferred.return {result= Ok x; rollback= Do_nothing}

      let bind tx ~f =
        Deferred.bind tx ~f:(fun {result; rollback} ->
            match result with
            | Error e -> Deferred.return {result= Error e; rollback}
            | Ok x ->
                Deferred.map (f x) ~f:(fun ty ->
                    { result= ty.result
                    ; rollback= Rollback.compose rollback ty.rollback } ) )

      let map t ~f =
        Deferred.map t ~f:(fun res ->
            {res with result= Or_error.map ~f res.result} )

      let map = `Custom map
    end

    include T
    include Monad.Make (T)

    let run t =
      Deferred.map t ~f:(fun {result; rollback} ->
          Rollback.run rollback ; result )

    let error e = Deferred.return {result= Error e; rollback= Do_nothing}

    let of_or_error result = Deferred.return {result; rollback= Do_nothing}

    let with_no_rollback dresult =
      Deferred.map dresult ~f:(fun result -> {result; rollback= Do_nothing})
  end

  let rec mapM_2 = function
    | [], [] -> Ok []
    | job :: jobs', work :: works' ->
        let open Or_error.Let_syntax in
        let%bind scanable_work = completed_work_to_scanable_work job work in
        let%bind scanable_works = mapM_2 (jobs', works') in
        Ok (scanable_work :: scanable_works)
    | _, _ -> Error (Error.of_string "Lengths mismatch")

  let fill_in_completed_work (state: scan_state) (works: Completed_work.t list)
      : Transaction_snark.t with_statement option Result_with_rollback.t =
    Result_with_rollback.with_no_rollback
      (let open Deferred.Or_error.Let_syntax in
      let next_jobs =
        Parallel_scan.next_k_jobs ~state
          ~k:(List.length works * Completed_work.proofs_length)
      in
      match next_jobs with
      | Error e -> Deferred.return (Error e)
      | Ok jobs ->
          let%bind scanable_work_list =
            Deferred.return
            @@ mapM_2 (jobs, List.concat_map works (fun work -> work.proofs))
          in
          Deferred.return
          @@ Parallel_scan.fill_in_completed_jobs state scanable_work_list)

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
