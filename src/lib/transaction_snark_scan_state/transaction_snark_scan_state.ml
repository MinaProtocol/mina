open Core_kernel
open Protocols

let option lab =
  Option.value_map ~default:(Or_error.error_string lab) ~f:(fun x -> Ok x)

let map2_or_error xs ys ~f =
  let rec go xs ys acc =
    match (xs, ys) with
    | [], [] -> Ok (List.rev acc)
    | x :: xs, y :: ys -> (
      match f x y with Error e -> Error e | Ok z -> go xs ys (z :: acc) )
    | _, _ -> Or_error.error_string "Length mismatch"
  in
  go xs ys []

module type Monad_with_Or_error_intf = sig
  type 'a t

  include Monad.S with type 'a t := 'a t

  module Or_error : sig
    type nonrec 'a t = 'a Or_error.t t

    include Monad.S with type 'a t := 'a t
  end
end

module Make (Inputs : Inputs.S) : sig
  include
    Coda_pow.Transaction_snark_scan_state_intf
    with type ledger := Inputs.Ledger.t
     and type transaction_snark_work := Inputs.Transaction_snark_work.t
     and type ledger_proof := Inputs.Ledger_proof.t
     and type sparse_ledger := Inputs.Sparse_ledger.t
     and type ledger_proof_statement := Inputs.Ledger_proof_statement.t
     and type transaction := Inputs.Transaction.t
     and type transaction_with_info := Inputs.Ledger.Undo.t
     and type frozen_ledger_hash := Inputs.Frozen_ledger_hash.t
     and type sok_message := Inputs.Sok_message.t
     and type staged_ledger_aux_hash := Inputs.Staged_ledger_aux_hash.t
     and type transaction_snark_work_statement :=
                Inputs.Transaction_snark_work.Statement.t
