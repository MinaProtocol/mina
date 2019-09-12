open Core_kernel
open Coda_base
open Module_version

let option lab =
  Option.value_map ~default:(Or_error.error_string lab) ~f:(fun x -> Ok x)

let map2_or_error xs ys ~f =
  let rec go xs ys acc =
    match (xs, ys) with
    | [], [] ->
        Ok (List.rev acc)
    | x :: xs, y :: ys -> (
      match f x y with Error e -> Error e | Ok z -> go xs ys (z :: acc) )
    | _, _ ->
        Or_error.error_string "Length mismatch"
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

module Transaction_with_witness = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        (* TODO: The statement is redundant here - it can be computed from the witness and the transaction *)
        type t =
          { transaction_with_info: Ledger.Undo.Stable.V1.t
          ; statement: Transaction_snark.Statement.Stable.V1.t
          ; witness: Transaction_witness.Stable.V1.t sexp_opaque }
        [@@deriving sexp, bin_io, version]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "transaction_snark_scan_state_transaction_with_witness"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  type t = Stable.Latest.t =
    { transaction_with_info: Ledger.Undo.t
    ; statement: Transaction_snark.Statement.t
    ; witness: Transaction_witness.t sexp_opaque }
  [@@deriving sexp]
end

module Ledger_proof_with_sok_message = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Ledger_proof.Stable.V1.t * Sok_message.Stable.V1.t
        [@@deriving sexp, bin_io, version]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "transaction_snark_scan_state_ledger_proof_with_sok_message"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  type t = Ledger_proof.t * Sok_message.t [@@deriving sexp]
end

module Available_job = struct
  type t =
    ( Ledger_proof_with_sok_message.t
    , Transaction_with_witness.t )
    Parallel_scan.Available_job.t
  [@@deriving sexp]
end

module Space_partition = Parallel_scan.Space_partition

module Job_view = struct
  type t = Transaction_snark.Statement.t Parallel_scan.Job_view.t
  [@@deriving sexp]

  let to_yojson ({value; position} : t) : Yojson.Safe.json =
    let hash_string h = Sexp.to_string (Frozen_ledger_hash.sexp_of_t h) in
    let statement_to_yojson (s : Transaction_snark.Statement.t) =
      `Assoc
        [ ("Work_id", `Int (Transaction_snark.Statement.hash s))
        ; ("Source", `String (hash_string s.source))
        ; ("Target", `String (hash_string s.target))
        ; ("Fee Excess", Currency.Fee.Signed.to_yojson s.fee_excess)
        ; ("Supply Increase", Currency.Amount.to_yojson s.supply_increase) ]
    in
    let job_to_yojson =
      match value with
      | BEmpty ->
          `Assoc [("B", `List [])]
      | MEmpty ->
          `Assoc [("M", `List [])]
      | MPart x ->
          `Assoc [("M", `List [statement_to_yojson x])]
      | MFull (x, y, {seq_no; status}) ->
          `Assoc
            [ ( "M"
              , `List
                  [ statement_to_yojson x
                  ; statement_to_yojson y
                  ; `Int seq_no
                  ; `Assoc
                      [ ( "Status"
                        , `String (Parallel_scan.Job_status.to_string status)
                        ) ] ] ) ]
      | BFull (x, {seq_no; status}) ->
          `Assoc
            [ ( "B"
              , `List
                  [ statement_to_yojson x
                  ; `Int seq_no
                  ; `Assoc
                      [ ( "Status"
                        , `String (Parallel_scan.Job_status.to_string status)
                        ) ] ] ) ]
    in
    `List [`Int position; job_to_yojson]
end

type job = Available_job.t [@@deriving sexp]

module Stable = struct
  module V1 = struct
    module T = struct
      type t =
        ( Ledger_proof_with_sok_message.Stable.V1.t
        , Transaction_with_witness.Stable.V1.t )
        Parallel_scan.State.Stable.V1.t
      [@@deriving sexp, bin_io, version]
    end

    include T
    include Registration.Make_latest_version (T)

    let hash t =
      let state_hash =
        Parallel_scan.State.hash t
          (Binable.to_string (module Ledger_proof_with_sok_message.Stable.V1))
          (Binable.to_string (module Transaction_with_witness.Stable.V1))
      in
      Staged_ledger_hash.Aux_hash.of_bytes
        (state_hash |> Digestif.SHA256.to_raw_string)

    include Binable.Of_binable
              (T)
              (struct
                type nonrec t = t

                let to_binable = Fn.id

                let of_binable = Fn.id
              end)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "transaction_snark_scan_state"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

