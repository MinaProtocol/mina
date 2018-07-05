open Core_kernel
open Async_kernel
open Protocols

module Make (Fee : sig
  module Unsigned : sig
    type t [@@deriving sexp_of, eq]

    val add : t -> t -> t option

    val sub : t -> t -> t option

    val zero : t

    val gte : t -> t -> bool
  end

  module Signed : sig
    type t [@@deriving sexp_of]

    val add : t -> t -> t option

    val negate : t -> t

    val of_unsigned : Unsigned.t -> t
  end
end)
(Public_key : Coda_pow.Public_key_intf) (Transaction : sig
    include Coda_pow.Transaction_intf with type fee := Fee.Unsigned.t

    include Sexpable with type t := t
end) (Fee_transfer : sig
  include Coda_pow.Fee_transfer_intf
          with type public_key := Public_key.t
           and type fee := Fee.Unsigned.t
end) (Super_transaction : sig
  include Coda_pow.Super_transaction_intf
          with type valid_transaction := Transaction.With_valid_signature.t
           and type fee_transfer := Fee_transfer.t
           and type signed_fee := Fee.Signed.t
end) (Ledger_hash : sig
  include Coda_pow.Ledger_hash_intf

  val equal : t -> t -> bool
end)
(Statement : Coda_pow.Transaction_snark_statement_intf
             with type ledger_hash := Ledger_hash.t
              and type signed_fee := Fee.Signed.t) (Proof : sig
    type t [@@deriving sexp]
end) (Ledger : sig
  include Coda_pow.Ledger_intf
          with type ledger_hash := Ledger_hash.t
           and type super_transaction := Super_transaction.t
end) (Ledger_builder_hash : sig
  type t [@@deriving eq]
end)
(Completed_work : Coda_pow.Completed_work_intf
                  with type proof := Proof.t
                   and type fee := Fee.Unsigned.t
                   and type public_key := Public_key.t
                   and type statement := Statement.t)
                                                    (Ledger_builder_witness : sig
    include Coda_pow.Ledger_builder_witness_intf
            with type completed_work := Completed_work.t
             and type transaction := Transaction.With_valid_signature.t
             and type public_key := Public_key.t
             and type ledger_builder_hash := Ledger_builder_hash.t

    val prev_hash : t -> Ledger_builder_hash.t
end) =
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

  module With_statement = struct
    type 'a t = 'a * Statement.t [@@deriving sexp_of]
  end

  module Ledger_proof = struct
    type t = {next_ledger_hash: Ledger_hash.t; proof: Proof.t}
  end

  type transaction = Super_transaction.t [@@deriving sexp_of]

  type proof_with_statement = Proof.t With_statement.t [@@deriving sexp_of]

  type job =
    ( proof_with_statement
    , transaction With_statement.t )
    Parallel_scan.State.Job.t
  [@@deriving sexp_of]

  type scan_state =
    ( proof_with_statement
    , proof_with_statement
    , transaction With_statement.t )
    Parallel_scan.State.t

  type t =
    { scan_state:
        scan_state
        (* Invariant: this is the ledger after having applied all the transactions in
    the above state. *)
    ; ledger: Ledger.t
    ; public_key: Public_key.t }

  let copy {scan_state; ledger; public_key} =
    { scan_state= Parallel_scan.State.copy scan_state
    ; ledger= Ledger.copy ledger
    ; public_key }

  module Job_hash = struct
    type t = job [@@deriving sexp_of]
  end

  let hash t : Ledger_builder_hash.t = failwith "TODO"

  module Spec = struct
    module Accum = struct
      type t = Proof.t With_statement.t [@@deriving sexp_of]

      let ( + ) t t' : t Deferred.t = failwith "TODO"
    end

    module Data = struct
      type t = transaction With_statement.t [@@deriving sexp_of]
    end

    module Output = struct
      type t = Proof.t With_statement.t [@@deriving sexp_of]
    end

    let merge t t' = return t'

    let map (x: Data.t) : Accum.t Deferred.t =
      failwith
        "Create a transaction snark from a transaction. Needs to look up some \
         ds that stores all the proofs that the witness has"
  end

  let spec =
    ( module Spec
    : Parallel_scan.Spec_intf with type Data.t = transaction With_statement.t and type 
      Accum.t = Proof.t With_statement.t and type Output.t = Proof.t
                                                             With_statement.t
    )

  let option lab =
    Option.value_map ~default:(Or_error.error_string lab) ~f:(fun x -> Ok x)

  let check label b = if not b then Or_error.error_string label else Ok ()

  let statement_of_job : job -> Statement.t option = function
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
        { Statement.source= stmt1.source
        ; target= stmt2.target
        ; fee_excess
        ; proof_type= `Merge }
    | _ -> None

  let verify job proof =
    match statement_of_job job with
    | None -> return false
    | Some statement -> Completed_work.verify proof statement

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

  let fill_in_completed_work state works : 
    proof_with_statement option Result_with_rollback.t =
      failwith "TODO: To be done in parallel scan?"

  let enqueue_data_with_rollback state data : unit Result_with_rollback.t =
    failwith "TODO"

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
              let stmt : Statement.t =
                { source
                ; target
                ; fee_excess= Super_transaction.fee_excess t
                ; proof_type= `Base }
              in
              go (t :: processed) ((t, stmt) :: acc) ts
    in
    go [] [] ts

  let check_completed_works t completed_works =
    Result_with_rollback.with_no_rollback
      (let open Deferred.Or_error.Let_syntax in
      let%bind next_jobs =
        Parallel_scan.next_k_jobs ~state:t.scan_state ~spec
          ~k:(List.length completed_works)
        |> Deferred.return
      in
      Deferred.List.for_all (List.zip_exn next_jobs completed_works) ~f:
        (fun (job, work) -> verify job work )
      |> Deferred.map ~f:(check "proofs did not verify"))

  let apply t (witness: Ledger_builder_witness.t) :
      proof_with_statement option Result_with_rollback.t =
    let payments = witness.transactions in
    let completed_works = witness.completed_works in
    let open Result_with_rollback.Let_syntax in
    let%bind () =
      check "bad hash"
        (not
           (Ledger_builder_hash.equal
              (Ledger_builder_witness.prev_hash witness)
              (hash t)))
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
    res_opt

  let apply t witness = Result_with_rollback.run (apply t witness)

  let free_space : scan_state -> int = failwith "TODO"

  let work_to_do : scan_state -> Statement.t Sequence.t = failwith "TODO"

  (* First, if there's any free space on the queue, put transactions there *)
  let create_diff t (ts_by_fee: Transaction.With_valid_signature.t Sequence.t)
      ~(get_completed_work: Statement.t -> Completed_work.t option) =
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
        (ts_by_fee: Transaction.With_valid_signature.t Sequence.t) work_to_do =
      match (Sequence.next ts_by_fee, Sequence.next work_to_do) with
      | None, Some _ ->
          (* Now we take work as our budget permits *)
          let budget', additional_works =
            take_until_budget_exceeded_or_work_absent budget work_to_do
          in
          (budget', payments, additional_works @ works)
      | Some _, None | None, None ->
          (* No work to do. *)
          (budget, payments, works)
      | Some (t, ts_by_fee), Some (stmt, work_to_do) ->
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
                go budget' (t :: payments) (work :: works) ts_by_fee work_to_do
    in
    (* First, we can add as many transactions as there is space on the
       queue (up to the max fee) *)
    let initial_budget, initial_payments, ts_by_fee =
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
      go Fee.Unsigned.zero [] 0 ts_by_fee
    in
    let _left_over_fees, payments, works =
      go initial_budget initial_payments [] ts_by_fee (work_to_do t.scan_state)
    in
    { Ledger_builder_witness.transactions= payments
    ; completed_works= works
    ; creator= t.public_key
    ; prev_hash= hash t }
end
