open Core_kernel
open Async_kernel
open Protocols
open Coda_pow

let option lab =
  Option.value_map ~default:(Or_error.error_string lab) ~f:(fun x -> Ok x)

let check_or_error label b =
  if not b then Or_error.error_string label else Ok ()

let map2_or_error xs ys ~f =
  let rec go xs ys acc =
    match (xs, ys) with
    | [], [] -> Ok (List.rev acc)
    | x :: xs, y :: ys -> (
      match f x y with Error e -> Error e | Ok z -> go xs ys (z :: acc) )
    | _, _ -> Or_error.error_string "Length mismatch"
  in
  go xs ys []

module Make_completed_work
    (Compressed_public_key : Compressed_public_key_intf) (Ledger_proof : sig
        type t [@@deriving sexp, bin_io]
    end) (Ledger_proof_statement : sig
      type t [@@deriving sexp, bin_io, hash, compare]

      val gen : t Quickcheck.Generator.t
    end) :
  Coda_pow.Completed_work_intf
  with type proof := Ledger_proof.t
   and type statement := Ledger_proof_statement.t
   and type public_key := Compressed_public_key.t =
struct
  let proofs_length = 2

  module Statement = struct
    module T = struct
      type t = Ledger_proof_statement.t list
      [@@deriving bin_io, sexp, hash, compare]
    end

    include T
    include Hashable.Make_binable (T)

    let gen =
      Quickcheck.Generator.list_with_length proofs_length
        Ledger_proof_statement.gen
  end

  module T = struct
    type t =
      { fee: Fee.Unsigned.t
      ; proofs: Ledger_proof.t list
      ; prover: Compressed_public_key.t }
    [@@deriving sexp, bin_io]
  end

  include T

  type unchecked = t

  module Checked = struct
    include T

    let create_unsafe = Fn.id
  end

  let forget = Fn.id
end

module Make_diff (Inputs : sig
  module Ledger_hash : Ledger_hash_intf

  module Ledger_proof : sig
    type t [@@deriving sexp, bin_io]
  end

  module Ledger_builder_aux_hash : Ledger_builder_aux_hash_intf

  module Ledger_builder_hash :
    Ledger_builder_hash_intf
    with type ledger_builder_aux_hash := Ledger_builder_aux_hash.t
     and type ledger_hash := Ledger_hash.t

  module Compressed_public_key : Compressed_public_key_intf

  module Transaction :
    Transaction_intf with type public_key := Compressed_public_key.t

  module Completed_work :
    Completed_work_intf
    with type public_key := Compressed_public_key.t
     and type statement := Transaction_snark.Statement.t
     and type proof := Ledger_proof.t
end) :
  Coda_pow.Ledger_builder_diff_intf
  with type transaction := Inputs.Transaction.t
   and type transaction_with_valid_signature :=
              Inputs.Transaction.With_valid_signature.t
   and type ledger_builder_hash := Inputs.Ledger_builder_hash.t
   and type public_key := Inputs.Compressed_public_key.t
   and type completed_work := Inputs.Completed_work.t
   and type completed_work_checked := Inputs.Completed_work.Checked.t =
struct
  open Inputs

  module At_most_two = struct
    type 'a t = Zero | One of 'a option | Two of ('a * 'a option) option
    [@@deriving sexp, bin_io]

    let increase t ws =
      match (t, ws) with
      | Zero, [] -> Ok (One None)
      | Zero, [a] -> Ok (One (Some a))
      | One _, [] -> Ok (Two None)
      | One _, [a] -> Ok (Two (Some (a, None)))
      | One _, [a; a'] -> Ok (Two (Some (a', Some a)))
      | _ -> Or_error.error_string "Error incrementing coinbase parts"
  end

  module At_most_one = struct
    type 'a t = Zero | One of 'a option [@@deriving sexp, bin_io]

    let increase t ws =
      match (t, ws) with
      | Zero, [] -> Ok (One None)
      | Zero, [a] -> Ok (One (Some a))
      | _ -> Or_error.error_string "Error incrementing coinbase parts"
  end

  type diff =
    {completed_works: Completed_work.t list; transactions: Transaction.t list}
  [@@deriving sexp, bin_io]

  type diff_with_at_most_two_coinbase =
    {diff: diff; coinbase_parts: Completed_work.t At_most_two.t}
  [@@deriving sexp, bin_io]

  type diff_with_at_most_one_coinbase =
    {diff: diff; coinbase_added: Completed_work.t At_most_one.t}
  [@@deriving sexp, bin_io]

  type pre_diffs =
    ( diff_with_at_most_one_coinbase
    , diff_with_at_most_two_coinbase * diff_with_at_most_one_coinbase )
    Either.t
  [@@deriving sexp, bin_io]

  type t =
    { pre_diffs: pre_diffs
    ; prev_hash: Ledger_builder_hash.t
    ; creator: Compressed_public_key.t }
  [@@deriving sexp, bin_io]

  module With_valid_signatures_and_proofs = struct
    type diff =
      { completed_works: Completed_work.Checked.t list
      ; transactions: Transaction.With_valid_signature.t list }
    [@@deriving sexp]

    type diff_with_at_most_two_coinbase =
      { diff: diff
      ; coinbase_parts: Inputs.Completed_work.Checked.t At_most_two.t }
    [@@deriving sexp]

    type diff_with_at_most_one_coinbase =
      { diff: diff
      ; coinbase_added: Inputs.Completed_work.Checked.t At_most_one.t }
    [@@deriving sexp]

    type pre_diffs =
      ( diff_with_at_most_one_coinbase
      , diff_with_at_most_two_coinbase * diff_with_at_most_one_coinbase )
      Either.t
    [@@deriving sexp]

    type t =
      { pre_diffs: pre_diffs
      ; prev_hash: Ledger_builder_hash.t
      ; creator: Compressed_public_key.t }
    [@@deriving sexp]

    let transactions t =
      Either.value_map t.pre_diffs
        ~first:(fun d -> d.diff.transactions)
        ~second:(fun d -> (fst d).diff.transactions @ (snd d).diff.transactions)
  end

  let forget_diff
      {With_valid_signatures_and_proofs.completed_works; transactions} =
    { completed_works= List.map ~f:Completed_work.forget completed_works
    ; transactions= (transactions :> Transaction.t list) }

  let forget_work_opt = Option.map ~f:Completed_work.forget

  let forget_pre_diff_with_at_most_two
      {With_valid_signatures_and_proofs.diff; coinbase_parts} =
    let forget_cw =
      match coinbase_parts with
      | At_most_two.Zero -> At_most_two.Zero
      | One cw -> One (forget_work_opt cw)
      | Two cw_pair ->
          Two
            (Option.map cw_pair ~f:(fun (cw, cw_opt) ->
                 (Completed_work.forget cw, forget_work_opt cw_opt) ))
    in
    {diff= forget_diff diff; coinbase_parts= forget_cw}

  let forget_pre_diff_with_at_most_one
      {With_valid_signatures_and_proofs.diff; coinbase_added} =
    let forget_cw =
      match coinbase_added with
      | At_most_one.Zero -> At_most_one.Zero
      | One cw -> One (forget_work_opt cw)
    in
    {diff= forget_diff diff; coinbase_added= forget_cw}

  let forget (t: With_valid_signatures_and_proofs.t) =
    { pre_diffs=
        Either.map t.pre_diffs ~first:forget_pre_diff_with_at_most_one ~second:
          (fun d ->
            ( forget_pre_diff_with_at_most_two (fst d)
            , forget_pre_diff_with_at_most_one (snd d) ) )
    ; prev_hash= t.prev_hash
    ; creator= t.creator }

  let transactions (t: t) =
    Either.value_map t.pre_diffs
      ~first:(fun d -> d.diff.transactions)
      ~second:(fun d -> (fst d).diff.transactions @ (snd d).diff.transactions)
end

module Make (Inputs : Inputs.S) : sig
  include Coda_pow.Ledger_builder_intf
          with type diff := Inputs.Ledger_builder_diff.t
           and type valid_diff :=
                      Inputs.Ledger_builder_diff.
                      With_valid_signatures_and_proofs.t
           and type ledger_hash := Inputs.Ledger_hash.t
           and type frozen_ledger_hash := Inputs.Frozen_ledger_hash.t
           and type ledger_builder_hash := Inputs.Ledger_builder_hash.t
           and type public_key := Inputs.Compressed_public_key.t
           and type ledger := Inputs.Ledger.t
           and type transaction_with_valid_signature :=
                      Inputs.Transaction.With_valid_signature.t
           and type statement := Inputs.Completed_work.Statement.t
           and type completed_work := Inputs.Completed_work.Checked.t
           and type ledger_proof := Inputs.Ledger_proof.t
           and type ledger_builder_aux_hash := Inputs.Ledger_builder_aux_hash.t
           and type sparse_ledger := Inputs.Sparse_ledger.t
           and type ledger_proof_statement := Inputs.Ledger_proof_statement.t
           and type ledger_proof_statement_set :=
                      Inputs.Ledger_proof_statement.Set.t
           and type super_transaction := Inputs.Super_transaction.t