type t = Stable.Latest.t [@@deriving sexp]

[%%define_locally
Stable.Latest.(hash)]

(**********Helpers*************)

let create_expected_statement
    {Transaction_with_witness.transaction_with_info; witness; statement} =
  let open Or_error.Let_syntax in
  let source =
    Frozen_ledger_hash.of_ledger_hash
    @@ Sparse_ledger.merkle_root witness.ledger
  in
  let%bind transaction = Ledger.Undo.transaction transaction_with_info in
  let%bind after =
    Or_error.try_with (fun () ->
        Sparse_ledger.apply_transaction_exn witness.ledger transaction )
  in
  let target =
    Frozen_ledger_hash.of_ledger_hash @@ Sparse_ledger.merkle_root after
  in
  let pending_coinbase_before =
    statement.pending_coinbase_stack_state.source
  in
  let pending_coinbase_after =
    match transaction with
    | Coinbase c ->
        Pending_coinbase.Stack.push pending_coinbase_before c
    | _ ->
        pending_coinbase_before
  in
  let%bind fee_excess = Transaction.fee_excess transaction in
  let%map supply_increase = Transaction.supply_increase transaction in
  { Transaction_snark.Statement.source
  ; target
  ; fee_excess
  ; supply_increase
  ; pending_coinbase_stack_state=
      { Transaction_snark.Pending_coinbase_stack_state.source=
          pending_coinbase_before
      ; target= pending_coinbase_after }
  ; proof_type= `Base }

let completed_work_to_scanable_work (job : job) (fee, current_proof, prover) :
    'a Or_error.t =
  let sok_digest = Ledger_proof.sok_digest current_proof
  and proof = Ledger_proof.underlying_proof current_proof in
  match job with
  | Base {statement; _} ->
      let ledger_proof = Ledger_proof.create ~statement ~sok_digest ~proof in
      Ok (ledger_proof, Sok_message.create ~fee ~prover)
  | Merge ((p, _), (p', _)) ->
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
        { Transaction_snark.Statement.source= s.source
        ; target= s'.target
        ; supply_increase
        ; pending_coinbase_stack_state=
            { source= s.pending_coinbase_stack_state.source
            ; target= s'.pending_coinbase_stack_state.target }
        ; fee_excess
        ; proof_type= `Merge }
      in
      ( Ledger_proof.create ~statement ~sok_digest ~proof
      , Sok_message.create ~fee ~prover )

let total_proofs (works : Transaction_snark_work.t list) =
  List.sum (module Int) works ~f:(fun w -> One_or_two.length w.proofs)

(*************exposed functions*****************)

module Make_statement_scanner
    (M : Monad_with_Or_error_intf) (Verifier : sig
        type t

        val verify :
             verifier:t
          -> proof:Ledger_proof.t
          -> statement:Transaction_snark.Statement.t
          -> message:Sok_message.t
          -> sexp_bool M.t
    end) =
