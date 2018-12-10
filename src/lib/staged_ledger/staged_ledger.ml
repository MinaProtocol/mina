[%%import
"../../config.mlh"]

open Core_kernel
open Async_kernel
open Protocols
open Coda_pow
open O1trace

let val_or_exn label = function
  | Error e -> failwithf "%s: %s" label (Error.to_string_hum e) ()
  | Ok x -> x

let option lab =
  Option.value_map ~default:(Or_error.error_string lab) ~f:(fun x -> Ok x)

let check_or_error label b =
  if not b then Or_error.error_string label else Ok ()

module Make_completed_work = Transaction_snark_work.Make
module Make_diff = Staged_ledger_diff.Make

module Make (Inputs : Inputs.S) : sig
  include
    Coda_pow.Staged_ledger_intf
    with type diff := Inputs.Staged_ledger_diff.t
     and type valid_diff :=
                Inputs.Staged_ledger_diff.With_valid_signatures_and_proofs.t
     and type ledger_hash := Inputs.Ledger_hash.t
     and type frozen_ledger_hash := Inputs.Frozen_ledger_hash.t
     and type staged_ledger_hash := Inputs.Staged_ledger_hash.t
     and type public_key := Inputs.Compressed_public_key.t
     and type ledger := Inputs.Ledger.t
     and type user_command_with_valid_signature :=
                Inputs.User_command.With_valid_signature.t
     and type statement := Inputs.Transaction_snark_work.Statement.t
     and type completed_work := Inputs.Transaction_snark_work.Checked.t
     and type ledger_proof := Inputs.Ledger_proof.t
     and type staged_ledger_aux_hash := Inputs.Staged_ledger_aux_hash.t
     and type sparse_ledger := Inputs.Sparse_ledger.t
     and type ledger_proof_statement := Inputs.Ledger_proof_statement.t
     and type ledger_proof_statement_set := Inputs.Ledger_proof_statement.Set.t
     and type transaction := Inputs.Transaction.t