end = struct
  open Inputs

  type 'a with_statement = 'a * Ledger_proof_statement.t
  [@@deriving sexp, bin_io]

  module Super_transaction_with_witness = struct
    (* TODO: The statement is redundant here - it can be computed from the witness and the transaction *)
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
      ( Parallel_scan.State.hash scan_state
          (Binable.to_string (module Snark_with_statement))
          (Binable.to_string (module Super_transaction_with_witness))
        :> string )

    let hash t = Ledger_builder_aux_hash.of_bytes (hash_to_string t)
  end

  type scan_state = Aux.t [@@deriving sexp, bin_io]

  type t =
    { scan_state:
        scan_state
        (* Invariant: this is the ledger after having applied all the transactions in
    the above state. *)
    ; ledger: Ledger.t
    ; public_key: Compressed_public_key.t }
  [@@deriving sexp, bin_io]

  let random_work_spec_chunk t
      (seen_statements:
        Ledger_proof_statement.Set.t * Ledger_proof_statement.t option) =
    let all_jobs = Parallel_scan.next_jobs ~state:t.scan_state in
    let module A = Parallel_scan.Available_job in
    let module L = Ledger_proof_statement in
    let canonical_statement_of_job = function
      | A.Base {Super_transaction_with_witness.statement; _} -> statement
      | A.Merge ((_, s1), (_, s2)) ->
          Ledger_proof_statement.merge s1 s2 |> Or_error.ok_exn
    in
    let single_spec (job: job) =
      match job with
      | A.Base d ->
          Snark_work_lib.Work.Single.Spec.Transition
            (d.statement, d.transaction, d.witness)
      | A.Merge ((p1, s1), (p2, s2)) ->
          let merged = Ledger_proof_statement.merge s1 s2 |> Or_error.ok_exn in
          Snark_work_lib.Work.Single.Spec.Merge (merged, p1, p2)
    in
    (* We currently have an invariant that work must be consecutive. In order to
     * appease that, we admit the redundant work in the following case:
     *
     * Starting state where we randomly choose index 1:
     * |_|_|x|x|_|
     *    ^
     *
     * We will produce the following bundle:
     * |_|_|x|x|_|
     *   (y,y)
     *
     * When we do bundles of size k instead we can revisit this and make it more
     * efficient.
     *
     * We use the following algorithm to choose the index:
     *
     * i <-$- [0,select0 str length)
     * j := (rank0 str i)
     * emit jobs@j and jobs@j+1 (if it exists)
     *  
     * if jobs@j+1 doesn't exist (if the last job is at j) 
     * then we track it separately and return a chunk consisting of just one
     * job. The last job is tracked separately and not included in the list of 
     * seen jobs for the following two reasons:
     * 1. It can be paired with a new job that could be appended to the list 
     * later.
     * 2. The chunk consisting of just the last job is not created more 
     * than once.
     *
     * See meaning of rank/select from here:
     * https://en.wikipedia.org/wiki/Succinct_data_structure
     *)
    let index_of_nth_occurence str n =
      Sequence.of_list str
      |> Sequence.filter_mapi ~f:(fun i b -> if not b then Some i else None)
      |> Fn.flip Sequence.nth n
    in
    let n = List.length all_jobs in
    let dirty_jobs =
      List.map all_jobs ~f:(fun j ->
          L.Set.mem (fst seen_statements) (canonical_statement_of_job j) )
    in
    let seen_jobs, jobs =
      List.partition_tf all_jobs ~f:(fun j ->
          L.Set.mem (fst seen_statements) (canonical_statement_of_job j) )
    in
    let seen_statements' =
      List.map seen_jobs ~f:canonical_statement_of_job |> L.Set.of_list
    in
    match jobs with
    | [] -> (None, seen_statements)
    | _ ->
        let i = Random.int (List.length jobs) in
        let j = index_of_nth_occurence dirty_jobs i |> Option.value_exn in
        (*TODO All of this will change, when we fix  #450. 
          There'll be no more bundles! *)
        if j + 1 < n then
          let chunk =
            [List.nth_exn all_jobs j; List.nth_exn all_jobs (j + 1)]
          in
          let new_last_job =
            Option.fold (snd seen_statements) ~init:None ~f:(fun _ stmt ->
                if
                  Ledger_proof_statement.equal stmt
                    (canonical_statement_of_job (List.last_exn all_jobs))
                then Some stmt
                else None )
          in
          ( Some (List.map chunk ~f:single_spec)
          , ( L.Set.add seen_statements'
                (canonical_statement_of_job @@ List.hd_exn chunk)
            , new_last_job ) )
        else
          let last_job = List.nth_exn all_jobs j in
          let last_job_eq =
            Option.fold (snd seen_statements) ~init:false ~f:(fun _ stmt ->
                Ledger_proof_statement.equal stmt
                  (canonical_statement_of_job last_job) )
          in
          if last_job_eq then (None, seen_statements)
          else
            ( Some [single_spec last_job]
            , (seen_statements', Some (canonical_statement_of_job last_job)) )

  let aux {scan_state; _} = scan_state

  let scan_statement (state: scan_state) :
      (Ledger_proof_statement.t, [`Error of Error.t | `Empty]) Result.t =
    with_return (fun {return} ->
        let ok_or_return = function
          | Ok x -> x
          | Error e -> return (Error (`Error e))
        in
        let merge s1 s2 = ok_or_return (Ledger_proof_statement.merge s1 s2) in
        let merge_acc acc s2 =
          match acc with None -> Some s2 | Some s1 -> Some (merge s1 s2)
        in
        let res =
          Parallel_scan.State.fold_chronological state ~init:None ~f:
            (fun acc_statement job ->
              match job with
              | Merge (None, Some (_, s)) | Merge (Some (_, s), None) ->
                  merge_acc acc_statement s
              | Merge (None, None) -> acc_statement
              | Merge (Some (_, s1), Some (_, s2)) ->
                  merge_acc acc_statement (merge s1 s2)
              | Base None -> acc_statement
              | Base (Some {transaction; statement; witness}) ->
                  let source =
                    Frozen_ledger_hash.of_ledger_hash
                    @@ Sparse_ledger.merkle_root witness
                  in
                  let after =
                    Or_error.try_with (fun () ->
                        Sparse_ledger.apply_super_transaction_exn witness
                          transaction )
                    |> ok_or_return
                  in
                  let target =
                    Frozen_ledger_hash.of_ledger_hash
                    @@ Sparse_ledger.merkle_root after
                  in
                  let expected_statement =
                    { Ledger_proof_statement.source
                    ; target
                    ; fee_excess=
                        ok_or_return (Super_transaction.fee_excess transaction)
                    ; supply_increase=
                        ok_or_return
                          (Super_transaction.supply_increase transaction)
                    ; proof_type= `Base }
                  in
                  if Ledger_proof_statement.equal statement expected_statement
                  then merge_acc acc_statement statement
                  else
                    return
                      (Error
                         (`Error
                           (Error.of_string
                              "Ledger_builder.scan_statement: Bad base \
                               statement"))) )
        in
        match res with None -> Error `Empty | Some res -> Ok res )

  let statement_exn t =
    match scan_statement t.scan_state with
    | Ok s -> `Non_empty s
    | Error `Empty -> `Empty
    | Error (`Error e) -> failwithf !"statement_exn: %{sexp:Error.t}" e ()

  let of_aux_and_ledger ~snarked_ledger_hash ~public_key ~ledger ~aux =
    let check cond err =
      if not cond then Or_error.errorf "Ledger_hash.of_aux_and_ledger: %s" err
      else Ok ()
    in
    let open Or_error.Let_syntax in
    let%map () =
      match scan_statement aux with
      | Error (`Error e) -> Error e
      | Error `Empty -> Ok ()
      | Ok {fee_excess; source; target; supply_increase= _; proof_type= _} ->
          let%map () =
            check
              (Frozen_ledger_hash.equal snarked_ledger_hash source)
              "did not connect with snarked ledger hash"
          and () =
            check
              (Frozen_ledger_hash.equal
                 ( Ledger.merkle_root ledger
                 |> Frozen_ledger_hash.of_ledger_hash )
                 target)
              "incorrect statement target hash"
          and () =
            check
              (Fee.Signed.equal Fee.Signed.zero fee_excess)
              "nonzero fee excess"
          in
          ()
    in
    {ledger; scan_state= aux; public_key}

  let copy {scan_state; ledger; public_key} =
    { scan_state= Parallel_scan.State.copy scan_state
    ; ledger= Ledger.copy ledger
    ; public_key }

  let hash {scan_state; ledger; public_key= _} : Ledger_builder_hash.t =
    Ledger_builder_hash.of_aux_and_ledger_hash (Aux.hash scan_state)
      (Ledger.merkle_root ledger)

  let ledger {ledger; _} = ledger

  let create ~ledger ~self : t =
    let open Config in
    (* Transaction capacity log_2 is half the capacity for work parallelism *)
    { scan_state=
        Parallel_scan.start ~parallelism_log_2:(transaction_capacity_log_2 + 1)
    ; ledger
    ; public_key= self }

  let current_ledger_proof t =
    let res_opt = Parallel_scan.last_emitted_value t.scan_state in
    Option.map res_opt ~f:(fun (snark, _stmt) -> snark)

  let statement_of_job : job -> Ledger_proof_statement.t option = function
    | Base {statement; _} -> Some statement
    | Merge ((_, stmt1), (_, stmt2)) ->
        let open Option.Let_syntax in
        let%bind () =
          Option.some_if
            (Frozen_ledger_hash.equal stmt1.target stmt2.source)
            ()
        in
        let%map fee_excess = Fee.Signed.add stmt1.fee_excess stmt2.fee_excess
        and supply_increase =
          Currency.Amount.add stmt1.supply_increase stmt2.supply_increase
        in
        { Ledger_proof_statement.source= stmt1.source
        ; target= stmt2.target
        ; supply_increase
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
        and supply_increase =
          Currency.Amount.add s.supply_increase s'.supply_increase
          |> option "Error adding supply_increases"
        in
        Parallel_scan.State.Completed_job.Merged
          ( proof
          , { Ledger_proof_statement.source= s.source
            ; target= s'.target
            ; supply_increase
            ; fee_excess
            ; proof_type= `Merge } )

  let verify ~message job proof =
    match statement_of_job job with
    | None -> return false
    | Some statement ->
        Inputs.Ledger_proof_verifier.verify proof statement ~message

  let total_proofs (works: Completed_work.t list) =
    List.sum (module Int) works ~f:(fun w -> List.length w.proofs)

  let fill_in_completed_work (state: scan_state) (works: Completed_work.t list)
      : Ledger_proof.t with_statement option Or_error.t =
    let open Or_error.Let_syntax in
    let%bind next_jobs =
      Parallel_scan.next_k_jobs ~state ~k:(total_proofs works)
    in
    let%bind scanable_work_list =
      map2_or_error next_jobs
        (List.concat_map works ~f:(fun work -> work.proofs))
        ~f:completed_work_to_scanable_work
    in
    Parallel_scan.fill_in_completed_jobs ~state
      ~completed_jobs:scanable_work_list

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
    let%bind fee_excess = Super_transaction.fee_excess s
    and supply_increase = Super_transaction.supply_increase s in
    let source =
      Ledger.merkle_root ledger |> Frozen_ledger_hash.of_ledger_hash
    in
    let%map undo = Ledger.apply_super_transaction ledger s in
    ( undo
    , { Ledger_proof_statement.source
      ; target= Ledger.merkle_root ledger |> Frozen_ledger_hash.of_ledger_hash
      ; fee_excess
      ; supply_increase
      ; proof_type= `Base } )

  let apply_super_transaction_and_get_witness ledger s =
    let public_keys = function
      | Super_transaction.Fee_transfer t -> Fee_transfer.receivers t
      | Transaction t ->
          let t = (t :> Transaction.t) in
          [Transaction.sender t; Transaction.receiver t]
      | Coinbase c ->
          let ft_receivers =
            Option.value_map c.fee_transfer ~default:[] ~f:(fun ft ->
                Fee_transfer.receivers (Fee_transfer.of_single ft) )
          in
          c.proposer :: ft_receivers
    in
    let open Or_error.Let_syntax in
    let witness = Sparse_ledger.of_ledger_subset_exn ledger (public_keys s) in
    let%map undo, statement =
      apply_super_transaction_and_get_statement ledger s
    in
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
              ~k:(total_proofs completed_works)
          in
          chunks_of jobs ~n:Completed_work.proofs_length)
      in
      Deferred.List.for_all (List.zip_exn jobses completed_works) ~f:
        (fun (jobs, work) ->
          let message = Sok_message.create ~fee:work.fee ~prover:work.prover in
          Deferred.List.for_all (List.zip_exn jobs work.proofs) ~f:
            (fun (job, proof) -> verify ~message job proof ) )
      |> Deferred.map ~f:(check_or_error "proofs did not verify"))

  let create_fee_transfers completed_works delta public_key =
    let singles =
      (if Fee.Unsigned.(equal zero delta) then [] else [(public_key, delta)])
      @ List.filter_map completed_works ~f:
          (fun {Completed_work.fee; prover; _} ->
            if Fee.Unsigned.equal fee Fee.Unsigned.zero then None
            else Some (prover, fee) )
    in
    Or_error.try_with (fun () ->
        Compressed_public_key.Map.of_alist_reduce singles ~f:(fun f1 f2 ->
            Option.value_exn (Fee.Unsigned.add f1 f2) )
        (* TODO: This creates a weird incentive to have a small public_key *)
        |> Map.to_alist ~key_order:`Increasing
        |> Fee_transfer.of_single_list )

  (*A Coinbase is a single transaction that accommodates the coinbase amount
  and a fee transfer for the work required to add the coinbase. Unlike a 
  transaction, a coinbase (including the fee transfer) just requires one slot 
  in the jobs queue. 
  
  The minimum number of slots required to add a single transaction is three (at 
  worst case number of provers: when each pair of proofs is from a different 
  prover). One slot for the transaction and two slots for fee transfers.

  When the diff is split into two prediffs (why? refer to #687) and if after 
  adding transactions, the first prediff has two slots remaining which cannot 
  not accommodate transactions, then those slots are filled by splitting the 
  coinbase into two parts. 
  If it has one slot, then we simply add one coinbase. It is also possible that 
  the first prediff may have no slots left after adding transactions (For 
  example, when there are three slots and 
  maximum number of provers), in which case, we simply add one coinbase as part 
  of the second prediff.
  *)
  let create_coinbase coinbase_parts proposer =
    let open Or_error.Let_syntax in
    let coinbase = Protocols.Coda_praos.coinbase_amount in
    let overflow_err a1 a2 =
      option
        ( "overflow when creating coinbase (fee:"
        ^ Currency.Amount.to_string a2
        ^ ") \n %!" )
        (Currency.Amount.sub a1 a2)
    in
    let single {Completed_work.fee; prover; _} =
      if
        Fee.Unsigned.equal fee Fee.Unsigned.zero
        || Compressed_public_key.equal prover proposer
      then None
      else Some (prover, fee)
    in
    let fee_transfer cw_opt = Option.bind cw_opt ~f:single in
    let two_parts amt w1 w2 =
      let%bind rem_coinbase = overflow_err coinbase amt in
      let%bind _ =
        overflow_err rem_coinbase
          (Option.value_map ~default:Currency.Amount.zero w2 ~f:
             (fun {Completed_work.fee; _} -> Currency.Amount.of_fee fee ))
      in
      let%bind cb1 =
        Coinbase.create ~amount:amt ~proposer ~fee_transfer:(fee_transfer w1)
      in
      let%map cb2 =
        Coinbase.create ~amount:rem_coinbase ~proposer
          ~fee_transfer:(fee_transfer w2)
      in
      [cb1; cb2]
    in
    match coinbase_parts with
    | `Zero -> return []
    | `One x ->
        let%map cb =
          Coinbase.create ~amount:coinbase ~proposer
            ~fee_transfer:(fee_transfer x)
        in
        [cb]
    | `Two None ->
        let amt = Currency.Amount.of_int 1 in
        two_parts amt None None
    | `Two (Some ((w1: Completed_work.t), w2)) ->
        let amt = Currency.Amount.of_fee w1.fee in
        two_parts amt (Some w1) w2

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

  let apply_pre_diff t coinbase_parts (diff: Ledger_builder_diff.diff) =
    let open Result_with_rollback.Let_syntax in
    let%bind payments =
      let%map payments' =
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
      List.rev payments'
    in
    let coinbase_work =
      match coinbase_parts with
      | `One (Some w) -> [w]
      | `Two (Some (w, None)) -> [w]
      | `Two (Some (w1, Some w2)) -> [w1; w2]
      | _ -> []
    in
    let%bind coinbase =
      create_coinbase coinbase_parts t.public_key
      |> Result_with_rollback.of_or_error
    in
    let%bind delta =
      fee_remainder payments diff.completed_works
      |> Result_with_rollback.of_or_error
    in
    let%bind fee_transfers =
      create_fee_transfers diff.completed_works delta t.public_key
      |> Result_with_rollback.of_or_error
    in
    let super_transactions =
      List.map payments ~f:(fun t -> Super_transaction.Transaction t)
      @ List.map coinbase ~f:(fun t -> Super_transaction.Coinbase t)
      @ List.map fee_transfers ~f:(fun t -> Super_transaction.Fee_transfer t)
    in
    let%map new_data =
      update_ledger_and_get_statements t.ledger super_transactions
    in
    (new_data, diff.completed_works, coinbase_work)

  (* TODO: when we move to a disk-backed db, this should call "Ledger.commit_changes" at the end. *)
  let apply_diff t (diff: Ledger_builder_diff.t) =
    let open Result_with_rollback.Let_syntax in
    let apply_pre_diff_with_at_most_two
        (pre_diff1: Ledger_builder_diff.diff_with_at_most_two_coinbase) =
      let coinbase_parts =
        match pre_diff1.coinbase_parts with
        | Zero -> `Zero
        | One x -> `One x
        | Two x -> `Two x
      in
      apply_pre_diff t coinbase_parts pre_diff1.diff
    in
    let apply_pre_diff_with_at_most_one
        (pre_diff2: Ledger_builder_diff.diff_with_at_most_one_coinbase) =
      let coinbase_added =
        match pre_diff2.coinbase_added with Zero -> `Zero | One x -> `One x
      in
      apply_pre_diff t coinbase_added pre_diff2.diff
    in
    let%bind () =
      let curr_hash = hash t in
      check_or_error
        (sprintf
           !"bad prev_hash: Expected %{sexp:Ledger_builder_hash.t}, got \
             %{sexp:Ledger_builder_hash.t}"
           curr_hash diff.prev_hash)
        (Ledger_builder_hash.equal diff.prev_hash (hash t))
      |> Result_with_rollback.of_or_error
    in
    let%bind data, works =
      Either.value_map diff.pre_diffs
        ~first:(fun d ->
          let%map data, works, cb_works = apply_pre_diff_with_at_most_one d in
          (data, cb_works @ works) )
        ~second:(fun d ->
          let%bind data1, works1, cb_works1 =
            apply_pre_diff_with_at_most_two (fst d)
          in
          let%map data2, works2, cb_works2 =
            apply_pre_diff_with_at_most_one (snd d)
          in
          (data1 @ data2, works1 @ cb_works1 @ cb_works2 @ works2) )
    in
    let%bind () = check_completed_works t works in
    let%bind res_opt =
      (* TODO: Add rollback *)
      let r = fill_in_completed_work t.scan_state works in
      Or_error.iter_error r ~f:(fun e ->
          (* TODO: Pass a logger here *)
          eprintf !"Unexpected error: %s %{sexp:Error.t}\n%!" __LOC__ e ) ;
      Result_with_rollback.of_or_error r
    in
    let%map () =
      (* TODO: Add rollback *)
      enqueue_data_with_rollback t.scan_state data
    in
    Option.map res_opt ~f:(fun (snark, _stmt) -> snark)

  let apply t witness = Result_with_rollback.run (apply_diff t witness)

  let forget_work_opt = Option.map ~f:Completed_work.forget

  let apply_pre_diff_unchecked t coinbase_parts
      (diff: Ledger_builder_diff.With_valid_signatures_and_proofs.diff) =
    let payments = diff.transactions in
    let txn_works = List.map ~f:Completed_work.forget diff.completed_works in
    let coinbase_work =
      match coinbase_parts with
      | `One (Some w) -> [w]
      | `Two (Some (w, None)) -> [w]
      | `Two (Some (w1, Some w2)) -> [w1; w2]
      | _ -> []
    in
    let coinbase_parts =
      Or_error.ok_exn (create_coinbase coinbase_parts t.public_key)
    in
    let delta = Or_error.ok_exn (fee_remainder payments txn_works) in
    let fee_transfers =
      Or_error.ok_exn (create_fee_transfers txn_works delta t.public_key)
    in
    let super_transactions =
      List.map payments ~f:(fun t -> Super_transaction.Transaction t)
      @ List.map coinbase_parts ~f:(fun t -> Super_transaction.Coinbase t)
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
    (new_data, txn_works, coinbase_work)

  let apply_diff_unchecked t
      (diff: Ledger_builder_diff.With_valid_signatures_and_proofs.t) =
    let apply_pre_diff_with_at_most_two
        (pre_diff1:
          Ledger_builder_diff.With_valid_signatures_and_proofs.
          diff_with_at_most_two_coinbase) =
      let coinbase_parts =
        match pre_diff1.coinbase_parts with
        | Zero -> `Zero
        | One x -> `One (forget_work_opt x)
        | Two x ->
            `Two
              (Option.map x ~f:(fun (w, w_opt) ->
                   (Completed_work.forget w, forget_work_opt w_opt) ))
      in
      apply_pre_diff_unchecked t coinbase_parts pre_diff1.diff
    in
    let apply_pre_diff_with_at_most_one
        (pre_diff2:
          Ledger_builder_diff.With_valid_signatures_and_proofs.
          diff_with_at_most_one_coinbase) =
      let coinbase_added =
        match pre_diff2.coinbase_added with
        | Zero -> `Zero
        | One x -> `One (forget_work_opt x)
      in
      apply_pre_diff_unchecked t coinbase_added pre_diff2.diff
    in
    let data, works =
      Either.value_map diff.pre_diffs
        ~first:(fun d ->
          let data, works, cb_works = apply_pre_diff_with_at_most_one d in
          (data, cb_works @ works) )
        ~second:(fun d ->
          let data1, works1, cb_works1 =
            apply_pre_diff_with_at_most_two (fst d)
          in
          let data2, works2, cb_works2 =
            apply_pre_diff_with_at_most_one (snd d)
          in
          (data1 @ data2, works1 @ cb_works1 @ cb_works2 @ works2) )
    in
    let res_opt =
      Or_error.ok_exn (fill_in_completed_work t.scan_state works)
    in
    Or_error.ok_exn (Parallel_scan.enqueue_data ~state:t.scan_state ~data) ;
    res_opt

  let sequence_chunks_of seq ~n =
    Sequence.unfold_step ~init:([], 0, seq) ~f:(fun (acc, i, seq) ->
        if i = n then Yield (List.rev acc, ([], 0, seq))
        else
          match Sequence.next seq with
          | None -> Done
          | Some (x, seq) ->
            match (*allow a chunk of 1 proof as well*)
                  Sequence.next seq with
            | None -> Yield (List.rev (x :: acc), ([], 0, seq))
            | _ -> Skip (x :: acc, i + 1, seq) )

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
      type t =
        { fee_transfers: Compressed_public_key.Set.t
        ; transactions: int
        ; coinbase_part_count: int }
      [@@deriving sexp]

      let count {fee_transfers; transactions; coinbase_part_count} =
        (* This is number of coinbase_parts + number of transactions + ceil
        (Set.length fee_transfers / 2) *)
        coinbase_part_count + transactions
        + ((Set.length fee_transfers + 1) / 2)

      let add_transaction t = {t with transactions= t.transactions + 1}

      let add_fee_transfer t public_key =
        {t with fee_transfers= Set.add t.fee_transfers public_key}

      let add_coinbase t =
        {t with coinbase_part_count= t.coinbase_part_count + 1}

      let init =
        { transactions= 0
        ; fee_transfers= Compressed_public_key.Set.empty
        ; coinbase_part_count= 0 }
    end

    type t =
      { budget: Fee.Signed.t
      ; queue_consumption: Queue_consumption.t
      ; available_queue_space: int
      ; work_done: int
      ; transactions: (Transaction.With_valid_signature.t * Ledger.Undo.t) list
      ; completed_works: Completed_work.Checked.t list
      ; coinbase_parts:
          ( Completed_work.Checked.t Ledger_builder_diff.At_most_two.t
          , Completed_work.Checked.t Ledger_builder_diff.At_most_one.t )
          Either.t
      ; completed_works_for_coinbase: Completed_work.Checked.t list
      ; self_pk: Compressed_public_key.t }
    [@@deriving sexp]

    let available_space t =
      t.available_queue_space - Queue_consumption.count t.queue_consumption

    let is_space_available t = available_space t > 0

    let budget_non_neg t = Fee.Signed.sgn t.budget = Sgn.Pos

    let coinbase_added t = t.queue_consumption.coinbase_part_count > 0

    let add_transaction t ((txv: Transaction.With_valid_signature.t), undo) =
      let tx = (txv :> Transaction.t) in
      let open Or_error.Let_syntax in
      let%bind budget =
        option "overflow"
          (Fee.Signed.add t.budget
             (Fee.Signed.of_unsigned @@ Transaction.fee tx))
      in
      let q =
        if Currency.Fee.equal (Transaction.fee tx) Currency.Fee.zero then
          t.queue_consumption
        else Queue_consumption.add_fee_transfer t.queue_consumption t.self_pk
      in
      let queue_consumption = Queue_consumption.add_transaction q in
      if not (is_space_available {t with queue_consumption= q}) then
        Or_error.error_string "Error adding a transaction: Insufficient space"
      else
        Ok
          { t with
            budget
          ; queue_consumption
          ; transactions= (txv, undo) :: t.transactions }

    let add_coinbase t =
      let open Or_error.Let_syntax in
      if not (is_space_available t) then
        Or_error.error_string "Error adding coinbase: Insufficient space"
      else
        let queue_consumption =
          Queue_consumption.add_coinbase t.queue_consumption
        in
        let%map coinbase_parts =
          match t.coinbase_parts with
          | First w ->
              let%map cb =
                Ledger_builder_diff.At_most_two.increase w
                  t.completed_works_for_coinbase
              in
              First cb
          | Second w ->
              let%map cb =
                Ledger_builder_diff.At_most_one.increase w
                  t.completed_works_for_coinbase
              in
              Second cb
        in
        {t with queue_consumption; coinbase_parts}

    let enough_work_for_txn t (txv: Transaction.With_valid_signature.t) =
      let tx = (txv :> Transaction.t) in
      let q =
        if Currency.Fee.equal (Transaction.fee tx) Currency.Fee.zero then
          t.queue_consumption
        else Queue_consumption.add_fee_transfer t.queue_consumption t.self_pk
      in
      let queue_consumption = Queue_consumption.add_transaction q in
      t.work_done = Queue_consumption.count queue_consumption * 2

    let enough_work_for_coinbase t =
      let work_done =
        List.sum
          (module Int)
          t.completed_works_for_coinbase
          ~f:(fun wc ->
            let w = Completed_work.forget wc in
            List.length w.proofs )
      in
      work_done >= (t.queue_consumption.coinbase_part_count + 1) * 2

    let add_work_for_coinbase t (wc: Completed_work.Checked.t) =
      let open Or_error.Let_syntax in
      let coinbase = Protocols.Coda_praos.coinbase_amount in
      let%bind coinbase_used_up =
        List.fold ~init:(Ok Currency.Fee.zero)
          ~f:(fun acc w ->
            let%bind acc = acc in
            let w' = Completed_work.forget w in
            option "overflow" (Currency.Fee.add acc w'.fee) )
          (wc :: t.completed_works_for_coinbase)
      in
      let%bind _ =
        option "overflow"
          (Currency.Fee.sub (Currency.Amount.to_fee coinbase) coinbase_used_up)
      in
      Ok
        { t with
          completed_works_for_coinbase= wc :: t.completed_works_for_coinbase }

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

    let init ~available_queue_space ~self prediff =
      { available_queue_space
      ; work_done= 0
      ; queue_consumption= Queue_consumption.init
      ; budget= Fee.Signed.zero
      ; transactions= []
      ; completed_works= []
      ; coinbase_parts= prediff
      ; completed_works_for_coinbase= []
      ; self_pk= self }
  end

  module Resource_util = struct
    type t =
      { resources: Resources.t
      ; work_to_do: Completed_work.Statement.t Sequence.t
      ; txns_to_include: Transaction.With_valid_signature.t Sequence.t }
  end

  let add_work work resources get_completed_work =
    match get_completed_work work with
    | Some w ->
        (* TODO: There is a subtle error here.
               You should not add work if it would cause the person's
               balance to overflow *)
        Resources.add_work resources w
    | None -> Error (Error.of_string "Work not found")

  let add_work_for_coinbase work resources get_completed_work =
    match get_completed_work work with
    | Some w ->
        (* TODO: There is a subtle error here.
               You should not add work if it would cause the person's
               balance to overflow *)
        Resources.add_work_for_coinbase resources w
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
      List.length invalid.transactions - List.length valid.transactions
    in
    if diff > 0 then List.take invalid.transactions diff else []

  let log_error_and_return_value logger err_val def_val =
    match err_val with
    | Error e ->
        Logger.error logger "%s" (Error.to_string_hum e) ;
        def_val
    | Ok value -> value

  let rec check_resources_add_txns logger get_completed_work ledger
      (valid: Resource_util.t) (current: Resource_util.t) =
    let add_transaction t ts ws =
      let r_transaction =
        log_error_and_return_value logger
          (add_transaction ledger t current.resources)
          current.resources
      in
      let new_res_util =
        { Resource_util.resources= r_transaction
        ; work_to_do= ws
        ; txns_to_include= ts }
      in
      if Resources.budget_non_neg r_transaction then
        check_resources_add_txns logger get_completed_work ledger new_res_util
          new_res_util
      else
        check_resources_add_txns logger get_completed_work ledger valid
          new_res_util
    in
    match
      ( Sequence.next current.work_to_do
      , Sequence.next current.txns_to_include
      , Resources.is_space_available current.resources )
    with
    | None, None, _ ->
        (valid, txns_not_included valid.resources current.resources)
    | None, Some (t, ts), true -> add_transaction t ts Sequence.empty
    | Some (w, ws), Some (t, ts), true -> (
        let enough_work_added_to_include_one_more =
          Resources.enough_work_for_txn current.resources t
        in
        if enough_work_added_to_include_one_more then
          add_transaction t ts (Sequence.append (Sequence.singleton w) ws)
        else
          match add_work w current.resources get_completed_work with
          | Ok r_work ->
              check_resources_add_txns logger get_completed_work ledger valid
                { resources= r_work
                ; work_to_do= ws
                ; txns_to_include= Sequence.append (Sequence.singleton t) ts }
          | Error e ->
              Logger.error logger "%s" (Error.to_string_hum e) ;
              (valid, txns_not_included valid.resources current.resources) )
    | _, _, _ -> (valid, txns_not_included valid.resources current.resources)

  let undo_txns ledger txns =
    List.fold txns ~init:() ~f:(fun _ (_, u) ->
        Or_error.ok_exn (Ledger.undo ledger u) )

  let update_coinbase_count n logger (res_util: Resource_util.t)
      get_completed_work : Resource_util.t =
    if Resources.coinbase_added res_util.resources then res_util
    else
      let rec go valid (current: Resource_util.t) count =
        let add_coinbase ws count =
          let r_cb =
            log_error_and_return_value logger
              (Resources.add_coinbase current.resources)
              current.resources
          in
          let new_res_util =
            {current with Resource_util.resources= r_cb; work_to_do= ws}
          in
          if Resources.budget_non_neg r_cb then
            go new_res_util new_res_util (count - 1)
          else (
            Logger.error logger "coinbase not enough to pay for the proofs" ;
            go valid new_res_util (count - 1) )
        in
        match (Sequence.next current.work_to_do, count > 0) with
        | _, false -> valid
        | None, true -> add_coinbase Sequence.empty count
        | Some (w, ws), true ->
            if Resources.enough_work_for_coinbase current.resources then
              add_coinbase (Sequence.append (Sequence.singleton w) ws) count
            else
              match
                add_work_for_coinbase w current.resources get_completed_work
              with
              | Ok r_work ->
                  go valid
                    {current with resources= r_work; work_to_do= ws}
                    count
              | Error e ->
                  Logger.error logger "%s" (Error.to_string_hum e) ;
                  valid
      in
      if n > 2 then
        log_error_and_return_value logger
          (Error
             (Error.of_string "Tried to split the coinbase more than twice"))
          res_util
      else go res_util res_util n

  let coinbase_after_txns coinbase_parts logger get_completed_work ledger
      init_res_util : Resource_util.t =
    let res_util, txns_to_undo =
      check_resources_add_txns logger get_completed_work ledger init_res_util
        init_res_util
    in
    let _ = undo_txns ledger txns_to_undo in
    let cb = coinbase_parts res_util in
    let res =
      { res_util.resources with
        available_queue_space= cb + res_util.resources.available_queue_space }
    in
    update_coinbase_count cb logger
      {res_util with resources= res}
      get_completed_work

  let one_prediff logger ws_seq ts_seq get_completed_work ledger self
      available_queue_space ~add_coinbase =
    let init_resources =
      Resources.init ~available_queue_space ~self
        (Second Ledger_builder_diff.At_most_one.Zero)
    in
    let init_res_util =
      { Resource_util.resources= init_resources
      ; work_to_do= ws_seq
      ; txns_to_include= ts_seq }
    in
    let res_util_with_coinbase =
      if add_coinbase then
        update_coinbase_count 1 logger init_res_util get_completed_work
      else init_res_util
    in
    let res_util_with_txns, txns_to_undo =
      check_resources_add_txns logger get_completed_work ledger
        res_util_with_coinbase res_util_with_coinbase
    in
    let _ = undo_txns ledger txns_to_undo in
    res_util_with_txns.resources

  let two_prediffs logger ws_seq ts_seq get_completed_work ledger self
      partitions
      (*: (Resources_util.t, Resources.t * Resources.t option) Either.t*) =
    let init_resources =
      Resources.init ~available_queue_space:(fst partitions) ~self
        (First Ledger_builder_diff.At_most_two.Zero)
    in
    let init_res_util =
      { Resource_util.resources= init_resources
      ; work_to_do= ws_seq
      ; txns_to_include= ts_seq }
    in
    (*splitting coinbase into n parts*)
    let remaining_slots (res_util: Resource_util.t) =
      let n' = Resources.available_space res_util.resources in
      (*if there are no more transactions to be included in the second prediff then don't bother splitting up the coinbase*)
      if n' > 1 && Sequence.length res_util.txns_to_include = 0 then 1 else n'
    in
    let res_util_coinbase =
      coinbase_after_txns remaining_slots logger get_completed_work ledger
        init_res_util
    in
    let unable_to_add_coinbase =
      Resources.is_space_available res_util_coinbase.resources
      && not (Resources.coinbase_added res_util_coinbase.resources)
    in
    if unable_to_add_coinbase then
      (*Not enough work to add coinbase and therefore recompute the diff again
      by adding coinbase first, resulting in a single pre_diff*)
      let _ = undo_txns ledger res_util_coinbase.resources.transactions in
      let res =
        one_prediff logger ws_seq ts_seq get_completed_work ledger self
          (fst partitions) ~add_coinbase:true
      in
      First res
    else
      let res_coinbase2 =
        one_prediff logger res_util_coinbase.work_to_do
          res_util_coinbase.txns_to_include get_completed_work ledger self
          (snd partitions)
          ~add_coinbase:
            (not (Resources.coinbase_added res_util_coinbase.resources))
      in
      let coinbase_added =
        Resources.coinbase_added res_util_coinbase.resources
        || Resources.coinbase_added res_coinbase2
      in
      if coinbase_added then (
        (*All the slots have been filled in the first pre_diff*)
        assert (
          Resources.Queue_consumption.count
            res_util_coinbase.resources.queue_consumption
          = fst partitions
          || List.length res_coinbase2.transactions = 0 ) ;
        Second (res_util_coinbase.resources, res_coinbase2) )
      else
        (*Not enough work to add coinbase and therefore recompute the diff
        again by adding coinbase first, resulting in a single pre_diff*)
        let _ =
          undo_txns ledger
            ( res_coinbase2.transactions
            @ res_util_coinbase.resources.transactions )
        in
        let res =
          one_prediff logger ws_seq ts_seq get_completed_work ledger self
            (fst partitions) ~add_coinbase:true
        in
        First res

  let generate_prediff logger ws_seq ts_seq get_completed_work ledger self
      partitions =
    let diff (res: Resources.t) :
        Ledger_builder_diff.With_valid_signatures_and_proofs.diff =
      (* We have to reverse here because we only know they work in THIS order *)
      { transactions= List.rev_map res.transactions ~f:fst
      ; completed_works= List.rev res.completed_works }
    in
    let make_diff_with_one (res: Resources.t) :
        Ledger_builder_diff.With_valid_signatures_and_proofs.
        diff_with_at_most_one_coinbase =
      match res.coinbase_parts with
      | First _ ->
          Logger.error logger
            "Error while creating a diff: Invalid resource configuration" ;
          {diff= diff res; coinbase_added= Ledger_builder_diff.At_most_one.Zero}
      | Second w -> {diff= diff res; coinbase_added= w}
    in
    let make_diff_with_two (res: Resources.t) :
        Ledger_builder_diff.With_valid_signatures_and_proofs.
        diff_with_at_most_two_coinbase =
      match res.coinbase_parts with
      | First w -> {diff= diff res; coinbase_parts= w}
      | Second _ ->
          Logger.error logger
            "Error while creating a diff: Invalid resource configuration" ;
          {diff= diff res; coinbase_parts= Ledger_builder_diff.At_most_two.Zero}
    in
    match partitions with
    | `One x ->
        let res =
          one_prediff logger ws_seq ts_seq get_completed_work ledger self x
            ~add_coinbase:true
        in
        let _ = undo_txns ledger res.transactions in
        First (make_diff_with_one res)
    | `Two (x, y) ->
      match
        two_prediffs logger ws_seq ts_seq get_completed_work ledger self (x, y)
      with
      | First res ->
          let _ = undo_txns ledger res.transactions in
          First (make_diff_with_one res)
      | Second (res1, res2) ->
          let _ = undo_txns ledger (res2.transactions @ res1.transactions) in
          Second (make_diff_with_two res1, make_diff_with_one res2)

  let create_diff t ~logger
      ~(transactions_by_fee: Transaction.With_valid_signature.t Sequence.t)
      ~(get_completed_work:
         Completed_work.Statement.t -> Completed_work.Checked.t option) =
    (* TODO: Don't copy *)
    let curr_hash = hash t in
    let t' = copy t in
    let ledger = ledger t' in
    let max_throughput = Int.pow 2 Inputs.Config.transaction_capacity_log_2 in
    let partitions =
      Parallel_scan.partition_if_overflowing ~max_slots:max_throughput
        t'.scan_state
    in
    let pre_diffs =
      generate_prediff logger (work_to_do t'.scan_state) transactions_by_fee
        get_completed_work ledger t'.public_key partitions
    in
    let diff =
      { Ledger_builder_diff.With_valid_signatures_and_proofs.pre_diffs
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
      module Compressed_public_key = String

      module Sok_message = struct
        module Digest = Unit
        include Unit

        let create ~fee:_ ~prover:_ = ()
      end

      module Transaction = struct
        type fee = Fee.Unsigned.t [@@deriving sexp, bin_io, compare]

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
        type public_key = Compressed_public_key.t
        [@@deriving sexp, bin_io, compare, eq]

        type fee = Fee.Unsigned.t [@@deriving sexp, bin_io, compare, eq]

        type single = public_key * fee [@@deriving bin_io, sexp, compare, eq]

        type t = One of single | Two of single * single
        [@@deriving bin_io, sexp, compare, eq]

        let to_list = function One x -> [x] | Two (x, y) -> [x; y]

        let of_single t = One t

        let of_single_list xs =
          let rec go acc = function
            | x1 :: x2 :: xs -> go (Two (x1, x2) :: acc) xs
            | [] -> acc
            | [x] -> One x :: acc
          in
          go [] xs

        let fee_excess t : fee Or_error.t =
          match t with
          | One (_, fee) -> Ok fee
          | Two ((_, fee1), (_, fee2)) ->
            match Fee.Unsigned.add fee1 fee2 with
            | None -> Or_error.error_string "Fee_transfer.fee_excess: overflow"
            | Some res -> Ok res

        let fee_excess_int t =
          Fee.Unsigned.to_int (Or_error.ok_exn @@ fee_excess t)

        let receivers t = List.map (to_list t) ~f:(fun (pk, _) -> pk)
      end

      module Coinbase = struct
        type public_key = string [@@deriving sexp, bin_io, compare, eq]

        type fee_transfer = Fee_transfer.single
        [@@deriving sexp, bin_io, compare, eq]

        type t =
          { proposer: public_key
          ; amount: Currency.Amount.t
          ; fee_transfer: fee_transfer option }
        [@@deriving sexp, bin_io, compare, eq]

        let supply_increase {proposer= _; amount; fee_transfer} =
          match fee_transfer with
          | None -> Ok amount
          | Some (_, fee) ->
              Currency.Amount.sub amount (Currency.Amount.of_fee fee)
              |> Option.value_map ~f:Or_error.return
                   ~default:(Or_error.error_string "Coinbase underflow")

        let fee_excess t =
          Or_error.map (supply_increase t) ~f:(fun _increase ->
              Currency.Fee.Signed.zero )

        let is_valid {proposer= _; amount; fee_transfer} =
          match fee_transfer with
          | None -> true
          | Some (_, fee) -> Currency.Amount.(of_fee fee <= amount)

        let create ~amount ~proposer ~fee_transfer =
          let t = {proposer; amount; fee_transfer} in
          if is_valid t then Ok t
          else
            Or_error.error_string "Coinbase.create: fee transfer was too high"
      end

      module Super_transaction = struct
        type valid_transaction = Transaction.With_valid_signature.t
        [@@deriving sexp, bin_io, compare, eq]

        type fee_transfer = Fee_transfer.t
        [@@deriving sexp, bin_io, compare, eq]

        type coinbase = Coinbase.t [@@deriving sexp, bin_io, compare, eq]

        type unsigned_fee = Fee.Unsigned.t [@@deriving sexp, bin_io, compare]

        type t =
          | Transaction of valid_transaction
          | Fee_transfer of fee_transfer
          | Coinbase of coinbase
        [@@deriving sexp, bin_io, compare, eq]

        let fee_excess : t -> Fee.Signed.t Or_error.t =
         fun t ->
          let open Or_error.Let_syntax in
          match t with
          | Transaction t' ->
              Ok (Currency.Fee.Signed.of_unsigned (Transaction.fee t'))
          | Fee_transfer f ->
              let%map fee = Fee_transfer.fee_excess f in
              Currency.Fee.Signed.negate (Currency.Fee.Signed.of_unsigned fee)
          | Coinbase t -> Coinbase.fee_excess t

        let supply_increase = function
          | Transaction _ | Fee_transfer _ -> Ok Currency.Amount.zero
          | Coinbase t -> Coinbase.supply_increase t
      end

      module Ledger_hash = struct
        include String

        let to_bytes : t -> string = fun t -> t
      end

      module Frozen_ledger_hash = struct
        include Ledger_hash

        let of_ledger_hash = Fn.id
      end

      module Ledger_proof_statement = struct
        module T = struct
          type t =
            { source: Ledger_hash.t
            ; target: Ledger_hash.t
            ; supply_increase: Currency.Amount.t
            ; fee_excess: Fee.Signed.t
            ; proof_type: [`Base | `Merge] }
          [@@deriving sexp, bin_io, compare, hash]

          let merge s1 s2 =
            let open Or_error.Let_syntax in
            let%map fee_excess =
              Fee.Signed.add s1.fee_excess s2.fee_excess
              |> option "Error adding fees"
            and supply_increase =
              Currency.Amount.add s1.supply_increase s2.supply_increase
              |> option "Error adding supply increases"
            in
            { source= s1.source
            ; target= s2.target
            ; supply_increase
            ; fee_excess
            ; proof_type= `Merge }
        end

        include T
        include Comparable.Make (T)

        let gen =
          let open Quickcheck.Generator.Let_syntax in
          let%bind source = Ledger_hash.gen
          and target = Ledger_hash.gen
          and fee_excess = Fee.Signed.gen
          and supply_increase = Currency.Amount.gen in
          let%map proof_type =
            Quickcheck.Generator.bool
            >>| function true -> `Base | false -> `Merge
          in
          {source; target; supply_increase; fee_excess; proof_type}
      end

      module Proof = Ledger_proof_statement

      module Ledger_proof = struct
        (*A proof here is a statement *)
        include Ledger_proof_statement

        type ledger_hash = Ledger_hash.t

        let statement_target : Ledger_proof_statement.t -> ledger_hash =
         fun statement -> statement.target

        let underlying_proof = Fn.id

        let sok_digest _ = ()

        let statement = Fn.id
      end

      module Ledger_proof_verifier = struct
        let verify (_: Ledger_proof.t) (_: Ledger_proof_statement.t) ~message:_
            : bool Deferred.t =
          return true
      end

      module Ledger = struct
        (*TODO: Test with a ledger that's more comprehensive*)
        type t = int ref [@@deriving sexp, bin_io, compare]

        type ledger_hash = Ledger_hash.t

        type super_transaction = Super_transaction.t [@@deriving sexp]

        module Undo = struct
          type t = super_transaction [@@deriving sexp]
        end

        let create : unit -> t = fun () -> ref 0

        let copy : t -> t = fun t -> ref !t

        let merkle_root : t -> ledger_hash = fun t -> Int.to_string !t

        let num_accounts _ = 0

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
          | Coinbase c ->
              t := !t + Currency.Amount.to_int c.amount ;
              Or_error.return (Super_transaction.Coinbase c)

        let undo_super_transaction : t -> super_transaction -> unit Or_error.t =
         fun t s ->
          let v =
            match s with
            | Transaction t' -> fst t'
            | Fee_transfer f -> Fee_transfer.fee_excess_int f
            | Coinbase c -> Currency.Amount.to_int c.amount
          in
          t := !t - v ;
          Or_error.return ()

        let undo t (txn: Undo.t) = undo_super_transaction t txn
      end

      module Sparse_ledger = struct
        type t = int [@@deriving sexp, bin_io]

        let of_ledger_subset_exn :
            Ledger.t -> Compressed_public_key.t list -> t =
         fun ledger _ -> !ledger

        let merkle_root t = Ledger.merkle_root (ref t)

        let apply_super_transaction_exn t txn =
          let l : Ledger.t = ref t in
          Or_error.ok_exn (Ledger.apply_super_transaction l txn) |> ignore ;
          !l
      end

      module Ledger_builder_aux_hash = struct
        include String

        let of_bytes : string -> t = fun s -> s
      end

      module Ledger_builder_hash = struct
        include String

        type ledger_hash = Ledger_hash.t

        type ledger_builder_aux_hash = Ledger_builder_aux_hash.t

        let of_aux_and_ledger_hash :
            ledger_builder_aux_hash -> ledger_hash -> t =
         fun ah h -> ah ^ h
      end

      module Completed_work = struct
        let proofs_length = 2

        type proof = Ledger_proof.t [@@deriving sexp, bin_io, compare]

        type statement = Ledger_proof_statement.t
        [@@deriving sexp, bin_io, compare, hash]

        type fee = Fee.Unsigned.t [@@deriving sexp, bin_io, compare]

        type public_key = Compressed_public_key.t
        [@@deriving sexp, bin_io, compare]

        module T = struct
          type t = {fee: fee; proofs: proof list; prover: public_key}
          [@@deriving sexp, bin_io, compare]
        end

        include T

        module Statement = struct
          module T = struct
            type t = statement list [@@deriving sexp, bin_io, compare, hash]
          end

          include T
          include Hashable.Make_binable (T)

          let gen =
            Quickcheck.Generator.list_with_length proofs_length
              Ledger_proof_statement.gen
        end

        type unchecked = t

        module Checked = struct
          include T

          let create_unsafe = Fn.id
        end

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

        type public_key = Compressed_public_key.t
        [@@deriving sexp, bin_io, compare]

        type ledger_builder_hash = Ledger_builder_hash.t
        [@@deriving sexp, bin_io, compare]

        module At_most_two = struct
          type 'a t =
            | Zero
            | One of 'a option
            | Two of ('a * 'a option) option
          [@@deriving sexp, bin_io]

          let increase t ws =
            match (t, ws) with
            | Zero, [] -> Ok (One None)
            | Zero, [a] -> Ok (One (Some a))
            | One _, [] -> Ok (Two None)
            | One _, [a] -> Ok (Two (Some (a, None)))
            | One _, [a; a'] -> Ok (Two (Some (a', Some a)))
            | _ -> Or_error.error_string "Error incrementing coinbase parts"
        end

        module At_most_one = struct
          type 'a t = Zero | One of 'a option [@@deriving sexp, bin_io]

          let increase t ws =
            match (t, ws) with
            | Zero, [] -> Ok (One None)
            | Zero, [a] -> Ok (One (Some a))
            | _ -> Or_error.error_string "Error incrementing coinbase parts"
        end

        type diff =
          {completed_works: completed_work list; transactions: transaction list}
        [@@deriving sexp, bin_io]

        type diff_with_at_most_two_coinbase =
          {diff: diff; coinbase_parts: completed_work At_most_two.t}
        [@@deriving sexp, bin_io]

        type diff_with_at_most_one_coinbase =
          {diff: diff; coinbase_added: completed_work At_most_one.t}
        [@@deriving sexp, bin_io]

        type pre_diffs =
          ( diff_with_at_most_one_coinbase
          , diff_with_at_most_two_coinbase * diff_with_at_most_one_coinbase )
          Either.t
        [@@deriving sexp, bin_io]

        type t =
          { pre_diffs: pre_diffs
          ; prev_hash: ledger_builder_hash
          ; creator: public_key }
        [@@deriving sexp, bin_io]

        module With_valid_signatures_and_proofs = struct
          type diff =
            { completed_works: completed_work_checked list
            ; transactions: transaction_with_valid_signature list }
          [@@deriving sexp]

          type diff_with_at_most_two_coinbase =
            {diff: diff; coinbase_parts: completed_work_checked At_most_two.t}
          [@@deriving sexp]

          type diff_with_at_most_one_coinbase =
            {diff: diff; coinbase_added: completed_work_checked At_most_one.t}
          [@@deriving sexp]

          type pre_diffs =
            ( diff_with_at_most_one_coinbase
            , diff_with_at_most_two_coinbase * diff_with_at_most_one_coinbase
            )
            Either.t
          [@@deriving sexp, bin_io]

          type t =
            { pre_diffs: pre_diffs
            ; prev_hash: ledger_builder_hash
            ; creator: public_key }
          [@@deriving sexp]

          let transactions t =
            Either.value_map t.pre_diffs
              ~first:(fun d -> d.diff.transactions)
              ~second:(fun d ->
                (fst d).diff.transactions @ (snd d).diff.transactions )
        end

        let forget_diff
            {With_valid_signatures_and_proofs.completed_works; transactions} =
          { completed_works= List.map ~f:Completed_work.forget completed_works
          ; transactions= (transactions :> Transaction.t list) }

        let forget_work_opt = Option.map ~f:Completed_work.forget

        let forget_pre_diff_with_at_most_two
            {With_valid_signatures_and_proofs.diff; coinbase_parts} =
          let forget_cw =
            match coinbase_parts with
            | At_most_two.Zero -> At_most_two.Zero
            | One cw -> One (forget_work_opt cw)
            | Two cw_pair ->
                Two
                  (Option.map cw_pair ~f:(fun (cw, cw_opt) ->
                       (Completed_work.forget cw, forget_work_opt cw_opt) ))
          in
          {diff= forget_diff diff; coinbase_parts= forget_cw}

        let forget_pre_diff_with_at_most_one
            {With_valid_signatures_and_proofs.diff; coinbase_added} =
          let forget_cw =
            match coinbase_added with
            | At_most_one.Zero -> At_most_one.Zero
            | One cw -> One (forget_work_opt cw)
          in
          {diff= forget_diff diff; coinbase_added= forget_cw}

        let forget (t: With_valid_signatures_and_proofs.t) =
          { pre_diffs=
              Either.map t.pre_diffs ~first:forget_pre_diff_with_at_most_one
                ~second:(fun d ->
                  ( forget_pre_diff_with_at_most_two (fst d)
                  , forget_pre_diff_with_at_most_one (snd d) ) )
          ; prev_hash= t.prev_hash
          ; creator= t.creator }

        let transactions (t: t) =
          Either.value_map t.pre_diffs
            ~first:(fun d -> d.diff.transactions)
            ~second:(fun d ->
              (fst d).diff.transactions @ (snd d).diff.transactions )
      end

      module Config = struct
        let transaction_capacity_log_2 = 7
      end

      let check :
             Completed_work.t
          -> Completed_work.statement list
          -> Completed_work.Checked.t option Deferred.t =
       fun {fee= f; proofs= p; prover= pr} _ ->
        Deferred.return
        @@ Some {Completed_work.Checked.fee= f; proofs= p; prover= pr}
    end

    module Lb = Make (Test_input1)

    let self_pk = "me"

    let stmt_to_work (stmts: Test_input1.Completed_work.Statement.t) :
        Test_input1.Completed_work.Checked.t option =
      let prover =
        List.fold stmts ~init:"P" ~f:(fun p stmt -> p ^ stmt.target)
      in
      Some
        { Test_input1.Completed_work.Checked.fee= Fee.Unsigned.of_int 1
        ; proofs= stmts
        ; prover }

    let create_and_apply lb logger txns stmt_to_work =
      let diff, _, _ =
        Lb.create_diff lb ~logger ~transactions_by_fee:txns
          ~get_completed_work:stmt_to_work
      in
      let%map ledger_proof =
        Lb.apply lb (Test_input1.Ledger_builder_diff.forget diff)
      in
      (ledger_proof, Test_input1.Ledger_builder_diff.forget diff)

    let txns n f g = List.zip_exn (List.init n ~f) (List.init n ~f:g)

    let coinbase_added_first_prediff = function
      | Test_input1.Ledger_builder_diff.At_most_two.Zero -> 0
      | One _ -> 1
      | _ -> 2

    let coinbase_added_second_prediff = function
      | Test_input1.Ledger_builder_diff.At_most_one.Zero -> 0
      | _ -> 1

    let coinbase_added (diff: Test_input1.Ledger_builder_diff.t) =
      match diff.pre_diffs with
      | First d -> coinbase_added_second_prediff d.coinbase_added
      | Second (d1, d2) ->
          let x = coinbase_added_first_prediff d1.coinbase_parts in
          let y = coinbase_added_second_prediff d2.coinbase_added in
          x + y

    let assert_at_least_coinbase_added txns cb = assert (txns > 0 || cb > 0)

    let expected_ledger no_txns_included txns_sent old_ledger =
      old_ledger
      + Currency.Amount.to_int Protocols.Coda_praos.coinbase_amount
      + List.sum
          (module Int)
          (List.take txns_sent no_txns_included)
          ~f:(fun (t, fee) -> t + fee)

    let%test_unit "Max throughput" =
      (*Always at worst case number of provers*)
      let logger = Logger.create () in
      let p = Int.pow 2 (Test_input1.Config.transaction_capacity_log_2 + 1) in
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
              let%map proof, diff =
                create_and_apply lb logger (Sequence.of_list all_ts)
                  stmt_to_work
              in
              let fee_excess =
                Option.value_map ~default:Currency.Fee.Signed.zero
                  (Or_error.ok_exn proof) ~f:(fun proof ->
                    let stmt = Test_input1.Ledger_proof.statement proof in
                    stmt.fee_excess )
              in
              (*fee_excess at the top should always be zero*)
              assert (
                Currency.Fee.Signed.equal fee_excess Currency.Fee.Signed.zero
              ) ;
              let cb = coinbase_added diff in
              (*At worst case number of provers coinbase should not be split more than two times*)
              assert (cb > 0 && cb < 3) ;
              let x =
                List.length (Test_input1.Ledger_builder_diff.transactions diff)
              in
              assert_at_least_coinbase_added x cb ;
              let expected_value = expected_ledger x all_ts old_ledger in
              assert (!(Lb.ledger lb) = expected_value) ) )

    let%test_unit "Be able to include random number of transactions" =
      (*Always at worst case number of provers*)
      Backtrace.elide := false ;
      let logger = Logger.create () in
      let p = Int.pow 2 (Test_input1.Config.transaction_capacity_log_2 + 1) in
      let g = Int.gen_incl 1 p in
      let initial_ledger = ref 0 in
      let lb = Lb.create ~ledger:initial_ledger ~self:self_pk in
      Quickcheck.test g ~trials:1000 ~f:(fun i ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              let open Deferred.Let_syntax in
              let old_ledger = !(Lb.ledger lb) in
              let all_ts = txns p (fun x -> (x + 1) * 100) (fun _ -> 4) in
              let ts = List.take all_ts i in
              let%map proof, diff =
                create_and_apply lb logger (Sequence.of_list ts) stmt_to_work
              in
              let fee_excess =
                Option.value_map ~default:Currency.Fee.Signed.zero
                  (Or_error.ok_exn proof) ~f:(fun proof ->
                    let stmt = Test_input1.Ledger_proof.statement proof in
                    stmt.fee_excess )
              in
              (*fee_excess at the top should always be zero*)
              assert (
                Currency.Fee.Signed.equal fee_excess Currency.Fee.Signed.zero
              ) ;
              let cb = coinbase_added diff in
              (*At worst case number of provers coinbase should not be split more than two times*)
              assert (cb > 0 && cb < 3) ;
              let x =
                List.length (Test_input1.Ledger_builder_diff.transactions diff)
              in
              assert_at_least_coinbase_added x cb ;
              let expected_value = expected_ledger x all_ts old_ledger in
              assert (!(Lb.ledger lb) = expected_value) ) )

    let%test_unit "Random workspec chunk doesn't send same things again" =
      (*Always at worst case number of provers*)
      let logger = Logger.create () in
      Backtrace.elide := false ;
      let p = Int.pow 2 (Test_input1.Config.transaction_capacity_log_2 + 1) in
      let g = Int.gen_incl 1 p in
      let initial_ledger = ref 0 in
      let lb = Lb.create ~ledger:initial_ledger ~self:self_pk in
      let module S = Test_input1.Ledger_proof_statement.Set in
      Quickcheck.test g ~trials:100 ~f:(fun i ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              let open Deferred.Let_syntax in
              let all_ts = txns p (fun x -> (x + 1) * 100) (fun _ -> 4) in
              let ts = List.take all_ts i in
              let%map _, _ =
                create_and_apply lb logger (Sequence.of_list ts) stmt_to_work
              in
              (* A bit of a roundabout way to check, but essentially, if it
               * does not give repeats then our loop will not iterate more than
               * parallelism times. See random work description for
               * explanation. *)
              let rec go i seen =
                [%test_result : Bool.t]
                  ~message:"Exceeded time expected to exhaust random_work"
                  ~expect:true
                  (i <= 2 * p) ;
                let maybe_stuff, seen = Lb.random_work_spec_chunk lb seen in
                match maybe_stuff with None -> () | Some _ -> go (i + 1) seen
              in
              go 0 (S.empty, None) ) )

    let%test_unit "Be able to include random number of transactions (One \
                   prover)" =
      let get_work (stmts: Test_input1.Completed_work.Statement.t) :
          Test_input1.Completed_work.Checked.t option =
        Some
          { Test_input1.Completed_work.Checked.fee= Fee.Unsigned.of_int 1
          ; proofs= stmts
          ; prover= "P" }
      in
      Backtrace.elide := false ;
      let logger = Logger.create () in
      let p = Int.pow 2 (Test_input1.Config.transaction_capacity_log_2 + 1) in
      let g = Int.gen_incl 1 p in
      let initial_ledger = ref 0 in
      let lb = Lb.create ~ledger:initial_ledger ~self:self_pk in
      Quickcheck.test g ~trials:1000 ~f:(fun i ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              let open Deferred.Let_syntax in
              let old_ledger = !(Lb.ledger lb) in
              let all_ts = txns p (fun x -> (x + 1) * 100) (fun _ -> 4) in
              let ts = List.take all_ts i in
              let%map proof, diff =
                create_and_apply lb logger (Sequence.of_list ts) get_work
              in
              let fee_excess =
                Option.value_map ~default:Currency.Fee.Signed.zero
                  (Or_error.ok_exn proof) ~f:(fun proof ->
                    let stmt = Test_input1.Ledger_proof.statement proof in
                    stmt.fee_excess )
              in
              (*fee_excess at the top should always be zero*)
              assert (
                Currency.Fee.Signed.equal fee_excess Currency.Fee.Signed.zero
              ) ;
              let cb = coinbase_added diff in
              (*With just one prover, coinbase should never be split*)
              assert (cb = 1) ;
              let x =
                List.length (Test_input1.Ledger_builder_diff.transactions diff)
              in
              assert_at_least_coinbase_added x cb ;
              let expected_value = expected_ledger x all_ts old_ledger in
              assert (!(Lb.ledger lb) = expected_value) ) )
  end )