struct
  module Fold = Parallel_scan.State.Make_foldable (M)

  (*TODO: fold over the pending_coinbase tree and validate the statements?*)
  let scan_statement tree ~verifier :
      (Transaction_snark.Statement.t, [`Error of Error.t | `Empty]) Result.t
      M.t =
    let write_error description =
      sprintf !"Staged_ledger.scan_statement: %s\n" description
    in
    let open M.Let_syntax in
    let with_error ~f message =
      let%map result = f () in
      Result.map_error result ~f:(fun e ->
          Error.createf !"%s: %{sexp:Error.t}" (write_error message) e )
    in
    let merge_acc ~verify_proof (acc : Transaction_snark.Statement.t option) s2
        : Transaction_snark.Statement.t option M.Or_error.t =
      let with_verification ~f =
        M.map (verify_proof ()) ~f:(fun is_verified ->
            if not is_verified then
              Or_error.error_string (write_error "Bad merge proof")
            else f () )
      in
      let open Or_error.Let_syntax in
      with_error "Bad merge proof" ~f:(fun () ->
          match acc with
          | None ->
              with_verification ~f:(fun () -> return (Some s2))
          | Some s1 ->
              with_verification ~f:(fun () ->
                  let%map merged_statement =
                    Transaction_snark.Statement.merge s1 s2
                  in
                  Some merged_statement ) )
    in
    let fold_step_a acc_statement job =
      match job with
      | Parallel_scan.Merge.Job.Part (proof, message) ->
          let statement = Ledger_proof.statement proof in
          merge_acc
            ~verify_proof:(fun () ->
              Verifier.verify ~verifier ~message ~proof ~statement )
            acc_statement statement
      | Empty | Full {status= Parallel_scan.Job_status.Done; _} ->
          M.Or_error.return acc_statement
      | Full {left= proof_1, message_1; right= proof_2, message_2; _} ->
          let open M.Or_error.Let_syntax in
          let%bind merged_statement =
            M.return
            @@ Transaction_snark.Statement.merge
                 (Ledger_proof.statement proof_1)
                 (Ledger_proof.statement proof_2)
          in
          merge_acc acc_statement merged_statement ~verify_proof:(fun () ->
              let open M.Let_syntax in
              let%map verified_list =
                M.all
                  (List.map [(proof_1, message_1); (proof_2, message_2)]
                     ~f:(fun (proof, message) ->
                       Verifier.verify ~verifier ~proof
                         ~statement:(Ledger_proof.statement proof)
                         ~message ))
              in
              List.for_all verified_list ~f:Fn.id )
    in
    let fold_step_d acc_statement job =
      match job with
      | Parallel_scan.Base.Job.Empty
      | Full {status= Parallel_scan.Job_status.Done; _} ->
          M.Or_error.return acc_statement
      | Full {job= transaction; _} ->
          with_error "Bad base statement" ~f:(fun () ->
              let open M.Or_error.Let_syntax in
              let%bind expected_statement =
                M.return (create_expected_statement transaction)
              in
              if
                Transaction_snark.Statement.equal transaction.statement
                  expected_statement
              then
                merge_acc
                  ~verify_proof:(fun () -> M.return true)
                  acc_statement transaction.statement
              else
                M.return
                @@ Or_error.error_string (write_error "Bad base statement") )
    in
    let res =
      Fold.fold_chronological_until tree ~init:None
        ~f_merge:(fun acc (_weight, job) ->
          let open Container.Continue_or_stop in
          match%map fold_step_a acc job with
          | Ok next ->
              Continue next
          | e ->
              Stop e )
        ~f_base:(fun acc (_weight, job) ->
          let open Container.Continue_or_stop in
          match%map fold_step_d acc job with
          | Ok next ->
              Continue next
          | e ->
              Stop e )
        ~finish:(Fn.compose M.return Result.return)
    in
    match%map res with
    | Ok None ->
        Error `Empty
    | Ok (Some res) ->
        Ok res
    | Error e ->
        Error (`Error e)

  let check_invariants t ~verifier ~error_prefix
      ~ledger_hash_end:current_ledger_hash
      ~ledger_hash_begin:snarked_ledger_hash =
    let clarify_error cond err =
      if not cond then Or_error.errorf "%s : %s" error_prefix err else Ok ()
    in
    let open M.Let_syntax in
    match%map scan_statement ~verifier t with
    | Error (`Error e) ->
        Error e
    | Error `Empty ->
        let current_ledger_hash = current_ledger_hash in
        Option.value_map ~default:(Ok ()) snarked_ledger_hash ~f:(fun hash ->
            clarify_error
              (Frozen_ledger_hash.equal hash current_ledger_hash)
              "did not connect with snarked ledger hash" )
    | Ok
        { fee_excess
        ; source
        ; target
        ; supply_increase= _
        ; pending_coinbase_stack_state= _ (*TODO: check pending coinbases?*)
        ; proof_type= _ } ->
        let open Or_error.Let_syntax in
        let%map () =
          Option.value_map ~default:(Ok ()) snarked_ledger_hash ~f:(fun hash ->
              clarify_error
                (Frozen_ledger_hash.equal hash source)
                "did not connect with snarked ledger hash" )
        and () =
          clarify_error
            (Frozen_ledger_hash.equal current_ledger_hash target)
            "incorrect statement target hash"
        and () =
          clarify_error
            (Currency.Fee.Signed.equal Currency.Fee.Signed.zero fee_excess)
            "nonzero fee excess"
        in
        ()
end

module Staged_undos = struct
  type undo = Ledger.Undo.t

  type t = undo list

  let apply t ledger =
    List.fold_left t ~init:(Ok ()) ~f:(fun acc t ->
        Or_error.bind
          (Or_error.map acc ~f:(fun _ -> t))
          ~f:(fun u -> Ledger.undo ledger u) )
end

let statement_of_job : job -> Transaction_snark.Statement.t option = function
  | Base {statement; _} ->
      Some statement
  | Merge ((p1, _), (p2, _)) ->
      let stmt1 = Ledger_proof.statement p1
      and stmt2 = Ledger_proof.statement p2 in
      let open Option.Let_syntax in
      let%bind () =
        Option.some_if (Frozen_ledger_hash.equal stmt1.target stmt2.source) ()
      in
      let%map fee_excess =
        Currency.Fee.Signed.add stmt1.fee_excess stmt2.fee_excess
      and supply_increase =
        Currency.Amount.add stmt1.supply_increase stmt2.supply_increase
      in
      { Transaction_snark.Statement.source= stmt1.source
      ; target= stmt2.target
      ; supply_increase
      ; pending_coinbase_stack_state=
          { source= stmt1.pending_coinbase_stack_state.source
          ; target= stmt2.pending_coinbase_stack_state.target }
      ; fee_excess
      ; proof_type= `Merge }

let create ~work_delay ~transaction_capacity_log_2 =
  let k = Int.pow 2 transaction_capacity_log_2 in
  Parallel_scan.empty ~delay:work_delay ~max_base_jobs:k

let empty () =
  let open Constants in
  create ~work_delay ~transaction_capacity_log_2

let extract_txns txns_with_witnesses =
  (* TODO: This type checks, but are we actually pulling the inverse txn here? *)
  List.map txns_with_witnesses
    ~f:(fun (txn_with_witness : Transaction_with_witness.t) ->
      Ledger.Undo.transaction txn_with_witness.transaction_with_info
      |> Or_error.ok_exn )

let latest_ledger_proof t =
  let open Option.Let_syntax in
  let%map proof, txns_with_witnesses = Parallel_scan.last_emitted_value t in
  (proof, extract_txns txns_with_witnesses)

let free_space = Parallel_scan.free_space

(*This needs to be grouped like in work_to_do function. Group of two jobs per list and not group of two jobs after concatenating the lists*)
let all_jobs = Parallel_scan.all_jobs

let next_on_new_tree = Parallel_scan.next_on_new_tree

let base_jobs_on_latest_tree = Parallel_scan.base_jobs_on_latest_tree

(*All the transactions in the order in which they were applied*)
let staged_transactions t =
  List.map ~f:(fun (t : Transaction_with_witness.t) ->
      t.transaction_with_info |> Ledger.Undo.transaction )
  @@ Parallel_scan.pending_data t
  |> Or_error.all

(*All the staged transactions in the reverse order of their application (Latest first)*)
let staged_undos t : Staged_undos.t =
  List.map
    (Parallel_scan.pending_data t |> List.rev)
    ~f:(fun (t : Transaction_with_witness.t) -> t.transaction_with_info)

let partition_if_overflowing t =
  let bundle_count work_count = (work_count + 1) / 2 in
  let {Space_partition.first= slots, job_count; second} =
    Parallel_scan.partition_if_overflowing t
  in
  { Space_partition.first= (slots, bundle_count job_count)
  ; second=
      Option.map second ~f:(fun (slots, job_count) ->
          (slots, bundle_count job_count) ) }

let extract_from_job (job : job) =
  match job with
  | Parallel_scan.Available_job.Base d ->
      First (d.transaction_with_info, d.statement, d.witness)
  | Merge ((p1, _), (p2, _)) ->
      Second (p1, p2)

let snark_job_list_json t =
  let all_jobs : Job_view.t list list =
    let fa (a : Ledger_proof_with_sok_message.t) =
      Ledger_proof.statement (fst a)
    in
    let fd (d : Transaction_with_witness.t) = d.statement in
    Parallel_scan.view_jobs_with_position t fa fd
  in
  Yojson.Safe.to_string
    (`List
      (List.map all_jobs ~f:(fun tree ->
           `List (List.map tree ~f:Job_view.to_yojson) )))

(*Always the same pairing of jobs*)
let all_work_statements t : Transaction_snark_work.Statement.t list =
  let work_seqs = all_jobs t in
  List.concat_map work_seqs ~f:(fun work_seq ->
      One_or_two.group_list
        (List.map work_seq ~f:(fun job ->
             match statement_of_job job with
             | None ->
                 assert false
             | Some stmt ->
                 stmt )) )

let required_work_pairs t ~slots =
  let work_list = Parallel_scan.jobs_for_slots t ~slots in
  List.concat_map work_list ~f:(fun works -> One_or_two.group_list works)

let k_work_pairs_for_new_diff t ~k =
  let work_list = Parallel_scan.jobs_for_next_update t in
  List.(
    take (concat_map work_list ~f:(fun works -> One_or_two.group_list works)) k)

(*Always the same pairing of jobs*)
let work_statements_for_new_diff t : Transaction_snark_work.Statement.t list =
  let work_list = Parallel_scan.jobs_for_next_update t in
  List.concat_map work_list ~f:(fun work_seq ->
      One_or_two.group_list
        (List.map work_seq ~f:(fun job ->
             match statement_of_job job with
             | None ->
                 assert false
             | Some stmt ->
                 stmt )) )

let all_work_pairs_exn t =
  let all_jobs = all_jobs t in
  let module A = Available_job in
  let single_spec (job : job) =
    match extract_from_job job with
    | First (transaction_with_info, statement, witness) ->
        let transaction =
          Or_error.ok_exn @@ Ledger.Undo.transaction transaction_with_info
        in
        Snark_work_lib.Work.Single.Spec.Transition
          (statement, transaction, witness)
    | Second (p1, p2) ->
        let merged =
          Transaction_snark.Statement.merge
            (Ledger_proof.statement p1)
            (Ledger_proof.statement p2)
          |> Or_error.ok_exn
        in
        Snark_work_lib.Work.Single.Spec.Merge (merged, p1, p2)
  in
  List.concat_map all_jobs ~f:(fun jobs ->
      List.map (One_or_two.group_list jobs) ~f:(One_or_two.map ~f:single_spec)
  )

let fill_work_and_enqueue_transactions t transactions work =
  let open Or_error.Let_syntax in
  let fill_in_transaction_snark_work t (works : Transaction_snark_work.t list)
      : (Ledger_proof.t * Sok_message.t) list Or_error.t =
    let next_jobs =
      List.(
        take
          (concat @@ Parallel_scan.jobs_for_next_update t)
          (total_proofs works))
    in
    map2_or_error next_jobs
      (List.concat_map works
         ~f:(fun {Transaction_snark_work.fee; proofs; prover} ->
           One_or_two.map proofs ~f:(fun proof -> (fee, proof, prover))
           |> One_or_two.to_list ))
      ~f:completed_work_to_scanable_work
  in
  let old_proof = Parallel_scan.last_emitted_value t in
  let%bind work_list = fill_in_transaction_snark_work t work in
  let%bind proof_opt, updated_scan_state =
    Parallel_scan.update t ~completed_jobs:work_list ~data:transactions
  in
  let%map result_opt =
    Option.value_map ~default:(Ok None) proof_opt
      ~f:(fun ((proof, _), txns_with_witnesses) ->
        let curr_source = (Ledger_proof.statement proof).source in
        (*TODO: get genesis ledger hash if the old_proof is none*)
        let prev_target =
          Option.value_map ~default:curr_source old_proof
            ~f:(fun ((p', _), _) -> (Ledger_proof.statement p').target)
        in
        if Frozen_ledger_hash.equal curr_source prev_target then
          Ok (Some (proof, extract_txns txns_with_witnesses))
        else Or_error.error_string "Unexpected ledger proof emitted" )
  in
  (result_opt, updated_scan_state)

module Constants = Constants