end = struct
  open Inputs
  module Scan_state = Transaction_snark_scan_state.Make (Inputs)

  type job = Scan_state.Available_job.t

  let verify_threadsafe proof statement ~message =
    (* TODO: This is synchronous for now -- we'll need to figure out how to make it async again long term *)
    Async.Thread_safe.block_on_async_exn (fun () ->
        Inputs.Ledger_proof_verifier.verify proof statement ~message )

  let verify ~message job proof =
    match Scan_state.statement_of_job job with
    | None -> false
    | Some statement -> verify_threadsafe proof statement ~message

  module M = struct
    include Monad.Ident
    module Or_error = Or_error
  end

  let is_valid t =
    Parallel_scan.parallelism ~state:t
    = Int.pow 2 (Config.transaction_capacity_log_2 + 2)
    && Parallel_scan.is_valid t

  module Statement_scanner = struct
    include Scan_state.Make_statement_scanner
              (M)
              (struct
                let verify (_ : Ledger_proof.t) (_ : Ledger_proof_statement.t)
                    ~message:(_ : Sok_message.t) =
                  true
              end)
  end

  module Statement_scanner_with_proofs =
    Scan_state.Make_statement_scanner
      (M)
      (struct
        let verify proof stmt ~message = verify_threadsafe proof stmt ~message
      end)

  type scan_state = Scan_state.t [@@deriving sexp, bin_io]

  type t =
    { scan_state:
        scan_state
        (* Invariant: this is the ledger after having applied all the transactions in
       the above state. *)
    ; ledger: Ledger.attached_mask sexp_opaque }
  [@@deriving sexp]

  type serializable = scan_state * Ledger.serializable [@@deriving bin_io]

  let serializable_of_t t = (t.scan_state, Ledger.serializable_of_t t.ledger)

  let of_serialized_and_unserialized ~(serialized : serializable)
      ~(unserialized : Ledger.maskable_ledger) =
    (* reattach the serialized mask to the unserialized ledger *)
    let scan_state, serialized_mask = serialized in
    let attached_mask =
      Ledger.register_mask unserialized
        (Ledger.unattached_mask_of_serializable serialized_mask)
    in
    {scan_state; ledger= attached_mask}

  let chunks_of xs ~n = List.groupi xs ~break:(fun i _ _ -> i mod n = 0)

  let sequence_chunks_of seq ~n =
    Sequence.unfold_step ~init:([], 0, seq) ~f:(fun (acc, i, seq) ->
        if i = n then Yield (List.rev acc, ([], 0, seq))
        else
          match Sequence.next seq with
          | None -> Done
          | Some (x, seq) -> (
            (*allow a chunk of 1 proof as well*)
            match Sequence.next seq with
            | None -> Yield (List.rev (x :: acc), ([], 0, seq))
            | _ -> Skip (x :: acc, i + 1, seq) ) )

  let all_work_pairs t =
    let all_jobs = Scan_state.next_jobs t.scan_state in
    let module A = Scan_state.Available_job in
    let module L = Ledger_proof_statement in
    let single_spec (job : job) =
      match Scan_state.extract_from_job job with
      | First (transaction_with_info, statement, witness) ->
          let transaction =
            Or_error.ok_exn @@ Ledger.Undo.transaction transaction_with_info
          in
          Snark_work_lib.Work.Single.Spec.Transition
            (statement, transaction, witness)
      | Second (p1, p2) ->
          let merged =
            Ledger_proof_statement.merge
              (Ledger_proof.statement p1)
              (Ledger_proof.statement p2)
            |> Or_error.ok_exn
          in
          Snark_work_lib.Work.Single.Spec.Merge (merged, p1, p2)
    in
    let all_jobs_paired =
      let pairs = chunks_of all_jobs ~n:2 in
      List.map pairs ~f:(fun js ->
          match js with
          | [j] -> (j, None)
          | [j1; j2] -> (j1, Some j2)
          | _ -> failwith "error pairing jobs" )
    in
    let job_pair_to_work_spec_pair = function
      | j, Some j' -> (single_spec j, Some (single_spec j'))
      | j, None -> (single_spec j, None)
    in
    List.map all_jobs_paired ~f:job_pair_to_work_spec_pair

  let scan_state {scan_state; _} = scan_state

  let get_target (proof, _) =
    let {Ledger_proof_statement.target; _} = Ledger_proof.statement proof in
    target

  let verify_scan_state_after_apply ledger (scan_state : scan_state) =
    let error_prefix =
      "Error verifying the parallel scan state after applying the diff."
    in
    match Scan_state.latest_ledger_proof scan_state with
    | None ->
        Statement_scanner.check_invariants scan_state ~error_prefix ledger None
    | Some proof ->
        Statement_scanner.check_invariants scan_state ~error_prefix ledger
          (Some (get_target proof))

  let snarked_ledger :
      t -> snarked_ledger_hash:Frozen_ledger_hash.t -> Ledger.t Or_error.t =
   fun {ledger; scan_state; _} ~snarked_ledger_hash:expected_target ->
    let open Or_error.Let_syntax in
    let txns_still_being_worked_on =
      Scan_state.staged_transactions scan_state
    in
    Debug_assert.debug_assert (fun () ->
        let parallelism = Parallel_scan.parallelism ~state:scan_state in
        [%test_pred: int]
          (( >= ) (Inputs.Config.transaction_capacity_log_2 * parallelism))
          (List.length txns_still_being_worked_on) ) ;
    let snarked_ledger = Ledger.register_mask ledger (Ledger.Mask.create ()) in
    let%bind () =
      List.fold_left txns_still_being_worked_on ~init:(Ok ()) ~f:(fun acc t ->
          Or_error.bind
            (Or_error.map acc ~f:(fun _ -> t))
            ~f:(fun u -> Ledger.undo snarked_ledger u) )
    in
    let snarked_ledger_hash =
      Ledger.merkle_root snarked_ledger |> Frozen_ledger_hash.of_ledger_hash
    in
    if not (Frozen_ledger_hash.equal snarked_ledger_hash expected_target) then
      Or_error.errorf
        !"Error materializing the snarked ledger with hash \
          %{sexp:Frozen_ledger_hash.t}: "
        expected_target
    else
      match Scan_state.latest_ledger_proof scan_state with
      | None -> return snarked_ledger
      | Some proof ->
          let target = get_target proof in
          if Frozen_ledger_hash.equal snarked_ledger_hash target then
            return snarked_ledger
          else
            Or_error.errorf
              !"Last snarked ledger (%{sexp: Frozen_ledger_hash.t}) is \
                different from the one being requested ((%{sexp: \
                Frozen_ledger_hash.t}))"
              target expected_target

  let statement_exn t =
    match Statement_scanner.scan_statement t.scan_state with
    | Ok s -> `Non_empty s
    | Error `Empty -> `Empty
    | Error (`Error e) -> failwithf !"statement_exn: %{sexp:Error.t}" e ()

  let of_scan_state_and_ledger ~snarked_ledger_hash ~ledger ~scan_state =
    let open Or_error.Let_syntax in
    let verify_snarked_ledger t snarked_ledger_hash =
      match snarked_ledger t ~snarked_ledger_hash with
      | Ok _ -> Ok ()
      | Error e ->
          Or_error.error_string
            ( "Error verifying snarked ledger hash from the ledger.\n"
            ^ Error.to_string_hum e )
    in
    let t = {ledger; scan_state} in
    let%bind () =
      Statement_scanner_with_proofs.check_invariants scan_state
        ~error_prefix:"Ledger_hash.of_scan_state_and_ledger" ledger
        (Some snarked_ledger_hash)
    in
    let%map () = verify_snarked_ledger t snarked_ledger_hash in
    t

  let copy {scan_state; ledger} =
    let new_mask = Ledger.Mask.create () in
    { scan_state= Scan_state.copy scan_state
    ; ledger= Ledger.register_mask ledger new_mask }

  let hash {scan_state; ledger} : Staged_ledger_hash.t =
    Staged_ledger_hash.of_aux_and_ledger_hash
      (Scan_state.hash scan_state)
      (Ledger.merkle_root ledger)

  [%%if
  call_logger]

  let hash t =
    Coda_debug.Call_logger.record_call "Staged_ledger.hash" ;
    hash t

  [%%endif]

  let ledger {ledger; _} = ledger

  let create ~ledger : t =
    let open Config in
    (* Transaction capacity log_2 is one-fourth the capacity for work parallelism *)
    { scan_state=
        Parallel_scan.start ~parallelism_log_2:(transaction_capacity_log_2 + 2)
    ; ledger }

  let current_ledger_proof t =
    Option.map (Scan_state.latest_ledger_proof t.scan_state) ~f:fst

  let total_proofs (works : Transaction_snark_work.t list) =
    List.sum (module Int) works ~f:(fun w -> List.length w.proofs)

  let sum_fees xs ~f =
    with_return (fun {return} ->
        Ok
          (List.fold ~init:Fee.Unsigned.zero xs ~f:(fun acc x ->
               match Fee.Unsigned.add acc (f x) with
               | None -> return (Or_error.error_string "Fee overflow")
               | Some res -> res )) )

  let apply_transaction_and_get_statement ledger s =
    let open Or_error.Let_syntax in
    let%bind fee_excess = Transaction.fee_excess s
    and supply_increase = Transaction.supply_increase s in
    let source =
      Ledger.merkle_root ledger |> Frozen_ledger_hash.of_ledger_hash
    in
    let%map undo = Ledger.apply_transaction ledger s in
    ( undo
    , { Ledger_proof_statement.source
      ; target= Ledger.merkle_root ledger |> Frozen_ledger_hash.of_ledger_hash
      ; fee_excess
      ; supply_increase
      ; proof_type= `Base } )

  let apply_transaction_and_get_witness ledger s =
    let public_keys = function
      | Transaction.Fee_transfer t -> Fee_transfer.receivers t
      | User_command t ->
          let t = (t :> User_command.t) in
          User_command.accounts_accessed t
      | Coinbase c ->
          let ft_receivers =
            Option.value_map c.fee_transfer ~default:[] ~f:(fun ft ->
                Fee_transfer.receivers (Fee_transfer.of_single ft) )
          in
          c.proposer :: ft_receivers
    in
    let witness =
      measure "sparse ledger" (fun () ->
          Sparse_ledger.of_ledger_subset_exn ledger (public_keys s) )
    in
    let r =
      measure "apply+stmt" (fun () ->
          apply_transaction_and_get_statement ledger s )
    in
    let open Or_error.Let_syntax in
    let%map undo, statement = r in
    ( undo
    , { Scan_state.Transaction_with_witness.transaction_with_info= undo
      ; witness
      ; statement } )

  let update_ledger_and_get_statements ledger ts =
    let undo_transactions undos =
      List.iter undos ~f:(fun u -> Or_error.ok_exn (Ledger.undo ledger u))
    in
    let rec go processed acc = function
      | [] ->
          { Result_with_rollback.result= Ok (List.rev acc)
          ; rollback= Call (fun () -> undo_transactions processed) }
      | t :: ts -> (
        match apply_transaction_and_get_witness ledger t with
        | Error e ->
            undo_transactions processed ;
            Result_with_rollback.error e
        | Ok (undo, res) -> go (undo :: processed) (res :: acc) ts )
    in
    go [] [] ts

  let check_completed_works t (completed_works : Transaction_snark_work.t list)
      =
    Result_with_rollback.with_no_rollback
      (let open Or_error.Let_syntax in
      let%bind jobses =
        let open Or_error.Let_syntax in
        let%map jobs =
          Scan_state.next_k_jobs t.scan_state ~k:(total_proofs completed_works)
        in
        chunks_of jobs ~n:Transaction_snark_work.proofs_length
      in
      List.for_all (List.zip_exn jobses completed_works)
        ~f:(fun (jobs, work) ->
          let message = Sok_message.create ~fee:work.fee ~prover:work.prover in
          List.for_all (List.zip_exn jobs work.proofs) ~f:(fun (job, proof) ->
              verify ~message job proof ) )
      |> check_or_error "proofs did not verify")

  let create_fee_transfers completed_works delta public_key =
    let singles =
      (if Fee.Unsigned.(equal zero delta) then [] else [(public_key, delta)])
      @ List.filter_map completed_works
          ~f:(fun {Transaction_snark_work.fee; prover; _} ->
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
    let single {Transaction_snark_work.fee; prover; _} =
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
          (Option.value_map ~default:Currency.Amount.zero w2
             ~f:(fun {Transaction_snark_work.fee; _} ->
               Currency.Amount.of_fee fee ))
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
    | `Two (Some ((w1 : Transaction_snark_work.t), w2)) ->
        let amt = Currency.Amount.of_fee w1.fee in
        two_parts amt (Some w1) w2

  let fee_remainder (user_commands : User_command.With_valid_signature.t list)
      completed_works =
    let open Or_error.Let_syntax in
    let%bind budget =
      sum_fees user_commands ~f:(fun t -> User_command.fee (t :> User_command.t)
      )
    in
    let%bind work_fee =
      sum_fees completed_works ~f:(fun {Transaction_snark_work.fee; _} -> fee)
    in
    option "budget did not suffice" (Fee.Unsigned.sub budget work_fee)

  module Prediff_info = struct
    type ('data, 'work) t =
      { data: 'data
      ; work: 'work list
      ; coinbase_work: 'work list
      ; user_commands_count: int
      ; coinbase_parts_count: int }
  end

  let apply_pre_diff ledger coinbase_parts proposer
      (diff : Staged_ledger_diff.diff) =
    let open Result_with_rollback.Let_syntax in
    let%bind user_commands =
      let%map user_commands' =
        List.fold_until diff.user_commands ~init:[]
          ~f:(fun acc t ->
            match User_command.check t with
            | Some t -> Continue (t :: acc)
            | None ->
                (* TODO: punish *)
                Stop (Or_error.error_string "Bad signature") )
          ~finish:Or_error.return
        |> Result_with_rollback.of_or_error
      in
      List.rev user_commands'
    in
    let coinbase_work =
      match coinbase_parts with
      | `One (Some w) -> [w]
      | `Two (Some (w, None)) -> [w]
      | `Two (Some (w1, Some w2)) -> [w1; w2]
      | _ -> []
    in
    let%bind coinbase =
      create_coinbase coinbase_parts proposer
      |> Result_with_rollback.of_or_error
    in
    let%bind delta =
      fee_remainder user_commands diff.completed_works
      |> Result_with_rollback.of_or_error
    in
    let%bind fee_transfers =
      create_fee_transfers diff.completed_works delta proposer
      |> Result_with_rollback.of_or_error
    in
    let transactions =
      List.map user_commands ~f:(fun t -> Transaction.User_command t)
      @ List.map coinbase ~f:(fun t -> Transaction.Coinbase t)
      @ List.map fee_transfers ~f:(fun t -> Transaction.Fee_transfer t)
    in
    let%map new_data = update_ledger_and_get_statements ledger transactions in
    { Prediff_info.data= new_data
    ; work= diff.completed_works
    ; coinbase_work
    ; user_commands_count= List.length user_commands
    ; coinbase_parts_count= List.length coinbase }

  (* TODO: when we move to a disk-backed db, this should call "Ledger.commit_changes" at the end. *)
  let apply_diff t (diff : Staged_ledger_diff.t) ~logger =
    let open Result_with_rollback.Let_syntax in
    let max_throughput = Int.pow 2 Inputs.Config.transaction_capacity_log_2 in
    let%bind spots_available, proofs_waiting =
      let%map jobs =
        Parallel_scan.next_jobs ~state:t.scan_state
        |> Result_with_rollback.of_or_error
      in
      ( Int.min (Parallel_scan.free_space ~state:t.scan_state) max_throughput
      , List.length jobs )
    in
    let apply_pre_diff_with_at_most_two
        (pre_diff1 : Staged_ledger_diff.diff_with_at_most_two_coinbase) ledger
        =
      let coinbase_parts =
        match pre_diff1.coinbase_parts with
        | Zero -> `Zero
        | One x -> `One x
        | Two x -> `Two x
      in
      apply_pre_diff ledger coinbase_parts diff.creator pre_diff1.diff
    in
    let apply_pre_diff_with_at_most_one
        (pre_diff2 : Staged_ledger_diff.diff_with_at_most_one_coinbase) ledger
        =
      let coinbase_added =
        match pre_diff2.coinbase_added with Zero -> `Zero | One x -> `One x
      in
      apply_pre_diff ledger coinbase_added diff.creator pre_diff2.diff
    in
    let%bind () =
      let curr_hash = hash t in
      check_or_error
        (sprintf
           !"bad prev_hash: Expected %{sexp:Staged_ledger_hash.t}, got \
             %{sexp:Staged_ledger_hash.t}"
           curr_hash diff.prev_hash)
        (Staged_ledger_hash.equal diff.prev_hash (hash t))
      |> Result_with_rollback.of_or_error
    in
    let new_mask = Inputs.Ledger.Mask.create () in
    let new_ledger = Inputs.Ledger.register_mask t.ledger new_mask in
    let%bind data, works, user_commands_count, cb_parts_count =
      Either.value_map diff.pre_diffs
        ~first:(fun d ->
          let%map { data
                  ; work
                  ; coinbase_work
                  ; user_commands_count
                  ; coinbase_parts_count } =
            apply_pre_diff_with_at_most_one d new_ledger
          in
          ( data
          , coinbase_work @ work
          , user_commands_count
          , coinbase_parts_count ) )
        ~second:(fun d ->
          let%bind p1 = apply_pre_diff_with_at_most_two (fst d) new_ledger in
          let%map p2 = apply_pre_diff_with_at_most_one (snd d) new_ledger in
          ( p1.data @ p2.data
          , p1.work @ p1.coinbase_work @ p2.coinbase_work @ p2.work
          , p1.user_commands_count + p2.user_commands_count
          , p1.coinbase_parts_count + p2.coinbase_parts_count ) )
    in
    let%bind () = check_completed_works t works in
    let%bind res_opt =
      (* TODO: Add rollback *)
      let r = Scan_state.fill_in_transaction_snark_work t.scan_state works in
      Or_error.iter_error r ~f:(fun e ->
          (* TODO: Pass a logger here *)
          eprintf !"Unexpected error: %s %{sexp:Error.t}\n%!" __LOC__ e ) ;
      Result_with_rollback.of_or_error r
    in
    let%bind () =
      Result_with_rollback.of_or_error
      @@ Scan_state.enqueue_transactions t.scan_state data
    in
    let%map () =
      verify_scan_state_after_apply new_ledger t.scan_state
      |> Result_with_rollback.of_or_error
    in
    Logger.info logger
      "Block info: No of transactions included:%d Coinbase parts:%d Work \
       count:%d Spots available:%d Proofs waiting to be solved:%d"
      user_commands_count cb_parts_count (List.length works) spots_available
      proofs_waiting ;
    ( `Hash_after_applying (hash t)
    , `Ledger_proof res_opt
    , `Updated_staged_ledger {t with ledger= new_ledger} )

  let apply t witness ~logger =
    Result_with_rollback.run (apply_diff t witness ~logger)

  let forget_work_opt = Option.map ~f:Transaction_snark_work.forget

  let apply_pre_diff_unchecked ledger coinbase_parts proposer
      (diff : Staged_ledger_diff.With_valid_signatures_and_proofs.diff) =
    let user_commands = diff.user_commands in
    let txn_works =
      List.map ~f:Transaction_snark_work.forget diff.completed_works
    in
    let coinbase_work =
      match coinbase_parts with
      | `One (Some w) -> [w]
      | `Two (Some (w, None)) -> [w]
      | `Two (Some (w1, Some w2)) -> [w1; w2]
      | _ -> []
    in
    let coinbase_parts =
      measure "create_coinbase" (fun () ->
          Or_error.ok_exn (create_coinbase coinbase_parts proposer) )
    in
    let delta = Or_error.ok_exn (fee_remainder user_commands txn_works) in
    let fee_transfers =
      Or_error.ok_exn (create_fee_transfers txn_works delta proposer)
    in
    let transactions =
      List.map user_commands ~f:(fun t -> Transaction.User_command t)
      @ List.map coinbase_parts ~f:(fun t -> Transaction.Coinbase t)
      @ List.map fee_transfers ~f:(fun t -> Transaction.Fee_transfer t)
    in
    let new_data =
      List.map transactions ~f:(fun s ->
          let r = apply_transaction_and_get_witness ledger s in
          let _undo, t = Or_error.ok_exn r in
          t )
    in
    (new_data, txn_works, coinbase_work)

  let apply_diff_unchecked t
      (diff : Staged_ledger_diff.With_valid_signatures_and_proofs.t) =
    let apply_pre_diff_with_at_most_two
        (pre_diff1 :
          Staged_ledger_diff.With_valid_signatures_and_proofs
          .diff_with_at_most_two_coinbase) ledger =
      let coinbase_parts =
        match pre_diff1.coinbase_parts with
        | Zero -> `Zero
        | One x -> `One (forget_work_opt x)
        | Two x ->
            `Two
              (Option.map x ~f:(fun (w, w_opt) ->
                   (Transaction_snark_work.forget w, forget_work_opt w_opt) ))
      in
      apply_pre_diff_unchecked ledger coinbase_parts diff.creator
        pre_diff1.diff
    in
    let apply_pre_diff_with_at_most_one
        (pre_diff2 :
          Staged_ledger_diff.With_valid_signatures_and_proofs
          .diff_with_at_most_one_coinbase) ledger =
      let coinbase_added =
        match pre_diff2.coinbase_added with
        | Zero -> `Zero
        | One x -> `One (forget_work_opt x)
      in
      apply_pre_diff_unchecked ledger coinbase_added diff.creator
        pre_diff2.diff
    in
    let new_mask = Inputs.Ledger.Mask.create () in
    let new_ledger = Inputs.Ledger.register_mask t.ledger new_mask in
    let data, works =
      Either.value_map diff.pre_diffs
        ~first:(fun d ->
          let data, works, cb_works =
            apply_pre_diff_with_at_most_one d new_ledger
          in
          (data, cb_works @ works) )
        ~second:(fun d ->
          let data1, works1, cb_works1 =
            apply_pre_diff_with_at_most_two (fst d) new_ledger
          in
          let data2, works2, cb_works2 =
            apply_pre_diff_with_at_most_one (snd d) new_ledger
          in
          (data1 @ data2, works1 @ cb_works1 @ cb_works2 @ works2) )
    in
    let res_opt =
      Or_error.ok_exn
        (Scan_state.fill_in_transaction_snark_work t.scan_state works)
    in
    Or_error.ok_exn (Scan_state.enqueue_transactions t.scan_state data) ;
    Or_error.ok_exn (verify_scan_state_after_apply t.ledger t.scan_state) ;
    ( `Hash_after_applying (hash t)
    , `Ledger_proof res_opt
    , `Updated_staged_ledger {t with ledger= new_ledger} )

  let work_to_do scan_state : Transaction_snark_work.Statement.t Sequence.t =
    let work_seq = Scan_state.next_jobs_sequence scan_state in
    sequence_chunks_of ~n:Transaction_snark_work.proofs_length
    @@ Sequence.map work_seq ~f:(fun maybe_work ->
           match Scan_state.statement_of_job maybe_work with
           | None -> assert false
           | Some work -> work )

  module Resources = struct
    module Queue_consumption = struct
      type t =
        { fee_transfers: Compressed_public_key.Set.t
        ; user_commands: int
        ; coinbase_part_count: int }
      [@@deriving sexp]

      let count {fee_transfers; user_commands; coinbase_part_count} =
        (* This is number of coinbase_parts + number of transactions + ceil
        (Set.length fee_transfers / 2) *)
        coinbase_part_count + user_commands
        + ((Set.length fee_transfers + 1) / 2)

      let add_user_command t = {t with user_commands= t.user_commands + 1}

      let add_fee_transfer t public_key =
        {t with fee_transfers= Set.add t.fee_transfers public_key}

      let add_coinbase t =
        {t with coinbase_part_count= t.coinbase_part_count + 1}

      let init =
        { user_commands= 0
        ; fee_transfers= Compressed_public_key.Set.empty
        ; coinbase_part_count= 0 }
    end

    type t =
      { budget: Fee.Signed.t
      ; queue_consumption: Queue_consumption.t
      ; available_queue_space: int
      ; work_done: int
      ; user_commands:
          (User_command.With_valid_signature.t * Ledger.Undo.t) list
      ; completed_works: Transaction_snark_work.Checked.t list
      ; coinbase_parts:
          ( Transaction_snark_work.Checked.t Staged_ledger_diff.At_most_two.t
          , Transaction_snark_work.Checked.t Staged_ledger_diff.At_most_one.t
          )
          Either.t
      ; completed_works_for_coinbase: Transaction_snark_work.Checked.t list
      ; self_pk: Compressed_public_key.t }
    [@@deriving sexp]

    let available_space t =
      t.available_queue_space - Queue_consumption.count t.queue_consumption

    let is_space_available t = available_space t > 0

    let budget_non_neg t = Fee.Signed.sgn t.budget = Sgn.Pos

    let coinbase_added t = t.queue_consumption.coinbase_part_count > 0

    let add_user_command t ((txv : User_command.With_valid_signature.t), undo)
        =
      let tx = (txv :> User_command.t) in
      let open Or_error.Let_syntax in
      let%bind budget =
        option "overflow"
          (Fee.Signed.add t.budget
             (Fee.Signed.of_unsigned @@ User_command.fee tx))
      in
      let q =
        if Currency.Fee.equal (User_command.fee tx) Currency.Fee.zero then
          t.queue_consumption
        else Queue_consumption.add_fee_transfer t.queue_consumption t.self_pk
      in
      let queue_consumption = Queue_consumption.add_user_command q in
      if not (is_space_available {t with queue_consumption= q}) then
        Or_error.error_string "Error adding a transaction: Insufficient space"
      else
        Ok
          { t with
            budget
          ; queue_consumption
          ; user_commands= (txv, undo) :: t.user_commands }

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
                Staged_ledger_diff.At_most_two.increase w
                  t.completed_works_for_coinbase
              in
              First cb
          | Second w ->
              let%map cb =
                Staged_ledger_diff.At_most_one.increase w
                  t.completed_works_for_coinbase
              in
              Second cb
        in
        {t with queue_consumption; coinbase_parts}

    let enough_work_for_user_command t
        (txv : User_command.With_valid_signature.t) =
      let tx = (txv :> User_command.t) in
      let q =
        if Currency.Fee.equal (User_command.fee tx) Currency.Fee.zero then
          t.queue_consumption
        else Queue_consumption.add_fee_transfer t.queue_consumption t.self_pk
      in
      let queue_consumption = Queue_consumption.add_user_command q in
      t.work_done = Queue_consumption.count queue_consumption * 2

    let enough_work_for_coinbase t =
      let work_done =
        List.sum
          (module Int)
          t.completed_works_for_coinbase
          ~f:(fun wc ->
            let w = Transaction_snark_work.forget wc in
            List.length w.proofs )
      in
      work_done >= (t.queue_consumption.coinbase_part_count + 1) * 2

    let add_work_for_coinbase t (wc : Transaction_snark_work.Checked.t) =
      let open Or_error.Let_syntax in
      let coinbase = Protocols.Coda_praos.coinbase_amount in
      let%bind coinbase_used_up =
        List.fold ~init:(Ok Currency.Fee.zero)
          ~f:(fun acc w ->
            let%bind acc = acc in
            let w' = Transaction_snark_work.forget w in
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

    let add_work t (wc : Transaction_snark_work.Checked.t) =
      let open Or_error.Let_syntax in
      let w = Transaction_snark_work.forget wc in
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
      ; user_commands= []
      ; completed_works= []
      ; coinbase_parts= prediff
      ; completed_works_for_coinbase= []
      ; self_pk= self }
  end

  module Resource_util = struct
    type t =
      { resources: Resources.t
      ; work_to_do: Transaction_snark_work.Statement.t Sequence.t
      ; user_commands_to_include:
          User_command.With_valid_signature.t Sequence.t }
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

  let add_user_command ledger txn resources =
    match Ledger.apply_transaction ledger (User_command txn) with
    | Error _ -> Ok resources
    | Ok undo -> (
      match Resources.add_user_command resources (txn, undo) with
      | Ok resources -> Ok resources
      | Error e ->
          Or_error.ok_exn (Ledger.undo ledger undo) ;
          Error e )

  let txns_not_included (valid : Resources.t) (invalid : Resources.t) =
    let diff =
      List.length invalid.user_commands - List.length valid.user_commands
    in
    if diff > 0 then List.take invalid.user_commands diff else []

  let log_error_and_return_value logger err_val def_val =
    match err_val with
    | Error e ->
        Logger.error logger "%s" (Error.to_string_hum e) ;
        def_val
    | Ok value -> value

  let rec check_resources_add_txns logger get_completed_work ledger
      (valid : Resource_util.t) (current : Resource_util.t) =
    let add_user_command t ts ws =
      let r_user_command =
        log_error_and_return_value logger
          (add_user_command ledger t current.resources)
          current.resources
      in
      let new_res_util =
        { Resource_util.resources= r_user_command
        ; work_to_do= ws
        ; user_commands_to_include= ts }
      in
      if Resources.budget_non_neg r_user_command then
        check_resources_add_txns logger get_completed_work ledger new_res_util
          new_res_util
      else
        check_resources_add_txns logger get_completed_work ledger valid
          new_res_util
    in
    match
      ( Sequence.next current.work_to_do
      , Sequence.next current.user_commands_to_include
      , Resources.is_space_available current.resources )
    with
    | None, None, _ ->
        (valid, txns_not_included valid.resources current.resources)
    | None, Some (t, ts), true -> add_user_command t ts Sequence.empty
    | Some (w, ws), Some (t, ts), true -> (
        let enough_work_added_to_include_one_more =
          Resources.enough_work_for_user_command current.resources t
        in
        if enough_work_added_to_include_one_more then
          add_user_command t ts (Sequence.append (Sequence.singleton w) ws)
        else
          match add_work w current.resources get_completed_work with
          | Ok r_work ->
              check_resources_add_txns logger get_completed_work ledger valid
                { resources= r_work
                ; work_to_do= ws
                ; user_commands_to_include=
                    Sequence.append (Sequence.singleton t) ts }
          | Error e ->
              Logger.error logger "%s" (Error.to_string_hum e) ;
              (valid, txns_not_included valid.resources current.resources) )
    | _, _, _ -> (valid, txns_not_included valid.resources current.resources)

  let undo_txns ledger txns =
    List.fold txns ~init:() ~f:(fun _ (_, u) ->
        Or_error.ok_exn (Ledger.undo ledger u) )

  let update_coinbase_count n logger (res_util : Resource_util.t)
      get_completed_work : Resource_util.t =
    if Resources.coinbase_added res_util.resources then res_util
    else
      let rec go valid (current : Resource_util.t) count =
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
        | Some (w, ws), true -> (
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
                  valid )
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
        (Second Staged_ledger_diff.At_most_one.Zero)
    in
    let init_res_util =
      { Resource_util.resources= init_resources
      ; work_to_do= ws_seq
      ; user_commands_to_include= ts_seq }
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
      partitions =
    let init_resources =
      Resources.init ~available_queue_space:(fst partitions) ~self
        (First Staged_ledger_diff.At_most_two.Zero)
    in
    let init_res_util =
      { Resource_util.resources= init_resources
      ; work_to_do= ws_seq
      ; user_commands_to_include= ts_seq }
    in
    (*splitting coinbase into n parts*)
    let remaining_slots (res_util : Resource_util.t) =
      let n' = Resources.available_space res_util.resources in
      (*if there are no more transactions to be included in the second prediff then don't bother splitting up the coinbase*)
      if n' > 1 && Sequence.length res_util.user_commands_to_include = 0 then 1
      else n'
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
      let _ = undo_txns ledger res_util_coinbase.resources.user_commands in
      let res =
        one_prediff logger ws_seq ts_seq get_completed_work ledger self
          (fst partitions) ~add_coinbase:true
      in
      First res
    else
      let res_coinbase2 =
        one_prediff logger res_util_coinbase.work_to_do
          res_util_coinbase.user_commands_to_include get_completed_work ledger
          self (snd partitions)
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
          || List.length res_coinbase2.user_commands = 0 ) ;
        Second (res_util_coinbase.resources, res_coinbase2) )
      else
        (*Not enough work to add coinbase and therefore recompute the diff
        again by adding coinbase first, resulting in a single pre_diff*)
        let _ =
          undo_txns ledger
            ( res_coinbase2.user_commands
            @ res_util_coinbase.resources.user_commands )
        in
        let res =
          one_prediff logger ws_seq ts_seq get_completed_work ledger self
            (fst partitions) ~add_coinbase:true
        in
        First res

  let generate_prediff logger ws_seq ts_seq get_completed_work ledger self
      partitions =
    let diff (res : Resources.t) :
        Staged_ledger_diff.With_valid_signatures_and_proofs.diff =
      (* We have to reverse here because we only know they work in THIS order *)
      { user_commands= List.rev_map res.user_commands ~f:fst
      ; completed_works= List.rev res.completed_works }
    in
    let make_diff_with_one (res : Resources.t) :
        Staged_ledger_diff.With_valid_signatures_and_proofs
        .diff_with_at_most_one_coinbase =
      match res.coinbase_parts with
      | First _ ->
          Logger.error logger
            "Error while creating a diff: Invalid resource configuration" ;
          {diff= diff res; coinbase_added= Staged_ledger_diff.At_most_one.Zero}
      | Second w -> {diff= diff res; coinbase_added= w}
    in
    let make_diff_with_two (res : Resources.t) :
        Staged_ledger_diff.With_valid_signatures_and_proofs
        .diff_with_at_most_two_coinbase =
      match res.coinbase_parts with
      | First w -> {diff= diff res; coinbase_parts= w}
      | Second _ ->
          Logger.error logger
            "Error while creating a diff: Invalid resource configuration" ;
          {diff= diff res; coinbase_parts= Staged_ledger_diff.At_most_two.Zero}
    in
    match partitions with
    | `One x ->
        let res =
          one_prediff logger ws_seq ts_seq get_completed_work ledger self x
            ~add_coinbase:true
        in
        First (make_diff_with_one res)
    | `Two (x, y) -> (
      match
        two_prediffs logger ws_seq ts_seq get_completed_work ledger self (x, y)
      with
      | First res -> First (make_diff_with_one res)
      | Second (res1, res2) ->
          Second (make_diff_with_two res1, make_diff_with_one res2) )

  let create_diff t ~self ~logger
      ~(transactions_by_fee : User_command.With_valid_signature.t Sequence.t)
      ~(get_completed_work :
            Transaction_snark_work.Statement.t
         -> Transaction_snark_work.Checked.t option) =
    let curr_hash = hash t in
    let new_mask = Inputs.Ledger.Mask.create () in
    let tmp_ledger = Inputs.Ledger.register_mask t.ledger new_mask in
    let max_throughput = Int.pow 2 Inputs.Config.transaction_capacity_log_2 in
    let partitions =
      Scan_state.partition_if_overflowing ~max_slots:max_throughput
        t.scan_state
    in
    (*TODO: return an or_error here *)
    let work_to_do = work_to_do_exn t'.scan_state in
    let pre_diffs =
      generate_prediff logger (work_to_do t.scan_state) transactions_by_fee
        get_completed_work tmp_ledger self partitions
    in
    let proofs_available =
      Sequence.filter_map work_to_do ~f:get_completed_work
      |> Sequence.to_list |> List.length
    in
    Logger.info logger "Block stats: Proofs ready for purchase: %d"
      proofs_available ;
    trace_event "prediffs done" ;
    { Staged_ledger_diff.With_valid_signatures_and_proofs.pre_diffs
    ; creator= self
    ; prev_hash= curr_hash }
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

      module Account = struct
        type t = int
      end

      module User_command = struct
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

        let accounts_accessed _ = ["R"; "S"]
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
          | Two ((_, fee1), (_, fee2)) -> (
            match Fee.Unsigned.add fee1 fee2 with
            | None -> Or_error.error_string "Fee_transfer.fee_excess: overflow"
            | Some res -> Ok res )

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

      module Transaction = struct
        type valid_user_command = User_command.With_valid_signature.t
        [@@deriving sexp, bin_io, compare, eq]

        type fee_transfer = Fee_transfer.t
        [@@deriving sexp, bin_io, compare, eq]

        type coinbase = Coinbase.t [@@deriving sexp, bin_io, compare, eq]

        type unsigned_fee = Fee.Unsigned.t [@@deriving sexp, bin_io, compare]

        type t =
          | User_command of valid_user_command
          | Fee_transfer of fee_transfer
          | Coinbase of coinbase
        [@@deriving sexp, bin_io, compare, eq]

        let fee_excess : t -> Fee.Signed.t Or_error.t =
         fun t ->
          let open Or_error.Let_syntax in
          match t with
          | User_command t' ->
              Ok (Currency.Fee.Signed.of_unsigned (User_command.fee t'))
          | Fee_transfer f ->
              let%map fee = Fee_transfer.fee_excess f in
              Currency.Fee.Signed.negate (Currency.Fee.Signed.of_unsigned fee)
          | Coinbase t -> Coinbase.fee_excess t

        let supply_increase = function
          | User_command _ | Fee_transfer _ -> Ok Currency.Amount.zero
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
            let%bind _ =
              if Ledger_hash.equal s1.target s2.source then Ok ()
              else
                Or_error.errorf
                  !"Invalid merge: target: %s source %s"
                  s1.target s2.source
            in
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

        let create ~statement ~sok_digest:_ ~proof:_ = statement
      end

      module Ledger_proof_verifier = struct
        let verify (_ : Ledger_proof.t) (_ : Ledger_proof_statement.t)
            ~message:_ : bool Deferred.t =
          return true
      end

      module Ledger = struct
        (*TODO: Test with a ledger that's more comprehensive*)
        type t = int ref [@@deriving sexp, bin_io, compare]

        type ledger_hash = Ledger_hash.t

        type transaction = Transaction.t [@@deriving sexp, bin_io]

        module Undo = struct
          type t = transaction [@@deriving sexp, bin_io]

          let transaction t = Ok t
        end

        let create ?directory_name:_ () = ref 0

        let copy : t -> t = fun t -> ref !t

        let merkle_root : t -> ledger_hash = fun t -> Int.to_string !t

        let to_list t = [!t]

        let num_accounts _ = 0

        (* BEGIN BOILERPLATE UNUSED *)
        type serializable = int [@@deriving bin_io]

        type maskable_ledger = t

        type attached_mask = t [@@deriving sexp]

        module Mask = struct
          type t = int [@@deriving bin_io]

          let create () = 0
        end

        type unattached_mask = Mask.t

        let unregister_mask_exn _ = failwith "unimplemented"

        let register_mask l _m = copy l

        let unattached_mask_of_serializable _ = failwith "unimplemented"

        let serializable_of_t _ = failwith "unimplemented"

        (* END BOILERPLATE UNUSED *)

        let commit _t = ()

        let apply_transaction : t -> Undo.t -> Undo.t Or_error.t =
         fun t s ->
          match s with
          | User_command t' ->
              t := !t + fst t' ;
              Or_error.return (Transaction.User_command t')
          | Fee_transfer f ->
              let t' = Fee_transfer.fee_excess_int f in
              t := !t + t' ;
              Or_error.return (Transaction.Fee_transfer f)
          | Coinbase c ->
              t := !t + Currency.Amount.to_int c.amount ;
              Or_error.return (Transaction.Coinbase c)

        let undo_transaction : t -> transaction -> unit Or_error.t =
         fun t s ->
          let v =
            match s with
            | User_command t' -> fst t'
            | Fee_transfer f -> Fee_transfer.fee_excess_int f
            | Coinbase c -> Currency.Amount.to_int c.amount
          in
          t := !t - v ;
          Or_error.return ()

        let undo t (txn : Undo.t) = undo_transaction t txn
      end

      module Sparse_ledger = struct
        type t = int [@@deriving sexp, bin_io]

        let of_ledger_subset_exn :
            Ledger.t -> Compressed_public_key.t list -> t =
         fun ledger _ -> !ledger

        let merkle_root t = Ledger.merkle_root (ref t)

        let apply_transaction_exn t txn =
          let l : Ledger.t = ref t in
          Or_error.ok_exn (Ledger.apply_transaction l txn) |> ignore ;
          !l
      end

      module Staged_ledger_aux_hash = struct
        include String

        let of_bytes : string -> t = fun s -> s
      end

      module Staged_ledger_hash = struct
        include String

        type ledger_hash = Ledger_hash.t

        type staged_ledger_aux_hash = Staged_ledger_aux_hash.t

        let ledger_hash _ = failwith "stub"

        let aux_hash _ = failwith "stub"

        let of_aux_and_ledger_hash : staged_ledger_aux_hash -> ledger_hash -> t
            =
         fun ah h -> ah ^ h
      end

      module Transaction_snark_work = struct
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

      module Staged_ledger_diff = struct
        type completed_work = Transaction_snark_work.t
        [@@deriving sexp, bin_io, compare]

        type completed_work_checked = Transaction_snark_work.Checked.t
        [@@deriving sexp, bin_io, compare]

        type user_command = User_command.t [@@deriving sexp, bin_io, compare]

        type user_command_with_valid_signature =
          User_command.With_valid_signature.t
        [@@deriving sexp, bin_io, compare]

        type public_key = Compressed_public_key.t
        [@@deriving sexp, bin_io, compare]

        type staged_ledger_hash = Staged_ledger_hash.t
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
          { completed_works: completed_work list
          ; user_commands: user_command list }
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
          ; prev_hash: staged_ledger_hash
          ; creator: public_key }
        [@@deriving sexp, bin_io]

        module With_valid_signatures_and_proofs = struct
          type diff =
            { completed_works: completed_work_checked list
            ; user_commands: user_command_with_valid_signature list }
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
            ; prev_hash: staged_ledger_hash
            ; creator: public_key }
          [@@deriving sexp]

          let user_commands t =
            Either.value_map t.pre_diffs
              ~first:(fun d -> d.diff.user_commands)
              ~second:(fun d ->
                (fst d).diff.user_commands @ (snd d).diff.user_commands )
        end

        let forget_diff
            {With_valid_signatures_and_proofs.completed_works; user_commands} =
          { completed_works=
              List.map ~f:Transaction_snark_work.forget completed_works
          ; user_commands= (user_commands :> User_command.t list) }

        let forget_work_opt = Option.map ~f:Transaction_snark_work.forget

        let forget_pre_diff_with_at_most_two
            {With_valid_signatures_and_proofs.diff; coinbase_parts} =
          let forget_cw =
            match coinbase_parts with
            | At_most_two.Zero -> At_most_two.Zero
            | One cw -> One (forget_work_opt cw)
            | Two cw_pair ->
                Two
                  (Option.map cw_pair ~f:(fun (cw, cw_opt) ->
                       ( Transaction_snark_work.forget cw
                       , forget_work_opt cw_opt ) ))
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

        let forget (t : With_valid_signatures_and_proofs.t) =
          { pre_diffs=
              Either.map t.pre_diffs ~first:forget_pre_diff_with_at_most_one
                ~second:(fun d ->
                  ( forget_pre_diff_with_at_most_two (fst d)
                  , forget_pre_diff_with_at_most_one (snd d) ) )
          ; prev_hash= t.prev_hash
          ; creator= t.creator }

        let user_commands (t : t) =
          Either.value_map t.pre_diffs
            ~first:(fun d -> d.diff.user_commands)
            ~second:(fun d ->
              (fst d).diff.user_commands @ (snd d).diff.user_commands )
      end

      module Config = struct
        let transaction_capacity_log_2 = 7
      end

      let check :
             Transaction_snark_work.t
          -> Transaction_snark_work.statement list
          -> Transaction_snark_work.Checked.t option Deferred.t =
       fun {fee= f; proofs= p; prover= pr} _ ->
        Deferred.return
        @@ Some {Transaction_snark_work.Checked.fee= f; proofs= p; prover= pr}
    end

    module Sl = Make (Test_input1)

    let self_pk = "me"

    let stmt_to_work (stmts : Test_input1.Transaction_snark_work.Statement.t) :
        Test_input1.Transaction_snark_work.Checked.t option =
      let prover =
        List.fold stmts ~init:"P" ~f:(fun p stmt -> p ^ stmt.target)
      in
      Some
        { Test_input1.Transaction_snark_work.Checked.fee= Fee.Unsigned.of_int 1
        ; proofs= stmts
        ; prover }

    let create_and_apply sl logger txns stmt_to_work proof =
      let open Or_error.Let_syntax in
      let diff =
        Sl.create_diff sl ~self:self_pk ~logger ~transactions_by_fee:txns
          ~get_completed_work:stmt_to_work
      in
      let%map _, `Ledger_proof ledger_proof, `Updated_staged_ledger sl' =
        Sl.apply sl (Test_input1.Staged_ledger_diff.forget diff) ~logger
      in
      let ledger = Sl.ledger sl in
      let snarked_ledger_hash =
        match ledger_proof with
        | None -> !proof
        | Some p ->
            let new_proof =
              Test_input1.Ledger_proof.statement_target
                (Test_input1.Ledger_proof.statement p)
            in
            proof := new_proof ;
            new_proof
      in
      ledger := !(Sl.ledger sl') ;
      ( ledger_proof
      , Test_input1.Staged_ledger_diff.forget diff
      , Or_error.ok_exn
        @@ Sl.of_scan_state_and_ledger ~scan_state:(Sl.scan_state sl') ~ledger
             ~snarked_ledger_hash )

    let txns n f g = List.zip_exn (List.init n ~f) (List.init n ~f:g)

    let coinbase_added_first_prediff = function
      | Test_input1.Staged_ledger_diff.At_most_two.Zero -> 0
      | One _ -> 1
      | _ -> 2

    let coinbase_added_second_prediff = function
      | Test_input1.Staged_ledger_diff.At_most_one.Zero -> 0
      | _ -> 1

    let coinbase_added (diff : Test_input1.Staged_ledger_diff.t) =
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
      let p = Int.pow 2 Test_input1.Config.transaction_capacity_log_2 in
      let g = Int.gen_incl 1 p in
      let initial_ledger = ref 0 in
      let sl = Sl.create ~ledger:initial_ledger in
      let proof = ref "0" in
      Quickcheck.test g ~trials:1000 ~f:(fun _ ->
          let old_ledger = !(Sl.ledger sl) in
          let all_ts = txns (p / 2) (fun x -> (x + 1) * 100) (fun _ -> 4) in
          let proof, diff, sl =
            create_and_apply sl logger (Sequence.of_list all_ts) stmt_to_work
              proof
            |> Or_error.ok_exn
          in
          let fee_excess =
            Option.value_map ~default:Currency.Fee.Signed.zero proof
              ~f:(fun proof ->
                let stmt = Test_input1.Ledger_proof.statement proof in
                stmt.fee_excess )
          in
          (*fee_excess at the top should always be zero*)
          assert (Currency.Fee.Signed.equal fee_excess Currency.Fee.Signed.zero) ;
          let cb = coinbase_added diff in
          (*At worst case number of provers coinbase should not be split more than two times*)
          assert (cb > 0 && cb < 3) ;
          let x =
            List.length (Test_input1.Staged_ledger_diff.user_commands diff)
          in
          assert_at_least_coinbase_added x cb ;
          let expected_value = expected_ledger x all_ts old_ledger in
          assert (!(Sl.ledger sl) = expected_value) )

    let%test_unit "Be able to include random number of user_commands" =
      (*Always at worst case number of provers*)
      Backtrace.elide := false ;
      let logger = Logger.create () in
      let p = Int.pow 2 Test_input1.Config.transaction_capacity_log_2 in
      let g = Int.gen_incl 1 p in
      let initial_ledger = ref 0 in
      let sl = Sl.create ~ledger:initial_ledger in
      let proof = ref "0" in
      Quickcheck.test g ~trials:1000 ~f:(fun i ->
          let old_ledger = !(Sl.ledger sl) in
          let all_ts = txns p (fun x -> (x + 1) * 100) (fun _ -> 4) in
          let ts = List.take all_ts i in
          let proof, diff, sl =
            create_and_apply sl logger (Sequence.of_list ts) stmt_to_work proof
            |> Or_error.ok_exn
          in
          let fee_excess =
            Option.value_map ~default:Currency.Fee.Signed.zero proof
              ~f:(fun proof ->
                let stmt = Test_input1.Ledger_proof.statement proof in
                stmt.fee_excess )
          in
          (*fee_excess at the top should always be zero*)
          assert (Currency.Fee.Signed.equal fee_excess Currency.Fee.Signed.zero) ;
          let cb = coinbase_added diff in
          (*At worst case number of provers coinbase should not be split more than two times*)
          assert (cb > 0 && cb < 3) ;
          let x =
            List.length (Test_input1.Staged_ledger_diff.user_commands diff)
          in
          assert_at_least_coinbase_added x cb ;
          let expected_value = expected_ledger x all_ts old_ledger in
          assert (!(Sl.ledger sl) = expected_value) )

    let%test_unit "Be able to include random number of user_commands (One \
                   prover)" =
      let get_work (stmts : Test_input1.Transaction_snark_work.Statement.t) :
          Test_input1.Transaction_snark_work.Checked.t option =
        Some
          { Test_input1.Transaction_snark_work.Checked.fee=
              Fee.Unsigned.of_int 1
          ; proofs= stmts
          ; prover= "P" }
      in
      Backtrace.elide := false ;
      let logger = Logger.create () in
      let p = Int.pow 2 Test_input1.Config.transaction_capacity_log_2 in
      let g = Int.gen_incl 1 p in
      let initial_ledger = ref 0 in
      let sl = Sl.create ~ledger:initial_ledger in
      let proof = ref "0" in
      Quickcheck.test g ~trials:1000 ~f:(fun i ->
          let old_ledger = !(Sl.ledger sl) in
          let all_ts = txns p (fun x -> (x + 1) * 100) (fun _ -> 4) in
          let ts = List.take all_ts i in
          let proof, diff, sl =
            create_and_apply sl logger (Sequence.of_list ts) get_work proof
            |> Or_error.ok_exn
          in
          let fee_excess =
            Option.value_map ~default:Currency.Fee.Signed.zero proof
              ~f:(fun proof ->
                let stmt = Test_input1.Ledger_proof.statement proof in
                stmt.fee_excess )
          in
          (*fee_excess at the top should always be zero*)
          assert (Currency.Fee.Signed.equal fee_excess Currency.Fee.Signed.zero) ;
          let cb = coinbase_added diff in
          (*With just one prover, coinbase should never be split*)
          assert (cb = 1) ;
          let x =
            List.length (Test_input1.Staged_ledger_diff.user_commands diff)
          in
          assert_at_least_coinbase_added x cb ;
          let expected_value = expected_ledger x all_ts old_ledger in
          assert (!(Sl.ledger sl) = expected_value) )

    let%test_unit "Reproduce invalid statement error" =
      (*Always at worst case number of provers*)
      Backtrace.elide := false ;
      let get_work (stmts : Test_input1.Transaction_snark_work.Statement.t) :
          Test_input1.Transaction_snark_work.Checked.t option =
        Some
          { Test_input1.Transaction_snark_work.Checked.fee= Fee.Unsigned.zero
          ; proofs= stmts
          ; prover= "P" }
      in
      let logger = Logger.create () in
      let txns =
        List.init 6 ~f:(fun _ -> [])
        @ [[(1, 0); (1, 0); (1, 0)]] @ [[(1, 0); (1, 0)]] @ [[(1, 0); (1, 0)]]
      in
      let ledger = ref 0 in
      let sl = Sl.create ~ledger in
      let proof = ref "0" in
      let _ =
        List.fold ~init:sl txns ~f:(fun _ ts ->
            let _, _, sl =
              create_and_apply sl logger (Sequence.of_list ts) get_work proof
              |> Or_error.ok_exn
            in
            sl )
      in
      ()

    let%test_unit "Snarked ledger" =
      Backtrace.elide := false ;
      let logger = Logger.create () in
      let p = Int.pow 2 Test_input1.Config.transaction_capacity_log_2 in
      let g = Int.gen_incl 1 p in
      let initial_ledger = ref 0 in
      let sl = Sl.create ~ledger:initial_ledger in
      let proof = ref "0" in
      let expected_snarked_ledger = ref 0 in
      Quickcheck.test g ~trials:50 ~f:(fun i ->
          let _old_ledger = !(Sl.ledger sl) in
          let all_ts = txns p (fun x -> (x + 1) * 100) (fun _ -> 4) in
          let ts = List.take all_ts i in
          let proof, _, sl =
            create_and_apply sl logger (Sequence.of_list ts) stmt_to_work proof
            |> Or_error.ok_exn
          in
          let last_snarked_ledger, snarked_ledger_hash =
            Option.value_map
              ~default:
                ( !expected_snarked_ledger
                , Int.to_string !expected_snarked_ledger )
              ~f:(fun p -> (Int.of_string p.target, p.target))
              proof
          in
          expected_snarked_ledger := last_snarked_ledger ;
          let materialized_ledger =
            Or_error.ok_exn @@ Sl.snarked_ledger sl ~snarked_ledger_hash
          in
          assert (!expected_snarked_ledger = !materialized_ledger) )
  end )