end = struct
  open Inputs

  module Transaction_with_witness = struct
    (* TODO: The statement is redundant here - it can be computed from the witness and the transaction *)
    type t =
      { transaction_with_info: Ledger.Undo.t
      ; statement: Ledger_proof_statement.t
      ; witness: Inputs.Sparse_ledger.t }
    [@@deriving sexp, bin_io]
  end

  module Ledger_proof_with_sok_message = struct
    type t = Ledger_proof.t * Sok_message.t [@@deriving sexp, bin_io]
  end

  module Available_job = struct
    type t =
      ( Ledger_proof_with_sok_message.t
      , Transaction_with_witness.t )
      Parallel_scan.Available_job.t
    [@@deriving sexp]
  end

  module Job_view = struct
    type t = Ledger_proof_statement.t Parallel_scan.Job_view.t
    [@@deriving sexp]

    let to_yojson ((pos, job) : t) : Yojson.Safe.json =
      let hash_string h = Sexp.to_string (Frozen_ledger_hash.sexp_of_t h) in
      let statement_to_yojson (s : Ledger_proof_statement.t) =
        `Assoc
          [ ("Source", `String (hash_string s.source))
          ; ("Target", `String (hash_string s.target))
          ; ("Fee Excess", Currency.Fee.Signed.to_yojson s.fee_excess)
          ; ("Supply Increase", Currency.Amount.to_yojson s.supply_increase) ]
      in
      let opt_json x =
        Option.value_map x ~default:(`List []) ~f:statement_to_yojson
      in
      let job_to_yojson =
        match job with
        | Merge (x, y) -> `Assoc [("M", `List [opt_json x; opt_json y])]
        | Base x -> `Assoc [("B", `List [opt_json x])]
      in
      `List [`Int pos; job_to_yojson]
  end

  type job = Available_job.t [@@deriving sexp]

  type parallel_scan_completed_job =
    Ledger_proof_with_sok_message.t Parallel_scan.State.Completed_job.t
  [@@deriving sexp, bin_io]

  module T = struct
    type t =
      ( Ledger_proof_with_sok_message.t
      , Transaction_with_witness.t )
      Parallel_scan.State.t
    [@@deriving sexp, bin_io]
  end

  include T

  let hash t =
    let state_hash =
      Parallel_scan.State.hash t
        (Binable.to_string (module Ledger_proof_with_sok_message))
        (Binable.to_string (module Transaction_with_witness))
    in
    Staged_ledger_aux_hash.of_bytes (state_hash :> string)

  let is_valid t =
    let k = max Config.work_availability_factor 2 in
    Parallel_scan.parallelism ~state:t
    = Int.pow 2 (Config.transaction_capacity_log_2 + k)
    && Parallel_scan.is_valid t

  include Binable.Of_binable
            (T)
            (struct
              type nonrec t = t

              let to_binable = Fn.id

              let of_binable t =
                assert (is_valid t) ;
                t
            end)

  (**********Helpers*************)

  let create_expected_statement
      {Transaction_with_witness.transaction_with_info; witness; _} =
    let open Or_error.Let_syntax in
    let source =
      Frozen_ledger_hash.of_ledger_hash @@ Sparse_ledger.merkle_root witness
    in
    let%bind transaction = Ledger.Undo.transaction transaction_with_info in
    let%bind after =
      Or_error.try_with (fun () ->
          Sparse_ledger.apply_transaction_exn witness transaction )
    in
    let target =
      Frozen_ledger_hash.of_ledger_hash @@ Sparse_ledger.merkle_root after
    in
    let%bind fee_excess = Transaction.fee_excess transaction in
    let%map supply_increase = Transaction.supply_increase transaction in
    { Ledger_proof_statement.source
    ; target
    ; fee_excess
    ; supply_increase
    ; proof_type= `Base }

  let completed_work_to_scanable_work (job : job) (fee, current_proof, prover)
      : parallel_scan_completed_job Or_error.t =
    let sok_digest = Ledger_proof.sok_digest current_proof
    and proof = Ledger_proof.underlying_proof current_proof in
    match job with
    | Base ({statement; _}, _) ->
        let ledger_proof = Ledger_proof.create ~statement ~sok_digest ~proof in
        Ok (Lifted (ledger_proof, Sok_message.create ~fee ~prover))
    | Merge ((p, _), (p', _), _) ->
        let s = Ledger_proof.statement p and s' = Ledger_proof.statement p' in
        let open Or_error.Let_syntax in
        let%map fee_excess =
          Currency.Fee.Signed.add s.fee_excess s'.fee_excess
          |> option "Error adding fees"
        and supply_increase =
          Currency.Amount.add s.supply_increase s'.supply_increase
          |> option "Error adding supply_increases"
        in
        let statement =
          { Ledger_proof_statement.source= s.source
          ; target= s'.target
          ; supply_increase
          ; fee_excess
          ; proof_type= `Merge }
        in
        Parallel_scan.State.Completed_job.Merged
          ( Ledger_proof.create ~statement ~sok_digest ~proof
          , Sok_message.create ~fee ~prover )

  let total_proofs (works : Transaction_snark_work.t list) =
    List.sum (module Int) works ~f:(fun w -> List.length w.proofs)

  (*************exposed functions*****************)

  module Make_statement_scanner
      (M : Monad_with_Or_error_intf) (Verifier : sig
          val verify :
               Ledger_proof.t
            -> Ledger_proof_statement.t
            -> message:Sok_message.t
            -> sexp_bool M.t
      end) =
  struct
    module Fold = Parallel_scan.State.Make_foldable (M)

    let scan_statement t :
        (Ledger_proof_statement.t, [`Error of Error.t | `Empty]) Result.t M.t =
      let write_error description =
        sprintf !"Staged_ledger.scan_statement: %s\n" description
      in
      let open M.Let_syntax in
      let with_error ~f message =
        let%map result = f () in
        Result.map_error result ~f:(fun e ->
            Error.createf !"%s: %{sexp:Error.t}" (write_error message) e )
      in
      let merge_acc ~verify_proof (acc : Ledger_proof_statement.t option) s2 :
          Ledger_proof_statement.t option M.Or_error.t =
        let with_verification ~f =
          M.map (verify_proof ()) ~f:(fun is_verified ->
              if not is_verified then
                Or_error.error_string (write_error "Bad merge proof")
              else f () )
        in
        let open Or_error.Let_syntax in
        with_error "Bad merge proof" ~f:(fun () ->
            match acc with
            | None -> with_verification ~f:(fun () -> return (Some s2))
            | Some s1 ->
                with_verification ~f:(fun () ->
                    let%map merged_statement =
                      Ledger_proof_statement.merge s1 s2
                    in
                    Some merged_statement ) )
      in
      let fold_step acc_statement job =
        match job with
        | Parallel_scan.State.Job.Merge (Rcomp (p, message))
         |Merge (Lcomp (p, message)) ->
            merge_acc
              ~verify_proof:(fun () ->
                Verifier.verify ~message p (Ledger_proof.statement p) )
              acc_statement (Ledger_proof.statement p)
        | Merge Empty -> M.Or_error.return acc_statement
        | Merge (Bcomp ((proof_1, message_1), (proof_2, message_2), _place)) ->
            let open M.Or_error.Let_syntax in
            let%bind merged_statement =
              M.return
              @@ Ledger_proof_statement.merge
                   (Ledger_proof.statement proof_1)
                   (Ledger_proof.statement proof_2)
            in
            merge_acc acc_statement merged_statement ~verify_proof:(fun () ->
                let open M.Let_syntax in
                let%map verified_list =
                  M.all
                    (List.map [(proof_1, message_1); (proof_2, message_2)]
                       ~f:(fun (proof, message) ->
                         Verifier.verify ~message proof
                           (Ledger_proof.statement proof) ))
                in
                List.for_all verified_list ~f:Fn.id )
        | Base None -> M.Or_error.return acc_statement
        | Base (Some (transaction, _place)) ->
            with_error "Bad base statement" ~f:(fun () ->
                let open M.Or_error.Let_syntax in
                let%bind expected_statement =
                  M.return (create_expected_statement transaction)
                in
                if
                  Ledger_proof_statement.equal transaction.statement
                    expected_statement
                then
                  merge_acc
                    ~verify_proof:(fun () -> M.return true)
                    acc_statement transaction.statement
                else
                  M.return
                  @@ Or_error.error_string (write_error "Bad base statement")
            )
      in
      let res =
        Fold.fold_chronological_until t ~init:None
          ~finish:(Fn.compose M.return Result.return) ~f:(fun acc job ->
            let open Container.Continue_or_stop in
            match%map fold_step acc job with
            | Ok next -> Continue next
            | Error e -> Stop (Error e) )
      in
      match%map res with
      | Ok None -> Error `Empty
      | Ok (Some res) -> Ok res
      | Error e -> Error (`Error e)

    let check_invariants t ~error_prefix ledger snarked_ledger_hash =
      let clarify_error cond err =
        if not cond then Or_error.errorf "%s : %s" error_prefix err else Ok ()
      in
      let open M.Let_syntax in
      match%map scan_statement t with
      | Error (`Error e) -> Error e
      | Error `Empty ->
          let current_ledger_hash =
            Ledger.merkle_root ledger |> Frozen_ledger_hash.of_ledger_hash
          in
          Option.value_map ~default:(Ok ()) snarked_ledger_hash ~f:(fun hash ->
              clarify_error
                (Frozen_ledger_hash.equal hash current_ledger_hash)
                "did not connect with snarked ledger hash" )
      | Ok {fee_excess; source; target; supply_increase= _; proof_type= _} ->
          let open Or_error.Let_syntax in
          let%map () =
            Option.value_map ~default:(Ok ()) snarked_ledger_hash
              ~f:(fun hash ->
                clarify_error
                  (Frozen_ledger_hash.equal hash source)
                  "did not connect with snarked ledger hash" )
          and () =
            clarify_error
              (Frozen_ledger_hash.equal
                 ( Ledger.merkle_root ledger
                 |> Frozen_ledger_hash.of_ledger_hash )
                 target)
              "incorrect statement target hash"
          and () =
            clarify_error
              (Currency.Fee.Signed.equal Currency.Fee.Signed.zero fee_excess)
              "nonzero fee excess"
          in
          ()
  end

  let statement_of_job : job -> Ledger_proof_statement.t option = function
    | Base ({statement; _}, _) -> Some statement
    | Merge ((p1, _), (p2, _), _) ->
        let stmt1 = Ledger_proof.statement p1
        and stmt2 = Ledger_proof.statement p2 in
        let open Option.Let_syntax in
        let%bind () =
          Option.some_if
            (Frozen_ledger_hash.equal stmt1.target stmt2.source)
            ()
        in
        let%map fee_excess =
          Currency.Fee.Signed.add stmt1.fee_excess stmt2.fee_excess
        and supply_increase =
          Currency.Amount.add stmt1.supply_increase stmt2.supply_increase
        in
        { Ledger_proof_statement.source= stmt1.source
        ; target= stmt2.target
        ; supply_increase
        ; fee_excess
        ; proof_type= `Merge }

  let capacity t = Parallel_scan.parallelism ~state:t

  let create ~transaction_capacity_log_2 =
    (* Transaction capacity log_2 is 1/2^work_availability_factor the capacity for work parallelism *)
    let k = max Config.work_availability_factor 2 in
    Parallel_scan.start ~parallelism_log_2:(transaction_capacity_log_2 + k)

  let empty () =
    let open Config in
    create ~transaction_capacity_log_2

  let fill_work_and_enqueue_transactions t transactions work =
    let open Or_error.Let_syntax in
    let enqueue_transactions t transactions =
      Parallel_scan.enqueue_data ~state:t ~data:transactions
    in
    let fill_in_transaction_snark_work t
        (works : Transaction_snark_work.t list) :
        Ledger_proof.t option Or_error.t =
      let%bind next_jobs =
        Parallel_scan.next_k_jobs ~state:t ~k:(total_proofs works)
      in
      let%bind scanable_work_list =
        map2_or_error next_jobs
          (List.concat_map works
             ~f:(fun {Transaction_snark_work.fee; proofs; prover} ->
               List.map proofs ~f:(fun proof -> (fee, proof, prover)) ))
          ~f:completed_work_to_scanable_work
      in
      let%map result =
        Parallel_scan.fill_in_completed_jobs ~state:t
          ~completed_jobs:scanable_work_list
      in
      Option.map result ~f:fst
    in
    let%bind () = Parallel_scan.update_curr_job_seq_no t in
    let%bind proof_opt = fill_in_transaction_snark_work t work in
    let%map () = enqueue_transactions t transactions in
    proof_opt

  let latest_ledger_proof = Parallel_scan.last_emitted_value

  let free_space t = Parallel_scan.free_space ~state:t

  let next_k_jobs t ~k = Parallel_scan.next_k_jobs ~state:t ~k

  let next_jobs t = Parallel_scan.next_jobs ~state:t

  let next_jobs_sequence t = Parallel_scan.next_jobs_sequence ~state:t

  let staged_transactions t =
    List.map (Parallel_scan.current_data t)
      ~f:(fun (t : Transaction_with_witness.t) -> t.transaction_with_info )

  let copy = Parallel_scan.State.copy

  let partition_if_overflowing t ~max_slots =
    Parallel_scan.partition_if_overflowing t ~max_slots

  let current_job_sequence_number = Parallel_scan.current_job_sequence_number

  let extract_from_job (job : job) =
    match job with
    | Parallel_scan.Available_job.Base (d, _) ->
        First (d.transaction_with_info, d.statement, d.witness)
    | Merge ((p1, _), (p2, _), _) -> Second (p1, p2)

  let filter_jobs_by_seq_no t =
    let open Or_error.Let_syntax in
    let current_seq = Parallel_scan.current_job_sequence_number t in
    let min_seq_no = max 0 (current_seq - Config.work_availability_factor) in
    let%map all_jobs = next_jobs_sequence t in
    Sequence.filter all_jobs ~f:(fun job ->
        let cur_seq =
          match job with
          | Parallel_scan.Available_job.Base (_, seq) -> seq
          | Merge (_, _, seq) -> seq
        in
        cur_seq <= min_seq_no )

  let snark_job_list_json t =
    let all_jobs : Job_view.t list =
      let fa (a : Ledger_proof_with_sok_message.t) =
        Ledger_proof.statement (fst a)
      in
      let fd (d : Transaction_with_witness.t) = d.statement in
      Parallel_scan.view_jobs_with_position t fa fd
    in
    Yojson.Safe.to_string (`List (List.map all_jobs ~f:Job_view.to_yojson))

  let sequence_chunks_of seq ~n =
    Sequence.unfold_step ~init:([], 0, seq) ~f:(fun (acc, i, seq) ->
        if i = n then Yield (List.rev acc, ([], 0, seq))
        else
          match Sequence.next seq with
          | None -> Done
          (* skip the last one if it's odd*)
          (*| Some (x, seq) -> (
            (*allow a chunk of 1 proof as well*)
            match Sequence.next seq with
            | None -> Yield (List.rev (x :: acc), ([], 0, seq))*)
          | Some (x, seq) -> Skip (x :: acc, i + 1, seq) )

  let all_work_to_do scan_state :
      Transaction_snark_work.Statement.t Sequence.t Or_error.t =
    let open Or_error.Let_syntax in
    let%map work_seq = next_jobs_sequence scan_state in
    Sequence.chunks_exn
      (Sequence.map work_seq ~f:(fun maybe_work ->
           match statement_of_job maybe_work with
           | None -> assert false
           | Some work -> work ))
      Transaction_snark_work.proofs_length

  let min_work_to_do scan_state :
      Transaction_snark_work.Statement.t Sequence.t Or_error.t =
    let open Or_error.Let_syntax in
    let%map work_seq = filter_jobs_by_seq_no scan_state in
    Core.printf "work count: %d \n %!" (Sequence.length work_seq) ;
    sequence_chunks_of ~n:Transaction_snark_work.proofs_length
    @@ Sequence.map work_seq ~f:(fun maybe_work ->
           match statement_of_job maybe_work with
           | None -> assert false
           | Some work -> work )
end
