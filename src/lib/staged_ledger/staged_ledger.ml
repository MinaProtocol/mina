[%%import
"../../config.mlh"]

open Core_kernel
open Async_kernel
open Coda_base
open Currency
open O1trace
open Signature_lib

let option lab =
  Option.value_map ~default:(Or_error.error_string lab) ~f:(fun x -> Ok x)

module T = struct
  module Scan_state = Transaction_snark_scan_state
  module Pre_diff_info = Pre_diff_info

  module Staged_ledger_error = struct
    type t =
      | Non_zero_fee_excess of
          Scan_state.Space_partition.t * Transaction.t list
      | Invalid_proof of
          Ledger_proof.t
          * Transaction_snark.Statement.t
          * Public_key.Compressed.t
      | Pre_diff of Pre_diff_info.Error.t
      | Insufficient_work of string
      | Unexpected of Error.t
    [@@deriving sexp]

    let to_string = function
      | Non_zero_fee_excess (partition, txns) ->
          Format.asprintf
            !"Fee excess is non-zero for the transactions: %{sexp: \
              Transaction.t list} and the current queue with slots \
              partitioned as %{sexp: Scan_state.Space_partition.t} \n"
            txns partition
      | Pre_diff pre_diff_error ->
          Format.asprintf
            !"Pre_diff_info.Error error: %{sexp:Pre_diff_info.Error.t}"
            pre_diff_error
      | Invalid_proof (_p, s, prover) ->
          Format.asprintf
            !"Verification failed for proof with statement: %{sexp: \
              Transaction_snark.Statement.t} work_id: %i Prover:%s}\n"
            s
            (Transaction_snark.Statement.hash s)
            (Yojson.Safe.to_string @@ Public_key.Compressed.to_yojson prover)
      | Insufficient_work str ->
          str
      | Unexpected e ->
          Error.to_string_hum e

    let to_error = Fn.compose Error.of_string to_string
  end

  let to_staged_ledger_or_error = function
    | Ok a ->
        Ok a
    | Error e ->
        Error (Staged_ledger_error.Unexpected e)

  type job = Scan_state.Available_job.t [@@deriving sexp]

  let verify_proof ~logger ~verifier ~proof ~statement ~message =
    let log_error err_str ~metadata =
      Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
        ~metadata:
          ( [ ("statement", Transaction_snark.Statement.to_yojson statement)
            ; ("error", `String err_str)
            ; ("sok_message", Sok_message.to_yojson message) ]
          @ metadata )
        "Invalid transaction snark for statement $statement: $error" ;
      Deferred.return false
    in
    let statement_eq a b = Int.(Transaction_snark.Statement.compare a b = 0) in
    if not (statement_eq (Ledger_proof.statement proof) statement) then
      log_error "Statement and proof do not match"
        ~metadata:
          [ ( "statement_from_proof"
            , Transaction_snark.Statement.to_yojson
                (Ledger_proof.statement proof) ) ]
    else
      match%bind Verifier.verify_transaction_snark verifier proof ~message with
      | Ok b ->
          Deferred.return b
      | Error e ->
          log_error (Error.to_string_hum e) ~metadata:[]

  let verify ~logger ~verifier ~message job proof prover =
    let open Deferred.Let_syntax in
    match Scan_state.statement_of_job job with
    | None ->
        Deferred.return
          ( Or_error.errorf !"Error creating statement from job %{sexp:job}" job
          |> to_staged_ledger_or_error )
    | Some statement -> (
        match%map
          verify_proof ~logger ~verifier ~proof ~statement ~message
        with
        | true ->
            Ok ()
        | _ ->
            Error
              (Staged_ledger_error.Invalid_proof (proof, statement, prover)) )

  module M = struct
    include Monad.Ident
    module Or_error = Or_error
  end

  module Statement_scanner = struct
    include Scan_state.Make_statement_scanner
              (M)
              (struct
                type t = unit

                let verify ~verifier:() ~proof:_ ~statement:_ ~message:_ = true
              end)
  end

  module Statement_scanner_proof_verifier = struct
    type t = {logger: Logger.t; verifier: Verifier.t}

    let verify ~verifier:{logger; verifier} = verify_proof ~logger ~verifier
  end

  module Statement_scanner_with_proofs =
    Scan_state.Make_statement_scanner
      (Deferred)
      (Statement_scanner_proof_verifier)

  type t =
    { scan_state: Scan_state.t
          (* Invariant: this is the ledger after having applied all the transactions in
     *the above state. *)
    ; ledger: Ledger.attached_mask sexp_opaque
    ; pending_coinbase_collection: Pending_coinbase.t }
  [@@deriving sexp]

  let proof_txns t =
    Scan_state.latest_ledger_proof t.scan_state
    |> Option.bind ~f:(Fn.compose Non_empty_list.of_list_opt snd)

  let scan_state {scan_state; _} = scan_state

  let all_work_pairs_exn t = Scan_state.all_work_pairs_exn t.scan_state

  let pending_coinbase_collection {pending_coinbase_collection; _} =
    pending_coinbase_collection

  let get_target ((proof, _), _) =
    let {Transaction_snark.Statement.target; _} =
      Ledger_proof.statement proof
    in
    target

  let verify_scan_state_after_apply ledger (scan_state : Scan_state.t) =
    let error_prefix =
      "Error verifying the parallel scan state after applying the diff."
    in
    match Scan_state.latest_ledger_proof scan_state with
    | None ->
        Statement_scanner.check_invariants scan_state ~verifier:()
          ~error_prefix ~ledger_hash_end:ledger ~ledger_hash_begin:None
    | Some proof ->
        Statement_scanner.check_invariants scan_state ~verifier:()
          ~error_prefix ~ledger_hash_end:ledger
          ~ledger_hash_begin:(Some (get_target proof))

  (* TODO: Remove this. This is deprecated *)
  let materialized_snarked_ledger_hash :
         t
      -> expected_target:Frozen_ledger_hash.t
      -> Frozen_ledger_hash.t Or_error.t =
   fun {ledger; scan_state; _} ~expected_target ->
    let open Or_error.Let_syntax in
    let txns_still_being_worked_on = Scan_state.staged_undos scan_state in
    let snarked_ledger = Ledger.register_mask ledger (Ledger.Mask.create ()) in
    let res =
      let%bind () =
        Scan_state.Staged_undos.apply txns_still_being_worked_on snarked_ledger
      in
      let snarked_ledger_hash =
        Ledger.merkle_root snarked_ledger |> Frozen_ledger_hash.of_ledger_hash
      in
      if not (Frozen_ledger_hash.equal snarked_ledger_hash expected_target)
      then
        Or_error.errorf
          !"Error materializing the snarked ledger with hash \
            %{sexp:Frozen_ledger_hash.t} got %{sexp:Frozen_ledger_hash.t}: "
          expected_target snarked_ledger_hash
      else
        match Scan_state.latest_ledger_proof scan_state with
        | None ->
            return snarked_ledger_hash
        | Some proof ->
            let target = get_target proof in
            if Frozen_ledger_hash.equal snarked_ledger_hash target then
              return snarked_ledger_hash
            else
              Or_error.errorf
                !"Last snarked ledger (%{sexp: Frozen_ledger_hash.t}) is \
                  different from the one being requested ((%{sexp: \
                  Frozen_ledger_hash.t}))"
                target expected_target
    in
    (* Make sure we don't leak this mask. *)
    Ledger.unregister_mask_exn ledger snarked_ledger |> ignore ;
    res

  let statement_exn t =
    match Statement_scanner.scan_statement t.scan_state ~verifier:() with
    | Ok s ->
        `Non_empty s
    | Error `Empty ->
        `Empty
    | Error (`Error e) ->
        failwithf !"statement_exn: %{sexp:Error.t}" e ()

  let of_scan_state_and_ledger ~logger ~verifier ~snarked_ledger_hash ~ledger
      ~scan_state ~pending_coinbase_collection =
    let open Deferred.Or_error.Let_syntax in
    let verify_snarked_ledger t snarked_ledger_hash =
      match
        materialized_snarked_ledger_hash t ~expected_target:snarked_ledger_hash
      with
      | Ok _ ->
          Ok ()
      | Error e ->
          Or_error.error_string
            ( "Error verifying snarked ledger hash from the ledger.\n"
            ^ Error.to_string_hum e )
    in
    let t = {ledger; scan_state; pending_coinbase_collection} in
    let%bind () =
      Statement_scanner_with_proofs.check_invariants scan_state
        ~verifier:{Statement_scanner_proof_verifier.logger; verifier}
        ~error_prefix:"Staged_ledger.of_scan_state_and_ledger"
        ~ledger_hash_end:
          (Frozen_ledger_hash.of_ledger_hash (Ledger.merkle_root ledger))
        ~ledger_hash_begin:(Some snarked_ledger_hash)
    in
    let%bind () =
      Deferred.return (verify_snarked_ledger t snarked_ledger_hash)
    in
    return t

  let of_scan_state_pending_coinbases_and_snarked_ledger ~logger ~verifier
      ~scan_state ~snarked_ledger ~expected_merkle_root ~pending_coinbases =
    let open Deferred.Or_error.Let_syntax in
    let snarked_ledger_hash = Ledger.merkle_root snarked_ledger in
    let snarked_frozen_ledger_hash =
      Frozen_ledger_hash.of_ledger_hash snarked_ledger_hash
    in
    let%bind txs =
      Scan_state.staged_transactions scan_state |> Deferred.return
    in
    let%bind () =
      List.fold_result
        ~f:(fun _ tx ->
          Ledger.apply_transaction snarked_ledger tx |> Or_error.ignore )
        ~init:() txs
      |> Deferred.return
    in
    let%bind () =
      let staged_ledger_hash = Ledger.merkle_root snarked_ledger in
      Deferred.return
      @@ Result.ok_if_true
           (Ledger_hash.equal expected_merkle_root staged_ledger_hash)
           ~error:
             (Error.createf
                !"Mismatching merkle root Expected:%{sexp:Ledger_hash.t} \
                  Got:%{sexp:Ledger_hash.t}"
                expected_merkle_root staged_ledger_hash)
    in
    of_scan_state_and_ledger ~logger ~verifier
      ~snarked_ledger_hash:snarked_frozen_ledger_hash ~ledger:snarked_ledger
      ~scan_state ~pending_coinbase_collection:pending_coinbases

  let copy {scan_state; ledger; pending_coinbase_collection} =
    let new_mask = Ledger.Mask.create () in
    { scan_state
    ; ledger= Ledger.register_mask ledger new_mask
    ; pending_coinbase_collection }

  let hash {scan_state; ledger; pending_coinbase_collection} :
      Staged_ledger_hash.t =
    Staged_ledger_hash.of_aux_ledger_and_coinbase_hash
      (Scan_state.hash scan_state)
      (Ledger.merkle_root ledger)
      pending_coinbase_collection

  [%%if
  call_logger]

  let hash t =
    Coda_debug.Call_logger.record_call "Staged_ledger.hash" ;
    hash t

  [%%endif]

  let ledger {ledger; _} = ledger

  let create_exn ~ledger : t =
    { scan_state= Scan_state.empty ()
    ; ledger
    ; pending_coinbase_collection=
        Pending_coinbase.create () |> Or_error.ok_exn }

  let current_ledger_proof t =
    Option.map
      (Scan_state.latest_ledger_proof t.scan_state)
      ~f:(Fn.compose fst fst)

  let replace_ledger_exn t ledger =
    [%test_result: Ledger_hash.t]
      ~message:"Cannot replace ledger since merkle_root differs"
      ~expect:(Ledger.merkle_root t.ledger)
      (Ledger.merkle_root ledger) ;
    {t with ledger}

  let sum_fees xs ~f =
    with_return (fun {return} ->
        Ok
          (List.fold ~init:Fee.zero xs ~f:(fun acc x ->
               match Fee.add acc (f x) with
               | None ->
                   return (Or_error.error_string "Fee overflow")
               | Some res ->
                   res )) )

  let working_stack pending_coinbase_collection ~is_new_stack =
    to_staged_ledger_or_error
      (Pending_coinbase.latest_stack pending_coinbase_collection ~is_new_stack)

  let push_coinbase_and_get_new_collection current_stack (t : Transaction.t) =
    match t with
    | Coinbase c ->
        Pending_coinbase.Stack.push current_stack c
    | _ ->
        current_stack

  let apply_transaction_and_get_statement ledger current_stack s =
    let open Result.Let_syntax in
    let%bind fee_excess = Transaction.fee_excess s |> to_staged_ledger_or_error
    and supply_increase =
      Transaction.supply_increase s |> to_staged_ledger_or_error
    in
    let source =
      Ledger.merkle_root ledger |> Frozen_ledger_hash.of_ledger_hash
    in
    let pending_coinbase_after =
      push_coinbase_and_get_new_collection current_stack s
    in
    let%map undo =
      Ledger.apply_transaction ledger s |> to_staged_ledger_or_error
    in
    ( undo
    , { Transaction_snark.Statement.source
      ; target= Ledger.merkle_root ledger |> Frozen_ledger_hash.of_ledger_hash
      ; fee_excess
      ; supply_increase
      ; pending_coinbase_stack_state=
          {source= current_stack; target= pending_coinbase_after}
      ; proof_type= `Base }
    , pending_coinbase_after )

  let apply_transaction_and_get_witness ledger current_stack s =
    let open Deferred.Let_syntax in
    let public_keys = function
      | Transaction.Fee_transfer t ->
          Fee_transfer.receivers t
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
    let ledger_witness =
      measure "sparse ledger" (fun () ->
          Sparse_ledger.of_ledger_subset_exn ledger (public_keys s) )
    in
    let%bind () = Async.Scheduler.yield () in
    let r =
      measure "apply+stmt" (fun () ->
          apply_transaction_and_get_statement ledger current_stack s )
    in
    let%map () = Async.Scheduler.yield () in
    let open Result.Let_syntax in
    let%map undo, statement, updated_coinbase_stack = r in
    ( { Scan_state.Transaction_with_witness.transaction_with_info= undo
      ; witness= {ledger= ledger_witness}
      ; statement }
    , updated_coinbase_stack )

  let update_ledger_and_get_statements ledger current_stack ts =
    let open Deferred.Let_syntax in
    let rec go coinbase_stack acc = function
      | [] ->
          return (Ok (List.rev acc, coinbase_stack))
      | t :: ts -> (
          match%bind
            apply_transaction_and_get_witness ledger coinbase_stack t
          with
          | Ok (res, updated_coinbase_stack) ->
              go updated_coinbase_stack (res :: acc) ts
          | Error e ->
              return (Error e) )
    in
    go current_stack [] ts

  let check_completed_works ~logger ~verifier scan_state
      (completed_works : Transaction_snark_work.t list) =
    let work_count = List.length completed_works in
    let job_pairs =
      Scan_state.k_work_pairs_for_new_diff scan_state ~k:work_count
    in
    let check job_proofs prover message =
      One_or_two.Deferred_result.map job_proofs ~f:(fun (job, proof) ->
          verify ~logger ~verifier ~message job proof prover )
    in
    let open Deferred.Let_syntax in
    let%map result =
      Deferred.List.find_map (List.zip_exn job_pairs completed_works)
        ~f:(fun (jobs, work) ->
          let message = Sok_message.create ~fee:work.fee ~prover:work.prover in
          Deferred.map ~f:Result.error
          @@ check (One_or_two.zip_exn jobs work.proofs) work.prover message )
    in
    Option.value_map result ~default:(Ok ()) ~f:(fun e -> Error e)

  (**The total fee excess caused by any diff should be zero. In the case where
     the slots are split into two partitions, total fee excess of the transactions
     to be enqueued on each of the partitions should be zero respectively *)
  let check_zero_fee_excess scan_state data =
    let zero = Fee.Signed.zero in
    let partitions = Scan_state.partition_if_overflowing scan_state in
    let txns_from_data data =
      List.fold_right ~init:(Ok []) data
        ~f:(fun (d : Scan_state.Transaction_with_witness.t) acc ->
          let open Or_error.Let_syntax in
          let%bind acc = acc in
          let%map t = d.transaction_with_info |> Ledger.Undo.transaction in
          t :: acc )
    in
    let total_fee_excess txns =
      List.fold txns ~init:(Ok (Some zero)) ~f:(fun fe (txn : Transaction.t) ->
          let open Or_error.Let_syntax in
          let%bind fe' = fe in
          let%map fee_excess = Transaction.fee_excess txn in
          Option.bind fe' ~f:(fun f -> Fee.Signed.add f fee_excess) )
      |> to_staged_ledger_or_error
    in
    let open Result.Let_syntax in
    let check data slots =
      let%bind txns = txns_from_data data |> to_staged_ledger_or_error in
      let%bind fe = total_fee_excess txns in
      let%bind fe_no_overflow =
        Option.value_map
          ~default:
            (to_staged_ledger_or_error
               (Or_error.error_string "fee excess overflow"))
          ~f:(fun fe -> Ok fe)
          fe
      in
      if Fee.Signed.equal fe_no_overflow zero then Ok ()
      else Error (Non_zero_fee_excess (slots, txns))
    in
    let%bind () = check (List.take data (fst partitions.first)) partitions in
    Option.value_map ~default:(Result.return ())
      ~f:(fun _ -> check (List.drop data (fst partitions.first)) partitions)
      partitions.second

  let update_coinbase_stack_and_get_data scan_state ledger
      pending_coinbase_collection transactions =
    let open Deferred.Result.Let_syntax in
    let coinbase_exists ~get_transaction txns =
      List.fold_until ~init:(Ok false) txns
        ~f:(fun acc t ->
          match get_transaction t with
          | Ok (Transaction.Coinbase _) ->
              Stop (Ok true)
          | Error e ->
              Stop (Error e)
          | _ ->
              Continue acc )
        ~finish:Fn.id
      |> Deferred.return
    in
    let {Scan_state.Space_partition.first= slots, _; second} =
      Scan_state.partition_if_overflowing scan_state
    in
    match second with
    | None ->
        (*Single partition:
         1.Check if a new stack is required and get a working stack [working_stack]
         2.create data for enqueuing onto the scan state *)
        let is_new_tree = Scan_state.next_on_new_tree scan_state in
        let have_data_to_enqueue = List.length transactions > 0 in
        let is_new_stack = is_new_tree && have_data_to_enqueue in
        let%bind working_stack =
          working_stack pending_coinbase_collection ~is_new_stack
          |> Deferred.return
        in
        let%map data, updated_stack =
          update_ledger_and_get_statements ledger working_stack transactions
        in
        (is_new_stack, data, `Update_one updated_stack)
    | Some _ ->
        (*Two partition:
        Assumption: Only one of the partition will have coinbase transaction(s)in it.
        1. Get the latest stack for coinbase in the first set of transactions
        2. get the first set of scan_state data[data1]
        3. get a new stack for the second parition because the second set of transactions would start from the begining of the scan_state
        4. get the second set of scan_state data[data2]*)
        let%bind working_stack1 =
          working_stack pending_coinbase_collection ~is_new_stack:false
          |> Deferred.return
        in
        let%bind data1, updated_stack1 =
          update_ledger_and_get_statements ledger working_stack1
            (List.take transactions slots)
        in
        let%bind working_stack2 =
          working_stack pending_coinbase_collection ~is_new_stack:true
          |> Deferred.return
        in
        let%bind data2, updated_stack2 =
          update_ledger_and_get_statements ledger working_stack2
            (List.drop transactions slots)
        in
        let%map first_has_coinbase =
          coinbase_exists
            ~get_transaction:(fun x -> Ok x)
            (List.take transactions slots)
        in
        let second_has_data = List.length (List.drop transactions slots) > 0 in
        let new_stack_in_snark, stack_update =
          match (first_has_coinbase, second_has_data) with
          | true, true ->
              (false, `Update_two (updated_stack1, updated_stack2))
          (*updated_stack2 will not have any coinbase and therefore we don't want to create a new stack in snark. updated_stack2 is only used to update the pending_coinbase_aux because there's going to be data(second has data) on a "new tree"*)
          | true, false ->
              (false, `Update_one updated_stack1)
          | false, true ->
              (true, `Update_one updated_stack2)
          (*updated stack2 has coinbase and it will be on a "new tree"*)
          | false, false ->
              (false, `Update_none)
        in
        (new_stack_in_snark, data1 @ data2, stack_update)

  (*update the pending_coinbase tree with the updated/new stack and delete the oldest stack if a proof was emitted*)
  let update_pending_coinbase_collection pending_coinbase_collection
      stack_update ~is_new_stack ~ledger_proof =
    let open Result.Let_syntax in
    (*Deleting oldest stack if proof emitted*)
    let%bind pending_coinbase_collection_updated1 =
      match ledger_proof with
      | Some (proof, _) ->
          let%bind oldest_stack, pending_coinbase_collection_updated1 =
            Pending_coinbase.remove_coinbase_stack pending_coinbase_collection
            |> to_staged_ledger_or_error
          in
          let ledger_proof_stack =
            (Ledger_proof.statement proof).pending_coinbase_stack_state.target
          in
          let%map () =
            if Pending_coinbase.Stack.equal oldest_stack ledger_proof_stack
            then Ok ()
            else
              Error
                (Staged_ledger_error.Unexpected
                   (Error.of_string
                      "Pending coinbase stack of the ledger proof did not \
                       match the oldest stack in the pending coinbase tree."))
          in
          pending_coinbase_collection_updated1
      | None ->
          Ok pending_coinbase_collection
    in
    (*updating the latest stack and/or adding a new one*)
    let%map pending_coinbase_collection_updated2 =
      match stack_update with
      | `Update_none ->
          Ok pending_coinbase_collection_updated1
      | `Update_one stack1 ->
          Pending_coinbase.update_coinbase_stack
            pending_coinbase_collection_updated1 stack1 ~is_new_stack
          |> to_staged_ledger_or_error
      | `Update_two (stack1, stack2) ->
          (*The case when part of the transactions go in to the old tree and remaining on to the new tree*)
          let%bind update1 =
            Pending_coinbase.update_coinbase_stack
              pending_coinbase_collection_updated1 stack1 ~is_new_stack:false
            |> to_staged_ledger_or_error
          in
          Pending_coinbase.update_coinbase_stack update1 stack2
            ~is_new_stack:true
          |> to_staged_ledger_or_error
    in
    pending_coinbase_collection_updated2

  let coinbase_for_blockchain_snark = function
    | [] ->
        Ok Currency.Amount.zero
    | [amount] ->
        Ok amount
    | [amount1; _] ->
        Ok amount1
    | _ ->
        Error
          (Staged_ledger_error.Pre_diff
             (Pre_diff_info.Error.Coinbase_error "More than two coinbase parts"))

  let apply_diff ~logger t pre_diff_info =
    let open Deferred.Result.Let_syntax in
    let max_throughput =
      Int.pow 2
        Transaction_snark_scan_state.Constants.transaction_capacity_log_2
    in
    let spots_available, proofs_waiting =
      let jobs = Scan_state.all_work_statements t.scan_state in
      ( Int.min (Scan_state.free_space t.scan_state) max_throughput
      , List.length jobs )
    in
    let new_mask = Ledger.Mask.create () in
    let new_ledger = Ledger.register_mask t.ledger new_mask in
    let transactions, works, user_commands_count, coinbases = pre_diff_info in
    let%bind is_new_stack, data, stack_update =
      update_coinbase_stack_and_get_data t.scan_state new_ledger
        t.pending_coinbase_collection transactions
    in
    let slots = List.length data in
    let work_count = List.length works in
    let required_pairs =
      Scan_state.work_statements_for_new_diff t.scan_state
    in
    let%bind () =
      let required = List.length required_pairs in
      if
        work_count < required
        && List.length data
           > Scan_state.free_space t.scan_state - required + work_count
      then
        Deferred.return
          (Error
             (Staged_ledger_error.Insufficient_work
                (sprintf
                   !"Insufficient number of transaction snark work (slots \
                     occupying: %d)  required %d, got %d"
                   slots required work_count)))
      else Deferred.return (Ok ())
    in
    let%bind () = Deferred.return (check_zero_fee_excess t.scan_state data) in
    let%bind res_opt, scan_state' =
      let r =
        Scan_state.fill_work_and_enqueue_transactions t.scan_state data works
      in
      Or_error.iter_error r ~f:(fun e ->
          let data_json =
            `List
              (List.map data
                 ~f:(fun {Scan_state.Transaction_with_witness.statement; _} ->
                   Transaction_snark.Statement.to_yojson statement ))
          in
          Logger.error logger ~module_:__MODULE__ ~location:__LOC__
            ~metadata:
              [ ( "scan_state"
                , `String (Scan_state.snark_job_list_json t.scan_state) )
              ; ("data", data_json) ]
            !"Unexpected error when applying diff data $data to the \
              scan_state $scan_state: %s\n\
              %!"
            (Error.to_string_hum e) ) ;
      Deferred.return (to_staged_ledger_or_error r)
    in
    let%bind updated_pending_coinbase_collection' =
      update_pending_coinbase_collection t.pending_coinbase_collection
        stack_update ~is_new_stack ~ledger_proof:res_opt
      |> Deferred.return
    in
    let%bind coinbase_amount =
      coinbase_for_blockchain_snark coinbases |> Deferred.return
    in
    let%map () =
      Deferred.return
        ( verify_scan_state_after_apply
            (Frozen_ledger_hash.of_ledger_hash (Ledger.merkle_root new_ledger))
            scan_state'
        |> to_staged_ledger_or_error )
    in
    Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
      ~metadata:
        [ ("user_command_count", `Int user_commands_count)
        ; ("coinbase_count", `Int (List.length coinbases))
        ; ("spots_available", `Int spots_available)
        ; ("proof_bundles_waiting", `Int proofs_waiting)
        ; ("work_count", `Int (List.length works)) ]
      "apply_diff block info: No of transactions included:$user_command_count\n\
      \      Coinbase parts:$coinbase_count Spots\n\
      \      available:$spots_available Pending work in the \
       scan-state:$proof_bundles_waiting Work included:$work_count" ;
    let new_staged_ledger =
      { scan_state= scan_state'
      ; ledger= new_ledger
      ; pending_coinbase_collection= updated_pending_coinbase_collection' }
    in
    ( `Hash_after_applying (hash new_staged_ledger)
    , `Ledger_proof res_opt
    , `Staged_ledger new_staged_ledger
    , `Pending_coinbase_data (is_new_stack, coinbase_amount) )

  let apply t witness ~logger ~verifier =
    let open Deferred.Result.Let_syntax in
    let work = Staged_ledger_diff.completed_works witness in
    Coda_metrics.(
      Gauge.set Snark_work.completed_snark_work_last_block
        (Float.of_int @@ List.length work)) ;
    let%bind () = check_completed_works ~logger ~verifier t.scan_state work in
    let%bind prediff =
      Result.map_error ~f:(fun error -> Staged_ledger_error.Pre_diff error)
      @@ Pre_diff_info.get witness
      |> Deferred.return
    in
    let%map res = apply_diff t prediff ~logger in
    let _, _, `Staged_ledger new_staged_ledger, _ = res in
    let () =
      try
        Coda_metrics.(
          Gauge.set Snark_work.scan_state_snark_work
            (Float.of_int
               (List.length
                  (Scan_state.all_work_pairs_exn new_staged_ledger.scan_state))))
      with exn ->
        Logger.error logger ~module_:__MODULE__ ~location:__LOC__
          ~metadata:[("error", `String (Exn.to_string exn))]
          !"Error when getting all work pairs from scan state: $error" ;
        Exn.reraise exn "Error when getting all work pairs from scan state"
    in
    res

  let apply_diff_unchecked t
      (sl_diff : Staged_ledger_diff.With_valid_signatures_and_proofs.t) =
    let open Deferred.Result.Let_syntax in
    let%bind prediff =
      Result.map_error ~f:(fun error -> Staged_ledger_error.Pre_diff error)
      @@ Pre_diff_info.get_unchecked sl_diff
      |> Deferred.return
    in
    apply_diff t prediff ~logger:(Logger.null ())

  module Resources = struct
    module Discarded = struct
      type t =
        { user_commands_rev: User_command.With_valid_signature.t Sequence.t
        ; completed_work: Transaction_snark_work.Checked.t Sequence.t }
      [@@deriving sexp_of]

      let add_user_command t uc =
        { t with
          user_commands_rev=
            Sequence.append t.user_commands_rev (Sequence.singleton uc) }

      let add_completed_work t cw =
        { t with
          completed_work=
            Sequence.append (Sequence.singleton cw) t.completed_work }
    end

    type t =
      { max_space: int (*max space available currently*)
      ; max_jobs: int
            (*Required amount of work for max_space that can be purchased*)
      ; user_commands_rev: User_command.With_valid_signature.t Sequence.t
      ; completed_work_rev: Transaction_snark_work.Checked.t Sequence.t
      ; fee_transfers: Fee.t Public_key.Compressed.Map.t
      ; coinbase:
          (Public_key.Compressed.t * Fee.t) Staged_ledger_diff.At_most_two.t
      ; self_pk: Public_key.Compressed.t
      ; budget: Fee.t Or_error.t
      ; discarded: Discarded.t
      ; logger: Logger.t }

    let coinbase_ft (cw : Transaction_snark_work.t) =
      (* Here we could not add the fee transfer if the prover=self but
      retaining it to preserve that information in the
      staged_ledger_diff. It will be checked in apply_diff before adding*)
      Option.some_if (cw.fee > Fee.zero) (cw.prover, cw.fee)

    let init (uc_seq : User_command.With_valid_signature.t Sequence.t)
        (cw_seq : Transaction_snark_work.Checked.t Sequence.t)
        (slots, job_count) self_pk ~add_coinbase logger =
      let seq_rev seq =
        let rec go seq rev_seq =
          match Sequence.next seq with
          | Some (w, rem_seq) ->
              go rem_seq (Sequence.append (Sequence.singleton w) rev_seq)
          | None ->
              rev_seq
        in
        go seq Sequence.empty
      in
      let cw_unchecked =
        Sequence.map cw_seq ~f:Transaction_snark_work.forget
      in
      let coinbase, rem_cw =
        match (add_coinbase, Sequence.next cw_unchecked) with
        | true, Some (cw, rem_cw) ->
            (Staged_ledger_diff.At_most_two.One (coinbase_ft cw), rem_cw)
        | true, None ->
            if job_count = 0 || slots - job_count >= 1 then
              (One None, cw_unchecked)
            else (Zero, cw_unchecked)
        | _ ->
            (Zero, cw_unchecked)
      in
      let singles =
        Sequence.filter_map rem_cw
          ~f:(fun {Transaction_snark_work.fee; prover; _} ->
            if Fee.equal fee Fee.zero then None else Some (prover, fee) )
        |> Sequence.to_list_rev
      in
      let fee_transfers =
        Public_key.Compressed.Map.of_alist_reduce singles ~f:(fun f1 f2 ->
            Option.value_exn (Fee.add f1 f2) )
      in
      let budget =
        Or_error.map2
          (sum_fees (Sequence.to_list uc_seq) ~f:(fun t ->
               User_command.fee (t :> User_command.t) ))
          (sum_fees
             (List.filter
                ~f:(fun (k, _) -> not (Public_key.Compressed.equal k self_pk))
                singles)
             ~f:snd)
          ~f:(fun r c -> option "budget did not suffice" (Fee.sub r c))
        |> Or_error.join
      in
      let discarded =
        { Discarded.completed_work= Sequence.empty
        ; user_commands_rev= Sequence.empty }
      in
      { max_space= slots
      ; max_jobs= job_count
      ; user_commands_rev=
          uc_seq
          (*Completed work in reverse order for faster removal of proofs if budget doesn't suffice*)
      ; completed_work_rev= seq_rev cw_seq
      ; fee_transfers
      ; self_pk
      ; coinbase
      ; budget
      ; discarded
      ; logger }

    let re_budget t =
      let open Or_error.Let_syntax in
      let payment_fees =
        sum_fees (Sequence.to_list t.user_commands_rev) ~f:(fun t ->
            User_command.fee (t :> User_command.t) )
      in
      let prover_fee_others =
        Public_key.Compressed.Map.fold t.fee_transfers ~init:(Ok Fee.zero)
          ~f:(fun ~key ~data fees ->
            let%bind others = fees in
            if Public_key.Compressed.equal t.self_pk key then Ok others
            else option "Fee overflow" (Fee.add others data) )
      in
      let revenue = payment_fees in
      let cost = prover_fee_others in
      Or_error.map2 revenue cost ~f:(fun r c ->
          option "budget did not suffice" (Fee.sub r c) )
      |> Or_error.join

    let budget_sufficient t =
      match t.budget with Ok _ -> true | Error _ -> false

    let coinbase_added t =
      match t.coinbase with
      | Staged_ledger_diff.At_most_two.Zero ->
          0
      | One _ ->
          1
      | Two _ ->
          2

    let slots_occupied t =
      let fee_for_self =
        match t.budget with
        | Error _ ->
            0
        | Ok b ->
            if b > Fee.zero then 1 else 0
      in
      let other_provers =
        Public_key.Compressed.Map.filter_keys t.fee_transfers
          ~f:(Fn.compose not (Public_key.Compressed.equal t.self_pk))
      in
      let total_fee_transfer_pks =
        Public_key.Compressed.Map.length other_provers + fee_for_self
      in
      Sequence.length t.user_commands_rev
      + ((total_fee_transfer_pks + 1) / 2)
      + coinbase_added t

    let space_available res =
      let slots = slots_occupied res in
      res.max_space > slots

    let work_done t =
      let no_of_proof_bundles = Sequence.length t.completed_work_rev in
      let slots = slots_occupied t in
      (*If more jobs were added in the previous diff then ( t.max_space-t.max_jobs) slots can go for free in this diff*)
      no_of_proof_bundles = t.max_jobs || slots <= t.max_space - t.max_jobs

    let space_constraint_satisfied t =
      let occupied = slots_occupied t in
      occupied <= t.max_space

    let work_constraint_satisfied (t : t) =
      (*Are we doing all the work available? *)
      let all_proofs = work_done t in
      (*enough work*)
      let slots = slots_occupied t in
      let cw_count = Sequence.length t.completed_work_rev in
      let enough_work = cw_count >= slots in
      (*if there are no transactions then don't need any proofs*)
      all_proofs || slots = 0 || enough_work

    let available_space t = t.max_space - slots_occupied t

    let incr_coinbase_part_by t count =
      let open Or_error.Let_syntax in
      let incr = function
        | Staged_ledger_diff.At_most_two.Zero, ft_opt ->
            Ok (Staged_ledger_diff.At_most_two.One ft_opt)
        | One None, None ->
            Ok (Two None)
        | One (Some ft), ft_opt ->
            Ok (Two (Some (ft, ft_opt)))
        | _ ->
            Or_error.error_string "Coinbase count cannot be more than two"
      in
      let by_one res =
        let res' =
          match Sequence.next res.discarded.completed_work with
          | Some (w, rem_work) ->
              let w' = Transaction_snark_work.forget w in
              let%map coinbase = incr (res.coinbase, coinbase_ft w') in
              { res with
                completed_work_rev=
                  Sequence.append (Sequence.singleton w) res.completed_work_rev
              ; discarded= {res.discarded with completed_work= rem_work}
              ; coinbase }
          | None ->
              let%bind coinbase = incr (res.coinbase, None) in
              let res = {res with coinbase} in
              if work_done res then Ok res
              else
                Or_error.error_string
                  "Could not increment coinbase transaction count because of \
                   insufficient work"
        in
        match res' with
        | Ok res'' ->
            res''
        | Error e ->
            Logger.error t.logger ~module_:__MODULE__ ~location:__LOC__
              "Error when increasing coinbase: $error"
              ~metadata:[("error", `String (Error.to_string_hum e))] ;
            res
      in
      match count with `One -> by_one t | `Two -> by_one (by_one t)

    let discard_last_work t =
      match Sequence.next t.completed_work_rev with
      | None ->
          t
      | Some (w, rem_seq) ->
          let to_be_discarded = Transaction_snark_work.forget w in
          let current_fee =
            Option.value
              (Public_key.Compressed.Map.find t.fee_transfers
                 to_be_discarded.prover)
              ~default:Fee.zero
          in
          let updated_map =
            match Fee.sub current_fee to_be_discarded.fee with
            | None ->
                Public_key.Compressed.Map.remove t.fee_transfers
                  to_be_discarded.prover
            | Some fee ->
                if fee > Fee.zero then
                  Public_key.Compressed.Map.update t.fee_transfers
                    to_be_discarded.prover ~f:(fun _ -> fee)
                else
                  Public_key.Compressed.Map.remove t.fee_transfers
                    to_be_discarded.prover
          in
          let discarded = Discarded.add_completed_work t.discarded w in
          let new_t =
            { t with
              completed_work_rev= rem_seq
            ; fee_transfers= updated_map
            ; discarded }
          in
          let budget =
            match t.budget with
            | Ok b ->
                option "Currency overflow" (Fee.add b to_be_discarded.fee)
            | _ ->
                re_budget new_t
          in
          {new_t with budget}

    let discard_user_command t =
      let decr_coinbase t =
        (*When discarding coinbase's fee transfer, add the fee transfer to the fee_transfers map so that budget checks can be done *)
        let update_fee_transfers t ft coinbase =
          let updated_fee_transfers =
            Public_key.Compressed.Map.update t.fee_transfers (fst ft)
              ~f:(fun _ -> snd ft)
          in
          let new_t =
            {t with coinbase; fee_transfers= updated_fee_transfers}
          in
          let updated_budget = re_budget new_t in
          {new_t with budget= updated_budget}
        in
        match t.coinbase with
        | Staged_ledger_diff.At_most_two.Zero ->
            t
        | One None ->
            {t with coinbase= Staged_ledger_diff.At_most_two.Zero}
        | Two None ->
            {t with coinbase= One None}
        | Two (Some (ft, None)) ->
            {t with coinbase= One (Some ft)}
        | One (Some ft) ->
            update_fee_transfers t ft Zero
        | Two (Some (ft1, Some ft2)) ->
            update_fee_transfers t ft2 (One (Some ft1))
      in
      match Sequence.next t.user_commands_rev with
      | None ->
          (* If we have reached here then it means we couldn't afford a slot for coinbase as well *)
          decr_coinbase t
      | Some (uc, rem_seq) ->
          let discarded = Discarded.add_user_command t.discarded uc in
          let new_t = {t with user_commands_rev= rem_seq; discarded} in
          let budget =
            match t.budget with
            | Ok b ->
                option "Fee insufficient"
                  (Fee.sub b (User_command.fee (uc :> User_command.t)))
            | _ ->
                re_budget new_t
          in
          {new_t with budget}
  end

  let worked_more (resources : Resources.t) =
    (*Is the work constraint satisfied even after discarding a work bundle?
       We reach here after having more than enough work*)
    let more_work t =
      let slots = Resources.slots_occupied t in
      let cw_count = Sequence.length t.completed_work_rev in
      cw_count > 0 && cw_count >= slots
    in
    let r = Resources.discard_last_work resources in
    more_work r && Resources.space_constraint_satisfied r

  let rec check_constraints_and_update (resources : Resources.t) =
    if Resources.slots_occupied resources = 0 then resources
    else if Resources.work_constraint_satisfied resources then
      if
        (*There's enough work. Check if they satisfy other constraints*)
        Resources.budget_sufficient resources
      then
        if Resources.space_constraint_satisfied resources then resources
        else if worked_more resources then
          (*There are too many fee_transfers(from the proofs) occupying the slots. discard one and check*)
          check_constraints_and_update (Resources.discard_last_work resources)
        else
          (*Well, there's no space; discard a user command *)
          check_constraints_and_update
            (Resources.discard_user_command resources)
      else
        (* insufficient budget; reduce the cost*)
        check_constraints_and_update (Resources.discard_last_work resources)
    else
      (* There isn't enough work for the transactions. Discard a trasnaction and check again *)
      check_constraints_and_update (Resources.discard_user_command resources)

  let one_prediff cw_seq ts_seq self ~add_coinbase partition logger =
    O1trace.measure "one_prediff" (fun () ->
        let init_resources =
          Resources.init ts_seq cw_seq partition self ~add_coinbase logger
        in
        check_constraints_and_update init_resources )

  let generate logger cw_seq ts_seq self
      (partitions : Scan_state.Space_partition.t) =
    let pre_diff_with_one (res : Resources.t) :
        Staged_ledger_diff.With_valid_signatures_and_proofs
        .pre_diff_with_at_most_one_coinbase =
      O1trace.measure "pre_diff_with_one" (fun () ->
          let to_at_most_one = function
            | Staged_ledger_diff.At_most_two.Zero ->
                Staged_ledger_diff.At_most_one.Zero
            | One x ->
                One x
            | _ ->
                Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                  "Error creating staged ledger diff: Should have at most one \
                   coinbase in the second pre_diff" ;
                Zero
          in
          (* We have to reverse here because we only know they work in THIS order *)
          { Staged_ledger_diff.Pre_diff_one.user_commands=
              Sequence.to_list_rev res.user_commands_rev
          ; completed_works= Sequence.to_list_rev res.completed_work_rev
          ; coinbase= to_at_most_one res.coinbase } )
    in
    let pre_diff_with_two (res : Resources.t) :
        Staged_ledger_diff.With_valid_signatures_and_proofs
        .pre_diff_with_at_most_two_coinbase =
      (* We have to reverse here because we only know they work in THIS order *)
      { user_commands= Sequence.to_list_rev res.user_commands_rev
      ; completed_works= Sequence.to_list_rev res.completed_work_rev
      ; coinbase= res.coinbase }
    in
    let make_diff res1 res2_opt =
      (pre_diff_with_two res1, Option.map res2_opt ~f:pre_diff_with_one)
    in
    let has_no_user_commands (res : Resources.t) =
      Sequence.length res.user_commands_rev = 0
    in
    let second_pre_diff (res : Resources.t) partition ~add_coinbase work =
      one_prediff work res.discarded.user_commands_rev self partition
        ~add_coinbase logger
    in
    let isEmpty (res : Resources.t) =
      has_no_user_commands res && Resources.coinbase_added res = 0
    in
    (*Partitioning explained in PR #687 *)
    match partitions.second with
    | None ->
        let res =
          one_prediff cw_seq ts_seq self partitions.first ~add_coinbase:true
            logger
        in
        make_diff res None
    | Some y ->
        assert (Sequence.length cw_seq <= snd partitions.first + snd y) ;
        let cw_seq_1 = Sequence.take cw_seq (snd partitions.first) in
        let cw_seq_2 = Sequence.drop cw_seq (snd partitions.first) in
        let res =
          one_prediff cw_seq_1 ts_seq self partitions.first ~add_coinbase:false
            logger
        in
        let incr_coinbase_and_compute res count =
          let new_res = Resources.incr_coinbase_part_by res count in
          if Resources.space_available new_res then
            (*Don't create the second prediff instead recompute first diff with just once coinbase*)
            ( one_prediff cw_seq_1 ts_seq self partitions.first
                ~add_coinbase:true logger
            , None )
          else
            let res2 =
              second_pre_diff new_res y ~add_coinbase:false cw_seq_2
            in
            if isEmpty res2 then
              (*Don't create the second prediff instead recompute first diff with just once coinbase*)
              ( one_prediff cw_seq_1 ts_seq self partitions.first
                  ~add_coinbase:true logger
              , None )
            else (new_res, Some res2)
        in
        let res1, res2 =
          match Resources.available_space res with
          | 0 ->
              (*generate the next prediff with a coinbase at least*)
              let res2 = second_pre_diff res y ~add_coinbase:true cw_seq_2 in
              (res, Some res2)
          | 1 ->
              (*There's a slot available in the first partition, fill it with coinbase and create another pre_diff for the slots in the second partiton with the remaining user commands and work *)
              incr_coinbase_and_compute res `One
          | 2 ->
              (*There are two slots which cannot be filled using user commands, so we split the coinbase into two parts and fill those two spots*)
              incr_coinbase_and_compute res `Two
          | _ ->
              (* Too many slots left in the first partition. Either there wasn't enough work to add transactions or there weren't enough transactions. Create a new pre_diff for just the first partition*)
              let new_res =
                one_prediff cw_seq_1 ts_seq self partitions.first
                  ~add_coinbase:true logger
              in
              (new_res, None)
        in
        let coinbase_added =
          Resources.coinbase_added res1
          + Option.value_map ~f:Resources.coinbase_added res2 ~default:0
        in
        if coinbase_added > 0 then make_diff res1 res2
        else
          (*Coinbase takes priority over user-commands. Create a diff in partitions.first with coinbase first and user commands if possible*)
          let res =
            one_prediff cw_seq_1 ts_seq self partitions.first
              ~add_coinbase:true logger
          in
          make_diff res None

  let create_diff t ~self ~logger
      ~(transactions_by_fee : User_command.With_valid_signature.t Sequence.t)
      ~(get_completed_work :
            Transaction_snark_work.Statement.t
         -> Transaction_snark_work.Checked.t option) =
    O1trace.trace_event "curr_hash" ;
    let validating_ledger = Transaction_validator.create t.ledger in
    O1trace.trace_event "done mask" ;
    let partitions = Scan_state.partition_if_overflowing t.scan_state in
    O1trace.trace_event "partitioned" ;
    let work_to_do = Scan_state.work_statements_for_new_diff t.scan_state in
    O1trace.trace_event "computed_work" ;
    let completed_works_seq, proof_count =
      List.fold_until work_to_do ~init:(Sequence.empty, 0)
        ~f:(fun (seq, count) w ->
          match get_completed_work w with
          | Some cw_checked ->
              Continue
                ( Sequence.append seq (Sequence.singleton cw_checked)
                , One_or_two.length cw_checked.proofs + count )
          | None ->
              Stop (seq, count) )
        ~finish:Fn.id
    in
    O1trace.trace_event "found completed work" ;
    (*Transactions in reverse order for faster removal if there is no space when creating the diff*)
    let valid_on_this_ledger =
      Sequence.fold transactions_by_fee ~init:Sequence.empty ~f:(fun seq t ->
          match
            O1trace.measure "validate txn" (fun () ->
                Transaction_validator.apply_transaction validating_ledger
                  (User_command t) )
          with
          | Error e ->
              let error_message =
                sprintf
                  !"Invalid user command! Error was: %s, command was: \
                    $user_command"
                  (Error.to_string_hum e)
              in
              Logger.fatal logger ~module_:__MODULE__ ~location:__LOC__
                ~metadata:
                  [ ( "user_command"
                    , User_command.With_valid_signature.to_yojson t ) ]
                !"%s" error_message ;
              failwith error_message
          | Ok _ ->
              Sequence.append (Sequence.singleton t) seq )
    in
    let diff =
      O1trace.measure "generate diff" (fun () ->
          generate logger completed_works_seq valid_on_this_ledger self
            partitions )
    in
    Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
      "Number of proofs ready for purchase: $proof_count"
      ~metadata:[("proof_count", `Int proof_count)] ;
    trace_event "prediffs done" ;
    {Staged_ledger_diff.With_valid_signatures_and_proofs.diff; creator= self}

  module For_tests = struct
    let materialized_snarked_ledger_hash = materialized_snarked_ledger_hash
  end
end

include T

let%test_module "test" =
  ( module struct
    module Sl = T

    let self_pk =
      Quickcheck.random_value ~seed:(`Deterministic "self_pk")
        Public_key.Compressed.gen

    (* Functor for testing with different instantiated staged ledger modules. *)
    let create_and_apply sl logger pids txns stmt_to_work =
      let open Deferred.Let_syntax in
      let diff =
        Sl.create_diff !sl ~self:self_pk ~logger ~transactions_by_fee:txns
          ~get_completed_work:stmt_to_work
      in
      let diff' = Staged_ledger_diff.forget diff in
      let%bind verifier = Verifier.create ~logger ~pids in
      let%map ( `Hash_after_applying hash
              , `Ledger_proof ledger_proof
              , `Staged_ledger sl'
              , `Pending_coinbase_data _ ) =
        match%map Sl.apply !sl diff' ~logger ~verifier with
        | Ok x ->
            x
        | Error e ->
            Error.raise (Sl.Staged_ledger_error.to_error e)
      in
      assert (Staged_ledger_hash.equal hash (Sl.hash sl')) ;
      sl := sl' ;
      (ledger_proof, diff')

    (* Run the given function inside of the Deferred monad, with a staged
         ledger and a separate test ledger, after applying the given
         init_state to both. In the below tests we apply the same commands to
         the staged and test ledgers, and verify they are in the same state.
      *)
    let async_with_ledgers ledger_init_state
        (f : Sl.t ref -> Ledger.Mask.Attached.t -> unit Deferred.t) =
      Ledger.with_ephemeral_ledger ~f:(fun ledger ->
          Ledger.apply_initial_ledger_state ledger ledger_init_state ;
          let casted = Ledger.Any_ledger.cast (module Ledger) ledger in
          let test_mask =
            Ledger.Maskable.register_mask casted (Ledger.Mask.create ())
          in
          let sl = ref @@ Sl.create_exn ~ledger in
          Async.Thread_safe.block_on_async_exn (fun () -> f sl test_mask) ;
          ignore @@ Ledger.Maskable.unregister_mask_exn casted test_mask )

    (* Assert the given staged ledger is in the correct state after applying
         the first n user commands passed to the given base ledger. Checks the
         states of the proposer account and user accounts but ignores snark
         workers for simplicity. *)
    let assert_ledger :
           Ledger.t
        -> Sl.t
        -> User_command.With_valid_signature.t list
        -> int
        -> Public_key.Compressed.t list
        -> unit =
     fun test_ledger staged_ledger cmds_all cmds_used pks_to_check ->
      let old_proposer_balance =
        Option.value_map
          (Option.bind
             (Ledger.location_of_key test_ledger self_pk)
             ~f:(Ledger.get test_ledger))
          ~default:Currency.Balance.zero
          ~f:(fun a -> a.balance)
      in
      let rec apply_cmds =
        let open Or_error.Let_syntax in
        function
        | [] ->
            return ()
        | cmd :: cmds ->
            let%bind _ = Ledger.apply_user_command test_ledger cmd in
            apply_cmds cmds
      in
      Or_error.ok_exn @@ apply_cmds @@ List.take cmds_all cmds_used ;
      let get_account_exn ledger pk =
        Option.value_exn
          (Option.bind
             (Ledger.location_of_key ledger pk)
             ~f:(Ledger.get ledger))
      in
      (* Check the user accounts in the updated staged ledger are as
           expected. *)
      List.iter pks_to_check ~f:(fun pk ->
          let expect = get_account_exn test_ledger pk in
          let actual = get_account_exn (Sl.ledger staged_ledger) pk in
          [%test_result: Account.t] ~expect actual ) ;
      (* We only test that the proposer got any reward here, since calculating
         the exact correct amount depends on the snark fees and tx fees. *)
      let new_proposer_balance =
        (get_account_exn (Sl.ledger staged_ledger) self_pk).balance
      in
      assert (Currency.Balance.(new_proposer_balance > old_proposer_balance))

    (* Deterministically compute a prover public key from a snark work statement. *)
    let stmt_to_prover :
        Transaction_snark_work.Statement.t -> Public_key.Compressed.t =
     fun stmts ->
      let prover_seed =
        One_or_two.fold stmts ~init:"P" ~f:(fun p stmt ->
            p ^ Frozen_ledger_hash.to_bytes stmt.target )
      in
      Quickcheck.random_value ~seed:(`Deterministic prover_seed)
        Public_key.Compressed.gen

    let proofs stmts : Ledger_proof.t One_or_two.t =
      let sok_digest = Sok_message.Digest.default in
      One_or_two.map stmts ~f:(fun statement ->
          Ledger_proof.create ~statement ~sok_digest ~proof:Proof.dummy )

    let stmt_to_work_random_prover (stmts : Transaction_snark_work.Statement.t)
        : Transaction_snark_work.Checked.t option =
      let prover = stmt_to_prover stmts in
      let fee = Fee.of_int 1 in
      Some {Transaction_snark_work.Checked.fee; proofs= proofs stmts; prover}

    (* Fixed public key for when there is only one snark worker. *)
    let snark_worker_pk =
      Quickcheck.random_value ~seed:(`Deterministic "snark worker")
        Public_key.Compressed.gen

    let stmt_to_work_one_prover (stmts : Transaction_snark_work.Statement.t) :
        Transaction_snark_work.Checked.t option =
      let fee = Fee.of_int 1 in
      Some {fee; proofs= proofs stmts; prover= snark_worker_pk}

    let coinbase_fee_transfers_first_prediff = function
      | Staged_ledger_diff.At_most_two.Zero ->
          0
      | One _ ->
          1
      | _ ->
          2

    let coinbase_fee_transfers_second_prediff = function
      | Staged_ledger_diff.At_most_one.Zero ->
          0
      | _ ->
          1

    let coinbase_fee_transfers (sl_diff : Staged_ledger_diff.t) =
      coinbase_fee_transfers_first_prediff (fst sl_diff.diff).coinbase
      + Option.value_map ~default:0 (snd sl_diff.diff) ~f:(fun d ->
            coinbase_fee_transfers_second_prediff d.coinbase )

    (* These tests do a lot of updating Merkle ledgers so making Pedersen
       hashing faster is a big win.
    *)
    let () =
      Snark_params.set_chunked_hashing true ;
      Async.Scheduler.set_record_backtraces true ;
      Backtrace.elide := false

    (* The tests are still very slow, so we set ~trials very low for all the
       QuickCheck tests. We may be able to turn them up after #2759 and/or #2760
       happen.
    *)

    (* Get the public keys from a ledger init state. *)
    let init_pks
        (init :
          ( Signature_lib.Keypair.t
          * Currency.Amount.t
          * Coda_numbers.Account_nonce.t )
          array) =
      Array.to_sequence init
      |> Sequence.map ~f:(fun (kp, _, _) -> Public_key.compress kp.public_key)
      |> Sequence.to_list

    (* Fee excess at top level ledger proofs should always be zero *)
    let assert_fee_excess :
        (Ledger_proof.t * Transaction.t list) option -> unit =
     fun proof_opt ->
      let fee_excess =
        Option.value_map ~default:Fee.Signed.zero proof_opt ~f:(fun proof ->
            (Ledger_proof.statement (fst proof)).fee_excess )
      in
      assert (Fee.Signed.(equal fee_excess zero))

    let transaction_capacity =
      Int.pow 2
        Transaction_snark_scan_state.Constants.transaction_capacity_log_2

    (* Abstraction for the pattern of taking a list of commands and applying it
       in chunks up to a given max size. *)
    let rec iter_cmds_acc :
           User_command.With_valid_signature.t list
           (** All the commands to apply. *)
        -> int option list
           (** A list of chunk sizes. If a chunk's size is None, apply as many
            commands as possible. *)
        -> 'acc
        -> (   User_command.With_valid_signature.t list
               (** All commands remaining. *)
            -> int option (* Current chunk size. *)
            -> User_command.With_valid_signature.t Sequence.t
               (* Sequence of commands to apply. *)
            -> 'acc
            -> (Staged_ledger_diff.t * 'acc) Deferred.t)
        -> 'acc Deferred.t =
     fun cmds cmd_iters acc f ->
      match cmd_iters with
      | [] ->
          Deferred.return acc
      | count_opt :: counts_rest ->
          let cmds_this_iter_max =
            match count_opt with
            | None ->
                cmds
            | Some count ->
                assert (count <= List.length cmds) ;
                List.take cmds count
          in
          let%bind diff, acc' =
            f cmds count_opt (Sequence.of_list cmds_this_iter_max) acc
          in
          let cmds_applied_count =
            List.length @@ Staged_ledger_diff.user_commands diff
          in
          iter_cmds_acc (List.drop cmds cmds_applied_count) counts_rest acc' f

    (** Same as iter_cmds_acc but with no accumulator. *)
    let iter_cmds :
           User_command.With_valid_signature.t list
        -> int option list
        -> (   User_command.With_valid_signature.t list
            -> int option
            -> User_command.With_valid_signature.t Sequence.t
            -> Staged_ledger_diff.t Deferred.t)
        -> unit Deferred.t =
     fun cmds cmd_iters f ->
      iter_cmds_acc cmds cmd_iters ()
        (fun cmds_left count_opt cmds_this_iter () ->
          let%map diff = f cmds_left count_opt cmds_this_iter in
          (diff, ()) )

    (** Generic test framework. *)
    let test_simple :
           Ledger.init_state
        -> User_command.With_valid_signature.t list
        -> int option list
        -> Sl.t ref
        -> ?expected_proof_count:int (*Number of ledger proofs expected*)
        -> Ledger.Mask.Attached.t
        -> [`One_prover | `Many_provers]
        -> (   Transaction_snark_work.Statement.t
            -> Transaction_snark_work.Checked.t option)
        -> unit Deferred.t =
     fun init_state cmds cmd_iters sl ?(expected_proof_count = 0) test_mask
         provers stmt_to_work ->
      let logger = Logger.null () in
      let pids = Child_processes.Termination.create_pid_set () in
      let%map total_ledger_proofs =
        iter_cmds_acc cmds cmd_iters 0
          (fun cmds_left count_opt cmds_this_iter proof_count ->
            let%bind ledger_proof, diff =
              create_and_apply sl logger pids cmds_this_iter stmt_to_work
            in
            let proof_count' =
              proof_count + if Option.is_some ledger_proof then 1 else 0
            in
            assert_fee_excess ledger_proof ;
            let cmds_applied_this_iter =
              List.length @@ Staged_ledger_diff.user_commands diff
            in
            let cb = coinbase_fee_transfers diff in
            ( match provers with
            | `One_prover ->
                assert (cb = 1)
            | `Many_provers ->
                assert (cb > 0 && cb < 3) ) ;
            ( match count_opt with
            | Some _ ->
                (* There is an edge case where cmds_applied_this_iter = 0, when
               there is only enough space for coinbase transactions. *)
                assert (
                  cmds_applied_this_iter <= Sequence.length cmds_this_iter ) ;
                [%test_eq: User_command.t list]
                  (Staged_ledger_diff.user_commands diff)
                  ( Sequence.take cmds_this_iter cmds_applied_this_iter
                    |> Sequence.to_list
                    :> User_command.t list )
            | None ->
                () ) ;
            assert_ledger test_mask !sl cmds_left cmds_applied_this_iter
              (init_pks init_state) ;
            return (diff, proof_count') )
      in
      (*Should have enough blocks to generate at least expected_proof_count
      proofs*)
      assert (total_ledger_proofs >= expected_proof_count)

    (* We use first class modules to compute some derived constants that depend
       on the scan state constants. *)
    module type Constants_intf = sig
      val transaction_capacity_log_2 : int

      val work_delay : int
    end

    let min_blocks_before_first_snarked_ledger_generic
        (module C : Constants_intf) =
      let open C in
      (transaction_capacity_log_2 + 1) * (work_delay + 1)

    (* How many blocks to we need to produce to fully exercise the ledger
       behavior? min_blocks_before_first_snarked_ledger_generic + 1*)
    let max_blocks_for_coverage_generic (module C : Constants_intf) =
      min_blocks_before_first_snarked_ledger_generic (module C) + 1

    (* n extra blocks for n more ledger proofs *)
    let max_blocks_for_coverage n =
      max_blocks_for_coverage_generic
        (module Transaction_snark_scan_state.Constants)
      + n

    (** Generator for when we always have enough commands to fill all slots. *)
    let gen_at_capacity :
        ( Ledger.init_state
        * User_command.With_valid_signature.t list
        * int option list )
        Quickcheck.Generator.t =
      let open Quickcheck.Generator.Let_syntax in
      let%bind ledger_init_state = Ledger.gen_initial_ledger_state in
      let%bind iters = Int.gen_incl 1 (max_blocks_for_coverage 0) in
      let%bind cmds =
        User_command.With_valid_signature.Gen.sequence
          ~length:(transaction_capacity * iters)
          ~sign_type:`Real ledger_init_state
      in
      return (ledger_init_state, cmds, List.init iters ~f:(Fn.const None))

    (*Same as gen_at_capacity except that the number of iterations[iters] is
    the function of [extra_block_count] and is same for all generated values*)
    let gen_at_capacity_fixed_blocks extra_block_count :
        ( Ledger.init_state
        * User_command.With_valid_signature.t list
        * int option list )
        Quickcheck.Generator.t =
      let open Quickcheck.Generator.Let_syntax in
      let%bind ledger_init_state = Ledger.gen_initial_ledger_state in
      let iters = max_blocks_for_coverage extra_block_count in
      let%bind cmds =
        User_command.With_valid_signature.Gen.sequence
          ~length:(transaction_capacity * iters)
          ~sign_type:`Real ledger_init_state
      in
      return (ledger_init_state, cmds, List.init iters ~f:(Fn.const None))

    (* Generator for when we have less commands than needed to fill all slots. *)
    let gen_below_capacity ?(extra_blocks = false) () =
      let open Quickcheck.Generator.Let_syntax in
      let%bind ledger_init_state = Ledger.gen_initial_ledger_state in
      let iters_max =
        max_blocks_for_coverage 0 * if extra_blocks then 4 else 2
      in
      let%bind iters = Int.gen_incl 1 iters_max in
      (* N.B. user commands per block is much less than transactions per block
         due to fee transfers and coinbases, especially with worse case number
         of provers, so in order to exercise not filling the scan state
         completely we always apply <= 1/2 transaction_capacity commands.
      *)
      let%bind cmds_per_iter =
        Quickcheck.Generator.list_with_length iters
          (Int.gen_incl 1 ((transaction_capacity / 2) - 1))
      in
      let%bind cmds =
        User_command.With_valid_signature.Gen.sequence
          ~length:(List.sum (module Int) ~f:Fn.id cmds_per_iter)
          ~sign_type:`Real ledger_init_state
      in
      return (ledger_init_state, cmds, List.map ~f:Option.some cmds_per_iter)

    let%test_unit "Max throughput-ledger proof count-fixed blocks" =
      let expected_proof_count = 3 in
      Quickcheck.test (gen_at_capacity_fixed_blocks expected_proof_count)
        ~sexp_of:
          [%sexp_of:
            Ledger.init_state
            * Coda_base.User_command.With_valid_signature.t list
            * int option list] ~trials:10
        ~f:(fun (ledger_init_state, cmds, iters) ->
          async_with_ledgers ledger_init_state (fun sl test_mask ->
              test_simple ledger_init_state cmds iters sl ~expected_proof_count
                test_mask `Many_provers stmt_to_work_random_prover ) )

    let%test_unit "Max throughput" =
      Quickcheck.test gen_at_capacity
        ~sexp_of:
          [%sexp_of:
            Ledger.init_state
            * Coda_base.User_command.With_valid_signature.t list
            * int option list] ~trials:15
        ~f:(fun (ledger_init_state, cmds, iters) ->
          async_with_ledgers ledger_init_state (fun sl test_mask ->
              test_simple ledger_init_state cmds iters sl test_mask
                `Many_provers stmt_to_work_random_prover ) )

    let%test_unit "Be able to include random number of user_commands" =
      Quickcheck.test (gen_below_capacity ()) ~trials:20
        ~f:(fun (ledger_init_state, cmds, iters) ->
          async_with_ledgers ledger_init_state (fun sl test_mask ->
              test_simple ledger_init_state cmds iters sl test_mask
                `Many_provers stmt_to_work_random_prover ) )

    let%test_unit "Be able to include random number of user_commands (One \
                   prover)" =
      Quickcheck.test (gen_below_capacity ()) ~trials:20
        ~f:(fun (ledger_init_state, cmds, iters) ->
          async_with_ledgers ledger_init_state (fun sl test_mask ->
              test_simple ledger_init_state cmds iters sl test_mask `One_prover
                stmt_to_work_one_prover ) )

    let%test_unit "Invalid diff test: check zero fee excess for partitions" =
      let create_diff_with_non_zero_fee_excess txns completed_works
          (partition : Sl.Scan_state.Space_partition.t) : Staged_ledger_diff.t
          =
        (*With exact number of user commands in partition.first, the fee transfers that settle the fee_excess would be added to the next tree causing a non-zero fee excess*)
        let slots, job_count1 = partition.first in
        match partition.second with
        | None ->
            { diff=
                ( { completed_works= List.take completed_works job_count1
                  ; user_commands= List.take txns slots
                  ; coinbase= Zero }
                , None )
            ; creator= self_pk }
        | Some (_, _) ->
            let txns_in_second_diff = List.drop txns slots in
            let diff : Staged_ledger_diff.Diff.t =
              ( { completed_works= List.take completed_works job_count1
                ; user_commands= List.take txns slots
                ; coinbase= Zero }
              , Some
                  { completed_works=
                      ( if List.is_empty txns_in_second_diff then []
                      else List.drop completed_works job_count1 )
                  ; user_commands= txns_in_second_diff
                  ; coinbase= Zero } )
            in
            {diff; creator= self_pk}
      in
      let empty_diff : Staged_ledger_diff.t =
        { diff=
            ( { completed_works= []
              ; user_commands= []
              ; coinbase= Staged_ledger_diff.At_most_two.Zero }
            , None )
        ; creator= self_pk }
      in
      Quickcheck.test (gen_below_capacity ())
        ~sexp_of:
          [%sexp_of:
            Ledger.init_state
            * User_command.With_valid_signature.t list
            * int option list]
        ~shrinker:
          (Quickcheck.Shrinker.create (fun (init_state, cmds, iters) ->
               if List.length iters > 1 then
                 Sequence.singleton
                   ( init_state
                   , List.take cmds (List.length cmds - transaction_capacity)
                   , List.tl_exn iters )
               else Sequence.empty ))
        ~trials:10
        ~f:(fun (ledger_init_state, cmds, iters) ->
          async_with_ledgers ledger_init_state (fun sl _test_mask ->
              let logger = Logger.null () in
              let pids = Child_processes.Termination.create_pid_set () in
              let%map checked =
                iter_cmds_acc cmds iters true
                  (fun _cmds_left _count_opt cmds_this_iter checked ->
                    let scan_state = Sl.scan_state !sl in
                    let work =
                      Sl.Scan_state.work_statements_for_new_diff scan_state
                    in
                    let partitions =
                      Sl.Scan_state.partition_if_overflowing scan_state
                    in
                    let work_done =
                      List.map
                        ~f:(fun stmts ->
                          { Transaction_snark_work.Checked.fee= Fee.zero
                          ; proofs= proofs stmts
                          ; prover= snark_worker_pk } )
                        work
                    in
                    let diff =
                      create_diff_with_non_zero_fee_excess
                        (Sequence.to_list cmds_this_iter :> User_command.t list)
                        work_done partitions
                    in
                    let%bind verifier = Verifier.create ~logger ~pids in
                    let%bind apply_res = Sl.apply !sl diff ~logger ~verifier in
                    let checked', diff' =
                      match apply_res with
                      | Error (Sl.Staged_ledger_error.Non_zero_fee_excess _) ->
                          (true, empty_diff)
                      | Error err ->
                          failwith
                          @@ sprintf
                               !"Wrong error: %{sexp: Sl.Staged_ledger_error.t}"
                               err
                      | Ok
                          ( `Hash_after_applying _hash
                          , `Ledger_proof _ledger_proof
                          , `Staged_ledger sl'
                          , `Pending_coinbase_data _ ) ->
                          sl := sl' ;
                          (false, diff)
                    in
                    return (diff', checked || checked') )
              in
              (*Note: if this fails, try increasing the number of trials*)
              assert checked ) )

    let%test_unit "Snarked ledger" =
      let logger = Logger.null () in
      let pids = Child_processes.Termination.create_pid_set () in
      Quickcheck.test (gen_below_capacity ()) ~trials:20
        ~f:(fun (ledger_init_state, cmds, iters) ->
          async_with_ledgers ledger_init_state (fun sl _test_mask ->
              iter_cmds cmds iters (fun _cmds_left _count_opt cmds_this_iter ->
                  let%map proof_opt, diff =
                    create_and_apply sl logger pids cmds_this_iter
                      stmt_to_work_random_prover
                  in
                  ( match proof_opt with
                  | None ->
                      ()
                  | Some proof ->
                      let last_snarked_ledger_hash =
                        (Ledger_proof.statement (fst proof)).target
                      in
                      let materialized_snarked_ledger_hash =
                        Or_error.ok_exn
                        @@ Sl.For_tests.materialized_snarked_ledger_hash !sl
                             ~expected_target:last_snarked_ledger_hash
                      in
                      assert (
                        Frozen_ledger_hash.equal last_snarked_ledger_hash
                          materialized_snarked_ledger_hash ) ) ;
                  diff ) ) )

    let stmt_to_work_restricted work_list provers
        (stmts : Transaction_snark_work.Statement.t) :
        Transaction_snark_work.Checked.t option =
      let prover =
        match provers with
        | `Many_provers ->
            stmt_to_prover stmts
        | `One_prover ->
            snark_worker_pk
      in
      if
        Option.is_some
          (List.find work_list ~f:(fun s ->
               Transaction_snark_work.Statement.compare s stmts = 0 ))
      then
        let fee = Fee.of_int 1 in
        Some {Transaction_snark_work.Checked.fee; proofs= proofs stmts; prover}
      else None

    (** Like test_simple but with a random number of completed jobs available.
    *)
    let test_random_number_of_proofs :
           Ledger.init_state
        -> User_command.With_valid_signature.t list
        -> int option list
        -> int list
        -> Sl.t ref
        -> Ledger.Mask.Attached.t
        -> [`One_prover | `Many_provers]
        -> unit Deferred.t =
     fun init_state cmds cmd_iters proofs_available sl test_mask provers ->
      let logger = Logger.null () in
      let pids = Child_processes.Termination.create_pid_set () in
      let%map proofs_available_left =
        iter_cmds_acc cmds cmd_iters proofs_available
          (fun cmds_left _count_opt cmds_this_iter proofs_available_left ->
            let work_list : Transaction_snark_work.Statement.t list =
              let spec_list = Sl.all_work_pairs_exn !sl in
              List.map spec_list ~f:(fun specs ->
                  One_or_two.map specs
                    ~f:Snark_work_lib.Work.Single.Spec.statement )
            in
            let proofs_available_this_iter =
              List.hd_exn proofs_available_left
            in
            let%map proof, diff =
              create_and_apply sl logger pids cmds_this_iter
                (stmt_to_work_restricted
                   (List.take work_list proofs_available_this_iter)
                   provers)
            in
            assert_fee_excess proof ;
            let cmds_applied_this_iter =
              List.length @@ Staged_ledger_diff.user_commands diff
            in
            let cb = coinbase_fee_transfers diff in
            assert (proofs_available_this_iter = 0 || cb > 0) ;
            ( match provers with
            | `One_prover ->
                assert (cb <= 1)
            | `Many_provers ->
                assert (cb <= 2) ) ;
            assert_ledger test_mask !sl cmds_left cmds_applied_this_iter
              (init_pks init_state) ;
            (diff, List.tl_exn proofs_available_left) )
      in
      assert (List.is_empty proofs_available_left)

    let%test_unit "max throughput-random number of proofs-worst case provers" =
      (* Always at worst case number of provers *)
      let g =
        let open Quickcheck.Generator.Let_syntax in
        let%bind ledger_init_state, cmds, iters = gen_at_capacity in
        (* How many proofs will be available at each iteration. *)
        let%bind proofs_available =
          (* I think in the worst case every user command begets 1.5
             transactions - one for the command and half of one for a fee
             transfer - and the merge overhead means you need (amortized) twice
             as many SNARKs as transactions, but since a SNARK work usually
             covers two SNARKS it cancels. So we need to admit up to (1.5 * the
             number of commands) works. I make it twice as many for simplicity
             and to cover coinbases. *)
          Quickcheck_lib.map_gens iters ~f:(fun _ ->
              Int.gen_incl 0 (transaction_capacity * 2) )
        in
        return (ledger_init_state, cmds, iters, proofs_available)
      in
      Quickcheck.test g ~trials:10
        ~f:(fun (ledger_init_state, cmds, iters, proofs_available) ->
          async_with_ledgers ledger_init_state (fun sl test_mask ->
              test_random_number_of_proofs ledger_init_state cmds iters
                proofs_available sl test_mask `Many_provers ) )

    let%test_unit "random no of transactions-random number of proofs-worst \
                   case provers" =
      let g =
        let open Quickcheck.Generator.Let_syntax in
        let%bind ledger_init_state, cmds, iters =
          gen_below_capacity ~extra_blocks:true ()
        in
        let%bind proofs_available =
          Quickcheck_lib.map_gens iters ~f:(fun cmds_opt ->
              Int.gen_incl 0 (3 * Option.value_exn cmds_opt) )
        in
        return (ledger_init_state, cmds, iters, proofs_available)
      in
      let shrinker =
        Quickcheck.Shrinker.create
          (fun (ledger_init_state, cmds, iters, proofs_available) ->
            let all_but_last xs = List.take xs (List.length xs - 1) in
            let iter_count = List.length iters in
            let mod_iters iters' =
              ( ledger_init_state
              , List.take cmds
                @@ List.sum (module Int) iters' ~f:(Option.value ~default:0)
              , iters'
              , List.take proofs_available (List.length iters') )
            in
            let half_iters =
              if iter_count > 1 then
                Some (mod_iters (List.take iters (iter_count / 2)))
              else None
            in
            let one_less_iters =
              if iter_count > 2 then Some (mod_iters (all_but_last iters))
              else None
            in
            List.filter_map [half_iters; one_less_iters] ~f:Fn.id
            |> Sequence.of_list )
      in
      Quickcheck.test g ~shrinker ~shrink_attempts:`Exhaustive
        ~sexp_of:
          [%sexp_of:
            Ledger.init_state
            * User_command.With_valid_signature.t list
            * int option list
            * int list] ~trials:50
        ~f:(fun (ledger_init_state, cmds, iters, proofs_available) ->
          async_with_ledgers ledger_init_state (fun sl test_mask ->
              test_random_number_of_proofs ledger_init_state cmds iters
                proofs_available sl test_mask `Many_provers ) )

    let%test_unit "Random number of user_commands-random number of proofs-one \
                   prover)" =
      let g =
        let open Quickcheck.Generator.Let_syntax in
        let%bind ledger_init_state, cmds, iters =
          gen_below_capacity ~extra_blocks:true ()
        in
        let%bind proofs_available =
          Quickcheck_lib.map_gens iters ~f:(fun cmds_opt ->
              Int.gen_incl 0 (3 * Option.value_exn cmds_opt) )
        in
        return (ledger_init_state, cmds, iters, proofs_available)
      in
      Quickcheck.test g ~trials:10
        ~f:(fun (ledger_init_state, cmds, iters, proofs_available) ->
          async_with_ledgers ledger_init_state (fun sl test_mask ->
              test_random_number_of_proofs ledger_init_state cmds iters
                proofs_available sl test_mask `One_prover ) )
  end )
