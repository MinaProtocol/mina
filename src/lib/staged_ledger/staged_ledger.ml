[%%import "/src/config.mlh"]

(* Only show stdout for failed inline tests. *)
open Inline_test_quiet_logs
open Core_kernel
open Async
open Mina_base
open Mina_transaction
open Currency
open Signature_lib
module Ledger = Mina_ledger.Ledger
module Sparse_ledger = Mina_ledger.Sparse_ledger

(* TODO: measure these operations and tune accordingly *)
let transaction_application_scheduler_batch_size = 10

let option lab =
  Option.value_map ~default:(Or_error.error_string lab) ~f:(fun x -> Ok x)

let yield_result = Fn.compose (Deferred.map ~f:Result.return) Scheduler.yield

let yield_result_every ~n =
  Fn.compose
    (Deferred.map ~f:Result.return)
    (Staged.unstage @@ Scheduler.yield_every ~n)

module Pre_statement = struct
  type t =
    { partially_applied_transaction : Ledger.Transaction_partially_applied.t
    ; expected_status : Transaction_status.t
    ; accounts_accessed : Account_id.t list
    ; fee_excess : Fee_excess.t
    ; first_pass_ledger_witness : Sparse_ledger.t
    ; first_pass_ledger_source_hash : Ledger_hash.t
    ; first_pass_ledger_target_hash : Ledger_hash.t
    ; pending_coinbase_stack_source : Pending_coinbase.Stack_versioned.t
    ; pending_coinbase_stack_target : Pending_coinbase.Stack_versioned.t
    ; init_stack : Transaction_snark.Pending_coinbase_stack_state.Init_stack.t
    }
end

module T = struct
  module Scan_state = Transaction_snark_scan_state
  module Pre_diff_info = Pre_diff_info

  module Staged_ledger_error = struct
    type t =
      | Non_zero_fee_excess of
          Scan_state.Space_partition.t * Transaction.t With_status.t list
      | Invalid_proofs of
          ( Ledger_proof.t
          * Transaction_snark.Statement.t
          * Mina_base.Sok_message.t )
          list
          * Error.t
      | Couldn't_reach_verifier of Error.t
      | Pre_diff of Pre_diff_info.Error.t
      | Insufficient_work of string
      | Mismatched_statuses of
          Transaction.t With_status.t * Transaction_status.t
      | Invalid_public_key of Public_key.Compressed.t
      | Unexpected of Error.t
    [@@deriving sexp]

    let to_string = function
      | Couldn't_reach_verifier e ->
          Format.asprintf
            !"The verifier could not be reached: %{sexp:Error.t}"
            e
      | Non_zero_fee_excess (partition, txns) ->
          Format.asprintf
            !"Fee excess is non-zero for the transactions: %{sexp: \
              Transaction.t With_status.t list} and the current queue with \
              slots partitioned as %{sexp: Scan_state.Space_partition.t} \n"
            txns partition
      | Pre_diff pre_diff_error ->
          Format.asprintf
            !"Pre_diff_info.Error error: %{sexp:Pre_diff_info.Error.t}"
            pre_diff_error
      | Invalid_proofs (ts, err) ->
          Format.asprintf
            !"Verification failed for proofs with (statement, work_id, \
              prover): %{sexp: (Transaction_snark.Statement.t * int * string) \
              list}\n\
              Error:\n\
              %s"
            (List.map ts ~f:(fun (_p, s, m) ->
                 ( s
                 , Transaction_snark.Statement.hash s
                 , Yojson.Safe.to_string
                   @@ Public_key.Compressed.to_yojson m.prover ) ) )
            (Yojson.Safe.pretty_to_string (Error_json.error_to_yojson err))
      | Insufficient_work str ->
          str
      | Mismatched_statuses (transaction, status) ->
          Format.asprintf
            !"Got a different status %{sexp: Transaction_status.t} when \
              applying the transaction %{sexp: Transaction.t With_status.t}"
            status transaction
      | Invalid_public_key pk ->
          Format.asprintf
            !"A transaction contained an invalid public key %{sexp: \
              Public_key.Compressed.t}"
            pk
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

  let verify_proofs ~logger ~verifier proofs =
    let statements () =
      `List
        (List.map proofs ~f:(fun (_, s, _) ->
             Transaction_snark.Statement.to_yojson s ) )
    in
    let log_error err_str ~metadata =
      [%log warn]
        ~metadata:
          ( [ ("statements", statements ())
            ; ("error", `String err_str)
            ; ( "sok_messages"
              , `List
                  (List.map proofs ~f:(fun (_, _, m) -> Sok_message.to_yojson m))
              )
            ]
          @ metadata )
        "Invalid transaction snark for statement $statement: $error" ;
      Deferred.return (Or_error.error_string err_str)
    in
    if
      List.exists proofs ~f:(fun (proof, statement, _msg) ->
          not
            (Transaction_snark.Statement.equal
               (Ledger_proof.statement proof)
               statement ) )
    then
      log_error "Statement and proof do not match"
        ~metadata:
          [ ( "statements_from_proof"
            , `List
                (List.map proofs ~f:(fun (p, _, _) ->
                     Transaction_snark.Statement.to_yojson
                       (Ledger_proof.statement p) ) ) )
          ]
    else
      let start = Time.now () in
      match%map
        Verifier.verify_transaction_snarks verifier
          (List.map proofs ~f:(fun (proof, _, msg) -> (proof, msg)))
      with
      | Ok b ->
          let time_ms = Time.abs_diff (Time.now ()) start |> Time.Span.to_ms in
          [%log trace]
            ~metadata:
              [ ( "work_id"
                , `List
                    (List.map proofs ~f:(fun (_, s, _) ->
                         `Int (Transaction_snark.Statement.hash s) ) ) )
              ; ("time", `Float time_ms)
              ]
            "Verification in apply_diff for work $work_id took $time ms" ;
          Ok b
      | Error e ->
          [%log fatal]
            ~metadata:
              [ ( "statement"
                , `List
                    (List.map proofs ~f:(fun (_, s, _) ->
                         Transaction_snark.Statement.to_yojson s ) ) )
              ; ("error", Error_json.error_to_yojson e)
              ]
            "Verifier error when checking transaction snark for statement \
             $statement: $error" ;
          Error e

  let map_opt xs ~f =
    with_return (fun { return } ->
        Some
          (List.map xs ~f:(fun x ->
               match f x with Some y -> y | None -> return None ) ) )

  let verify ~logger ~verifier job_msg_proofs =
    let open Deferred.Let_syntax in
    match
      map_opt job_msg_proofs ~f:(fun (job, msg, proof) ->
          Option.map (Scan_state.statement_of_job job) ~f:(fun s ->
              (proof, s, msg) ) )
    with
    | None ->
        Deferred.return
          ( Or_error.errorf
              !"Error creating statement from job %{sexp:job list}"
              (List.map job_msg_proofs ~f:(fun (j, _, _) -> j))
          |> to_staged_ledger_or_error )
    | Some proof_statement_msgs -> (
        match%map verify_proofs ~logger ~verifier proof_statement_msgs with
        | Ok (Ok ()) ->
            Ok ()
        | Ok (Error err) ->
            Error
              (Staged_ledger_error.Invalid_proofs (proof_statement_msgs, err))
        | Error e ->
            Error (Couldn't_reach_verifier e) )

  module Statement_scanner = struct
    include Scan_state.Make_statement_scanner (struct
      type t = unit

      let verify ~verifier:() _proofs = Deferred.Or_error.return (Ok ())
    end)
  end

  module Statement_scanner_proof_verifier = struct
    type t = { logger : Logger.t; verifier : Verifier.t }

    let verify ~verifier:{ logger; verifier } ts =
      verify_proofs ~logger ~verifier
        (List.map ts ~f:(fun (p, m) -> (p, Ledger_proof.statement p, m)))
  end

  module Statement_scanner_with_proofs =
    Scan_state.Make_statement_scanner (Statement_scanner_proof_verifier)

  type t =
    { scan_state : Scan_state.t
    ; ledger :
        ((* Invariant: this is the ledger after having applied all the
             transactions in the above state. *)
         Ledger.attached_mask
        [@sexp.opaque] )
    ; constraint_constants : Genesis_constants.Constraint_constants.t
    ; pending_coinbase_collection : Pending_coinbase.t
    }
  [@@deriving sexp]

  let proof_txns_with_state_hashes t =
    Scan_state.latest_ledger_proof t.scan_state
    |> Option.bind ~f:(Fn.compose Mina_stdlib.Nonempty_list.of_list_opt snd)

  let scan_state { scan_state; _ } = scan_state

  let all_work_pairs t
      ~(get_state : State_hash.t -> Mina_state.Protocol_state.value Or_error.t)
      =
    Scan_state.all_work_pairs t.scan_state ~get_state

  let all_work_statements_exn t =
    Scan_state.all_work_statements_exn t.scan_state

  let pending_coinbase_collection { pending_coinbase_collection; _ } =
    pending_coinbase_collection

  let _get_target ((proof, _), _) =
    let { Transaction_snark.Statement.Poly.target; _ } =
      Ledger_proof.statement proof
    in
    target

  let verify_scan_state_after_apply ~constraint_constants
      ~pending_coinbase_stack ~first_pass_ledger_end ~second_pass_ledger_end
      (scan_state : Scan_state.t) =
    let error_prefix =
      "Error verifying the parallel scan state after applying the diff."
    in
    let registers_end : _ Mina_state.Registers.t =
      { first_pass_ledger = first_pass_ledger_end
      ; second_pass_ledger = second_pass_ledger_end
      ; local_state = Mina_state.Local_state.empty ()
      ; pending_coinbase_stack
      }
    in
    let statement_check = `Partial in
    let last_proof_statement =
      Option.map
        ~f:(fun ((p, _), _) -> Ledger_proof.statement p)
        (Scan_state.latest_ledger_proof scan_state)
    in
    Statement_scanner.check_invariants ~constraint_constants scan_state
      ~statement_check ~verifier:() ~error_prefix ~registers_end
      ~last_proof_statement

  let of_scan_state_and_ledger_unchecked ~ledger ~scan_state
      ~constraint_constants ~pending_coinbase_collection =
    { ledger; scan_state; constraint_constants; pending_coinbase_collection }

  let of_scan_state_and_ledger ~logger
      ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ~verifier ~last_proof_statement ~ledger ~scan_state
      ~pending_coinbase_collection ~get_state ~first_pass_ledger_target =
    let open Deferred.Or_error.Let_syntax in
    let t =
      of_scan_state_and_ledger_unchecked ~ledger ~scan_state
        ~constraint_constants ~pending_coinbase_collection
    in
    let%bind pending_coinbase_stack =
      Pending_coinbase.latest_stack ~is_new_stack:false
        pending_coinbase_collection
      |> Deferred.return
    in
    let%bind () =
      Statement_scanner_with_proofs.check_invariants ~constraint_constants
        scan_state ~statement_check:(`Full get_state)
        ~verifier:{ Statement_scanner_proof_verifier.logger; verifier }
        ~error_prefix:"Staged_ledger.of_scan_state_and_ledger"
        ~last_proof_statement
        ~registers_end:
          { local_state = Mina_state.Local_state.empty ()
          ; first_pass_ledger = first_pass_ledger_target
          ; second_pass_ledger =
              Frozen_ledger_hash.of_ledger_hash (Ledger.merkle_root ledger)
          ; pending_coinbase_stack
          }
    in
    return t

  let of_scan_state_and_ledger_unchecked
      ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ~last_proof_statement ~ledger ~scan_state ~pending_coinbase_collection
      ~first_pass_ledger_target =
    let open Deferred.Or_error.Let_syntax in
    let t =
      { ledger; scan_state; constraint_constants; pending_coinbase_collection }
    in
    let%bind pending_coinbase_stack =
      Pending_coinbase.latest_stack ~is_new_stack:false
        pending_coinbase_collection
      |> Deferred.return
    in
    let%bind () =
      Statement_scanner.check_invariants ~constraint_constants scan_state
        ~statement_check:`Partial ~verifier:()
        ~error_prefix:"Staged_ledger.of_scan_state_and_ledger"
        ~last_proof_statement
        ~registers_end:
          { local_state = Mina_state.Local_state.empty ()
          ; first_pass_ledger = first_pass_ledger_target
          ; second_pass_ledger =
              Frozen_ledger_hash.of_ledger_hash (Ledger.merkle_root ledger)
          ; pending_coinbase_stack
          }
    in
    return t

  let of_scan_state_pending_coinbases_and_snarked_ledger' ~constraint_constants
      ~pending_coinbases ~scan_state ~snarked_ledger ~snarked_local_state:_
      ~expected_merkle_root ~get_state f =
    let open Deferred.Or_error.Let_syntax in
    let apply_first_pass =
      Ledger.apply_transaction_first_pass ~constraint_constants
    in
    let apply_second_pass = Ledger.apply_transaction_second_pass in
    let apply_first_pass_sparse_ledger ~global_slot ~txn_state_view
        sparse_ledger txn =
      let open Or_error.Let_syntax in
      let%map _ledger, partial_txn =
        Mina_ledger.Sparse_ledger.apply_transaction_first_pass
          ~constraint_constants ~global_slot ~txn_state_view sparse_ledger txn
      in
      partial_txn
    in
    let%bind (`First_pass_ledger_hash first_pass_ledger_target) =
      Scan_state.get_staged_ledger_async
        ~async_batch_size:transaction_application_scheduler_batch_size
        ~ledger:snarked_ledger ~get_protocol_state:get_state ~apply_first_pass
        ~apply_second_pass ~apply_first_pass_sparse_ledger scan_state
    in
    let staged_ledger_hash = Ledger.merkle_root snarked_ledger in
    let%bind () =
      Deferred.return
      @@ Result.ok_if_true
           (Ledger_hash.equal expected_merkle_root staged_ledger_hash)
           ~error:
             (Error.createf
                !"Mismatching merkle root Expected:%{sexp:Ledger_hash.t} \
                  Got:%{sexp:Ledger_hash.t}"
                expected_merkle_root staged_ledger_hash )
    in
    let last_proof_statement =
      Scan_state.latest_ledger_proof scan_state
      |> Option.map ~f:(fun ((p, _), _) -> Ledger_proof.statement p)
    in
    f ~constraint_constants ~last_proof_statement ~ledger:snarked_ledger
      ~scan_state ~pending_coinbase_collection:pending_coinbases
      ~first_pass_ledger_target

  let of_scan_state_pending_coinbases_and_snarked_ledger ~logger
      ~constraint_constants ~verifier ~scan_state ~snarked_ledger
      ~snarked_local_state ~expected_merkle_root ~pending_coinbases ~get_state =
    of_scan_state_pending_coinbases_and_snarked_ledger' ~constraint_constants
      ~pending_coinbases ~scan_state ~snarked_ledger ~snarked_local_state
      ~expected_merkle_root ~get_state
      (of_scan_state_and_ledger ~logger ~get_state ~verifier)

  let of_scan_state_pending_coinbases_and_snarked_ledger_unchecked
      ~constraint_constants ~scan_state ~snarked_ledger ~snarked_local_state
      ~expected_merkle_root ~pending_coinbases ~get_state =
    of_scan_state_pending_coinbases_and_snarked_ledger' ~constraint_constants
      ~pending_coinbases ~scan_state ~snarked_ledger ~snarked_local_state
      ~expected_merkle_root ~get_state of_scan_state_and_ledger_unchecked

  let copy
      { scan_state; ledger; constraint_constants; pending_coinbase_collection }
      =
    let new_mask = Ledger.Mask.create ~depth:(Ledger.depth ledger) () in
    { scan_state
    ; ledger = Ledger.register_mask ledger new_mask
    ; constraint_constants
    ; pending_coinbase_collection
    }

  let hash
      { scan_state
      ; ledger
      ; constraint_constants = _
      ; pending_coinbase_collection
      } : Staged_ledger_hash.t =
    Staged_ledger_hash.of_aux_ledger_and_coinbase_hash
      (Scan_state.hash scan_state)
      (Ledger.merkle_root ledger)
      pending_coinbase_collection

  [%%if call_logger]

  let hash t =
    Mina_debug.Call_logger.record_call "Staged_ledger.hash" ;
    hash t

  [%%endif]

  let ledger { ledger; _ } = ledger

  let create_exn ~constraint_constants ~ledger : t =
    { scan_state = Scan_state.empty ~constraint_constants ()
    ; ledger
    ; constraint_constants
    ; pending_coinbase_collection =
        Pending_coinbase.create
          ~depth:constraint_constants.pending_coinbase_depth ()
        |> Or_error.ok_exn
    }

  let current_ledger_proof t =
    Option.map
      (Scan_state.latest_ledger_proof t.scan_state)
      ~f:(Fn.compose fst fst)

  let replace_ledger_exn t ledger =
    [%test_result: Ledger_hash.t]
      ~message:"Cannot replace ledger since merkle_root differs"
      ~expect:(Ledger.merkle_root t.ledger)
      (Ledger.merkle_root ledger) ;
    { t with ledger }

  let sum_fees xs ~f =
    with_return (fun { return } ->
        Ok
          (List.fold ~init:Fee.zero xs ~f:(fun acc x ->
               match Fee.add acc (f x) with
               | None ->
                   return (Or_error.error_string "Fee overflow")
               | Some res ->
                   res ) ) )

  let working_stack pending_coinbase_collection ~is_new_stack =
    to_staged_ledger_or_error
      (Pending_coinbase.latest_stack pending_coinbase_collection ~is_new_stack)

  let push_coinbase current_stack (t : Transaction.t) =
    match t with
    | Coinbase c ->
        Pending_coinbase.Stack.push_coinbase c current_stack
    | _ ->
        current_stack

  let push_state current_stack state_body_hash global_slot =
    Pending_coinbase.Stack.push_state state_body_hash global_slot current_stack

  module Stack_state_with_init_stack = struct
    type t =
      { pc : Transaction_snark.Pending_coinbase_stack_state.t
      ; init_stack : Pending_coinbase.Stack.t
      }
  end

  let coinbase_amount ~supercharge_coinbase
      ~(constraint_constants : Genesis_constants.Constraint_constants.t) =
    if supercharge_coinbase then
      Currency.Amount.scale constraint_constants.coinbase_amount
        constraint_constants.supercharged_coinbase_factor
    else Some constraint_constants.coinbase_amount

  let _coinbase_amount_or_error ~supercharge_coinbase
      ~(constraint_constants : Genesis_constants.Constraint_constants.t) =
    if supercharge_coinbase then
      Option.value_map
        ~default:
          (Error
             (Pre_diff_info.Error.Coinbase_error
                (sprintf
                   !"Overflow when calculating coinbase amount: Supercharged \
                     coinbase factor (%d) x coinbase amount (%{sexp: \
                     Currency.Amount.t})"
                   constraint_constants.supercharged_coinbase_factor
                   constraint_constants.coinbase_amount ) ) )
        (coinbase_amount ~supercharge_coinbase ~constraint_constants)
        ~f:(fun x -> Ok x)
    else Ok constraint_constants.coinbase_amount

  let apply_single_transaction_first_pass ~constraint_constants ~global_slot
      ledger (pending_coinbase_stack_state : Stack_state_with_init_stack.t)
      txn_with_status (txn_state_view : Zkapp_precondition.Protocol_state.View.t)
      :
      ( Pre_statement.t * Stack_state_with_init_stack.t
      , Staged_ledger_error.t )
      Result.t =
    let open Result.Let_syntax in
    let txn = With_status.data txn_with_status in
    let expected_status = With_status.status txn_with_status in
    (* TODO: for zkapps, we should actually narrow this by segments *)
    let accounts_accessed = Transaction.accounts_referenced txn in
    let%bind fee_excess =
      to_staged_ledger_or_error (Transaction.fee_excess txn)
    in
    let source_ledger_hash = Ledger.merkle_root ledger in
    let ledger_witness =
      O1trace.sync_thread "create_ledger_witness" (fun () ->
          Sparse_ledger.of_ledger_subset_exn ledger accounts_accessed )
    in
    let pending_coinbase_target =
      push_coinbase pending_coinbase_stack_state.pc.target txn
    in
    let new_init_stack =
      push_coinbase pending_coinbase_stack_state.init_stack txn
    in
    let%map partially_applied_transaction =
      to_staged_ledger_or_error
        (Ledger.apply_transaction_first_pass ~constraint_constants ~global_slot
           ~txn_state_view ledger txn )
    in
    let target_ledger_hash = Ledger.merkle_root ledger in
    ( { Pre_statement.partially_applied_transaction
      ; expected_status
      ; accounts_accessed
      ; fee_excess
      ; first_pass_ledger_witness = ledger_witness
      ; first_pass_ledger_source_hash = source_ledger_hash
      ; first_pass_ledger_target_hash = target_ledger_hash
      ; pending_coinbase_stack_source = pending_coinbase_stack_state.pc.source
      ; pending_coinbase_stack_target = pending_coinbase_target
      ; init_stack =
          Transaction_snark.Pending_coinbase_stack_state.Init_stack.Base
            pending_coinbase_stack_state.init_stack
      }
    , { Stack_state_with_init_stack.pc =
          { source = pending_coinbase_target; target = pending_coinbase_target }
      ; init_stack = new_init_stack
      } )

  let apply_single_transaction_second_pass ~connecting_ledger ledger
      state_and_body_hash ~global_slot (pre_stmt : Pre_statement.t) =
    let open Result.Let_syntax in
    let empty_local_state = Mina_state.Local_state.empty () in
    let second_pass_ledger_source_hash = Ledger.merkle_root ledger in
    let ledger_witness =
      O1trace.sync_thread "create_ledger_witness" (fun () ->
          (* TODO: for zkapps, we should actually narrow this by segments *)
          Sparse_ledger.of_ledger_subset_exn ledger pre_stmt.accounts_accessed )
    in
    let%bind applied_txn =
      to_staged_ledger_or_error
        (Ledger.apply_transaction_second_pass ledger
           pre_stmt.partially_applied_transaction )
    in
    let second_pass_ledger_target_hash = Ledger.merkle_root ledger in
    let%bind supply_increase =
      to_staged_ledger_or_error
        (Ledger.Transaction_applied.supply_increase applied_txn)
    in
    let%map () =
      let actual_status =
        Ledger.Transaction_applied.transaction_status applied_txn
      in
      if Transaction_status.equal pre_stmt.expected_status actual_status then
        return ()
      else
        let txn_with_expected_status =
          { With_status.data =
              With_status.data
                (Ledger.Transaction_applied.transaction applied_txn)
          ; status = pre_stmt.expected_status
          }
        in
        Error
          (Staged_ledger_error.Mismatched_statuses
             (txn_with_expected_status, actual_status) )
    in
    let statement =
      { Mina_wire_types.Mina_state_snarked_ledger_state.Poly.V2.source =
          { first_pass_ledger = pre_stmt.first_pass_ledger_source_hash
          ; second_pass_ledger = second_pass_ledger_source_hash
          ; pending_coinbase_stack = pre_stmt.pending_coinbase_stack_source
          ; local_state = empty_local_state
          }
      ; target =
          { first_pass_ledger = pre_stmt.first_pass_ledger_target_hash
          ; second_pass_ledger = second_pass_ledger_target_hash
          ; pending_coinbase_stack = pre_stmt.pending_coinbase_stack_target
          ; local_state = empty_local_state
          }
      ; connecting_ledger_left = connecting_ledger
      ; connecting_ledger_right = connecting_ledger
      ; fee_excess = pre_stmt.fee_excess
      ; supply_increase
      ; sok_digest = ()
      }
    in
    { Scan_state.Transaction_with_witness.transaction_with_info = applied_txn
    ; state_hash = state_and_body_hash
    ; first_pass_ledger_witness = pre_stmt.first_pass_ledger_witness
    ; second_pass_ledger_witness = ledger_witness
    ; init_stack = pre_stmt.init_stack
    ; statement
    ; block_global_slot = global_slot
    }

  let apply_transactions_first_pass ~yield ~constraint_constants ~global_slot
      ledger init_pending_coinbase_stack_state ts current_state_view =
    let open Deferred.Result.Let_syntax in
    let apply pending_coinbase_stack_state txn =
      match
        List.find (Transaction.public_keys txn.With_status.data) ~f:(fun pk ->
            Option.is_none (Signature_lib.Public_key.decompress pk) )
      with
      | Some pk ->
          Error (Staged_ledger_error.Invalid_public_key pk)
      | None ->
          apply_single_transaction_first_pass ~constraint_constants ~global_slot
            ledger pending_coinbase_stack_state txn current_state_view
    in
    let%map res_rev, pending_coinbase_stack_state =
      Mina_stdlib.Deferred.Result.List.fold ts
        ~init:([], init_pending_coinbase_stack_state)
        ~f:(fun (acc, pending_coinbase_stack_state) t ->
          let%bind pre_witness, pending_coinbase_stack_state' =
            Deferred.return (apply pending_coinbase_stack_state t)
          in
          let%map () = yield () in
          (pre_witness :: acc, pending_coinbase_stack_state') )
    in
    (List.rev res_rev, pending_coinbase_stack_state.pc.target)

  let apply_transactions_second_pass ~yield ~global_slot ledger
      state_and_body_hash pre_stmts =
    let open Deferred.Result.Let_syntax in
    let connecting_ledger = Ledger.merkle_root ledger in
    Mina_stdlib.Deferred.Result.List.map pre_stmts ~f:(fun pre_stmt ->
        let%bind result =
          apply_single_transaction_second_pass ~connecting_ledger ~global_slot
            ledger state_and_body_hash pre_stmt
          |> Deferred.return
        in
        let%map () = yield () in
        result )

  let update_ledger_and_get_statements ~constraint_constants ~global_slot ledger
      current_stack tss current_state_view state_and_body_hash =
    let open Deferred.Result.Let_syntax in
    let state_body_hash = snd state_and_body_hash in
    let ts, ts_opt = tss in
    let apply_first_pass working_stack ts =
      let working_stack_with_state =
        push_state working_stack state_body_hash global_slot
      in
      let init_pending_coinbase_stack_state : Stack_state_with_init_stack.t =
        { pc = { source = working_stack; target = working_stack_with_state }
        ; init_stack = working_stack
        }
      in
      apply_transactions_first_pass ~constraint_constants ~global_slot ledger
        init_pending_coinbase_stack_state ts current_state_view
    in
    let yield =
      yield_result_every ~n:transaction_application_scheduler_batch_size
    in
    let%bind pre_stmts1, updated_stack1 =
      apply_first_pass ~yield current_stack ts
    in
    let%bind pre_stmts2, updated_stack2 =
      match ts_opt with
      | None ->
          return ([], updated_stack1)
      | Some ts ->
          let current_stack2 =
            Pending_coinbase.Stack.create_with current_stack
          in
          apply_first_pass ~yield current_stack2 ts
    in
    let first_pass_ledger_end = Ledger.merkle_root ledger in
    let%map txns_with_witnesses =
      apply_transactions_second_pass ~yield ~global_slot ledger
        state_and_body_hash (pre_stmts1 @ pre_stmts2)
    in
    (txns_with_witnesses, updated_stack1, updated_stack2, first_pass_ledger_end)

  let check_completed_works ~logger ~verifier scan_state
      (completed_works : Transaction_snark_work.t list) =
    let work_count = List.length completed_works in
    let job_pairs =
      Scan_state.k_work_pairs_for_new_diff scan_state ~k:work_count
    in
    let jmps =
      List.concat_map (List.zip_exn job_pairs completed_works)
        ~f:(fun (jobs, work) ->
          let message = Sok_message.create ~fee:work.fee ~prover:work.prover in
          One_or_two.(
            to_list
              (map (zip_exn jobs work.proofs) ~f:(fun (job, proof) ->
                   (job, message, proof) ) )) )
    in
    verify jmps ~logger ~verifier

  (**The total fee excess caused by any diff should be zero. In the case where
     the slots are split into two partitions, total fee excess of the transactions
     to be enqueued on each of the partitions should be zero respectively *)
  let check_zero_fee_excess scan_state data =
    let partitions = Scan_state.partition_if_overflowing scan_state in
    let txns_from_data data =
      List.fold_right ~init:(Ok []) data
        ~f:(fun (d : Scan_state.Transaction_with_witness.t) acc ->
          let open Or_error.Let_syntax in
          let%map acc = acc in
          let t =
            d.transaction_with_info |> Ledger.Transaction_applied.transaction
          in
          t :: acc )
    in
    let total_fee_excess txns =
      List.fold_until txns ~init:Fee_excess.empty ~finish:Or_error.return
        ~f:(fun acc (txn : Transaction.t With_status.t) ->
          match
            let open Or_error.Let_syntax in
            let%bind fee_excess = Transaction.fee_excess txn.data in
            Fee_excess.combine acc fee_excess
          with
          | Ok fee_excess ->
              Continue fee_excess
          | Error _ as err ->
              Stop err )
      |> to_staged_ledger_or_error
    in
    let open Result.Let_syntax in
    let check data slots =
      let%bind txns = txns_from_data data |> to_staged_ledger_or_error in
      let%bind fee_excess = total_fee_excess txns in
      if Fee_excess.is_zero fee_excess then Ok ()
      else Error (Non_zero_fee_excess (slots, txns))
    in
    let%bind () = check (List.take data (fst partitions.first)) partitions in
    Option.value_map ~default:(Result.return ())
      ~f:(fun _ -> check (List.drop data (fst partitions.first)) partitions)
      partitions.second

  let update_coinbase_stack_and_get_data ~logger ~constraint_constants
      ~global_slot scan_state ledger pending_coinbase_collection transactions
      current_state_view state_and_body_hash =
    let open Deferred.Result.Let_syntax in
    let coinbase_exists txns =
      List.fold_until ~init:false txns
        ~f:(fun acc t ->
          match t.With_status.data with
          | Transaction.Coinbase _ ->
              Stop true
          | _ ->
              Continue acc )
        ~finish:Fn.id
    in
    let { Scan_state.Space_partition.first = slots, _; second } =
      Scan_state.partition_if_overflowing scan_state
    in
    if not @@ List.is_empty transactions then (
      match second with
      | None ->
          (*Single partition:
            1.Check if a new stack is required and get a working stack [working_stack]
            2.create data for enqueuing onto the scan state *)
          let is_new_stack = Scan_state.next_on_new_tree scan_state in
          let%bind working_stack =
            working_stack pending_coinbase_collection ~is_new_stack
            |> Deferred.return
          in
          [%log internal] "Update_ledger_and_get_statements"
            ~metadata:[ ("partition", `String "single") ] ;
          let%map data, updated_stack, _, first_pass_ledger_end =
            update_ledger_and_get_statements ~constraint_constants ~global_slot
              ledger working_stack (transactions, None) current_state_view
              state_and_body_hash
          in
          [%log internal] "Update_ledger_and_get_statements_done" ;
          [%log internal] "Update_coinbase_stack_done"
            ~metadata:
              [ ("is_new_stack", `Bool is_new_stack)
              ; ("transactions_len", `Int (List.length transactions))
              ; ("data_len", `Int (List.length data))
              ] ;
          ( is_new_stack
          , data
          , Pending_coinbase.Update.Action.Update_one
          , `Update_one updated_stack
          , `First_pass_ledger_end first_pass_ledger_end )
      | Some _ ->
          (*Two partition:
            Assumption: Only one of the partition will have coinbase transaction(s)in it.
            1. Get the latest stack for coinbase in the first set of transactions
            2. get the first set of scan_state data[data1]
            3. get a new stack for the second partion because the second set of transactions would start from the begining of the next tree in the scan_state
            4. Initialize the new stack with the state from the first stack
            5. get the second set of scan_state data[data2]*)
          let txns_for_partition1 = List.take transactions slots in
          let coinbase_in_first_partition =
            coinbase_exists txns_for_partition1
          in
          let%bind working_stack1 =
            working_stack pending_coinbase_collection ~is_new_stack:false
            |> Deferred.return
          in
          let txns_for_partition2 = List.drop transactions slots in
          [%log internal] "Update_ledger_and_get_statements"
            ~metadata:[ ("partition", `String "both") ] ;
          let%map data, updated_stack1, updated_stack2, first_pass_ledger_end =
            update_ledger_and_get_statements ~constraint_constants ~global_slot
              ledger working_stack1
              (txns_for_partition1, Some txns_for_partition2)
              current_state_view state_and_body_hash
          in
          [%log internal] "Update_ledger_and_get_statements_done" ;
          let second_has_data = List.length txns_for_partition2 > 0 in
          let pending_coinbase_action, stack_update =
            match (coinbase_in_first_partition, second_has_data) with
            | true, true ->
                ( Pending_coinbase.Update.Action.Update_two_coinbase_in_first
                , `Update_two (updated_stack1, updated_stack2) )
            (*updated_stack2 does not have coinbase and but has the state from the previous stack*)
            | true, false ->
                (*updated_stack1 has some new coinbase but parition 2 has no
                  data and so we have only one stack to update*)
                (Update_one, `Update_one updated_stack1)
            | false, true ->
                (*updated_stack1 just has the new state. [updated stack2] might have coinbase, definitely has some
                  data and therefore will have a non-dummy state.*)
                ( Update_two_coinbase_in_second
                , `Update_two (updated_stack1, updated_stack2) )
            | false, false ->
                (* a diff consists of only non-coinbase transactions. This is currently not possible because a diff will have a coinbase at the very least, so don't update anything?*)
                (Update_none, `Update_none)
          in
          [%log internal] "Update_coinbase_stack_done"
            ~metadata:
              [ ("is_new_stack", `Bool false)
              ; ( "coinbase_in_first_partition"
                , `Bool coinbase_in_first_partition )
              ; ("second_has_data", `Bool second_has_data)
              ; ( "txns_for_partition1_len"
                , `Int (List.length txns_for_partition1) )
              ; ( "txns_for_partition2_len"
                , `Int (List.length txns_for_partition2) )
              ] ;
          ( false
          , data
          , pending_coinbase_action
          , stack_update
          , `First_pass_ledger_end first_pass_ledger_end ) )
    else (
      [%log internal] "Update_coinbase_stack_done" ;
      Deferred.return
        (Ok
           ( false
           , []
           , Pending_coinbase.Update.Action.Update_none
           , `Update_none
           , `First_pass_ledger_end (Ledger.merkle_root ledger) ) ) )

  (*update the pending_coinbase tree with the updated/new stack and delete the oldest stack if a proof was emitted*)
  let update_pending_coinbase_collection ~depth pending_coinbase_collection
      stack_update ~is_new_stack ~ledger_proof =
    let open Result.Let_syntax in
    (*Deleting oldest stack if proof emitted*)
    let%bind pending_coinbase_collection_updated1 =
      match ledger_proof with
      | Some (proof, _) ->
          let%bind oldest_stack, pending_coinbase_collection_updated1 =
            Pending_coinbase.remove_coinbase_stack ~depth
              pending_coinbase_collection
            |> to_staged_ledger_or_error
          in
          let ledger_proof_stack =
            (Ledger_proof.statement proof).target.pending_coinbase_stack
          in
          let%map () =
            if Pending_coinbase.Stack.equal oldest_stack ledger_proof_stack then
              Ok ()
            else
              Error
                (Staged_ledger_error.Unexpected
                   (Error.of_string
                      "Pending coinbase stack of the ledger proof did not \
                       match the oldest stack in the pending coinbase tree." )
                )
          in
          pending_coinbase_collection_updated1
      | None ->
          Ok pending_coinbase_collection
    in
    (*updating the latest stack and/or adding a new one*)
    match stack_update with
    | `Update_none ->
        Ok pending_coinbase_collection_updated1
    | `Update_one stack1 ->
        Pending_coinbase.update_coinbase_stack ~depth
          pending_coinbase_collection_updated1 stack1 ~is_new_stack
        |> to_staged_ledger_or_error
    | `Update_two (stack1, stack2) ->
        (*The case when some of the transactions go into the old tree and remaining on to the new tree*)
        let%bind update1 =
          Pending_coinbase.update_coinbase_stack ~depth
            pending_coinbase_collection_updated1 stack1 ~is_new_stack:false
          |> to_staged_ledger_or_error
        in
        Pending_coinbase.update_coinbase_stack ~depth update1 stack2
          ~is_new_stack:true
        |> to_staged_ledger_or_error

  let coinbase_for_blockchain_snark = function
    | [] ->
        Ok Currency.Amount.zero
    | [ amount ] ->
        Ok amount
    | [ amount1; _ ] ->
        Ok amount1
    | _ ->
        Error
          (Staged_ledger_error.Pre_diff
             (Pre_diff_info.Error.Coinbase_error "More than two coinbase parts")
          )

  let apply_diff ?(skip_verification = false) ~logger ~constraint_constants
      ~global_slot t pre_diff_info ~current_state_view ~state_and_body_hash
      ~log_prefix =
    let open Deferred.Result.Let_syntax in
    let max_throughput =
      Int.pow 2 t.constraint_constants.transaction_capacity_log_2
    in
    let spots_available, proofs_waiting =
      let jobs = Scan_state.all_work_statements_exn t.scan_state in
      ( Int.min (Scan_state.free_space t.scan_state) max_throughput
      , List.length jobs )
    in
    let new_mask = Ledger.Mask.create ~depth:(Ledger.depth t.ledger) () in
    let new_ledger = Ledger.register_mask t.ledger new_mask in
    let transactions, works, commands_count, coinbases = pre_diff_info in
    [%log internal] "Update_coinbase_stack"
      ~metadata:
        [ ("transactions", `Int (List.length transactions))
        ; ("works", `Int (List.length works))
        ; ("commands_count", `Int commands_count)
        ; ("coinbases", `Int (List.length coinbases))
        ; ("spots_available", `Int spots_available)
        ; ("proofs_waiting", `Int proofs_waiting)
        ; ("max_throughput", `Int max_throughput)
        ] ;
    let%bind ( is_new_stack
             , data
             , stack_update_in_snark
             , stack_update
             , `First_pass_ledger_end first_pass_ledger_end ) =
      O1trace.thread "update_coinbase_stack_start_time" (fun () ->
          update_coinbase_stack_and_get_data ~logger ~constraint_constants
            ~global_slot t.scan_state new_ledger t.pending_coinbase_collection
            transactions current_state_view state_and_body_hash )
    in
    let slots = List.length data in
    let work_count = List.length works in
    let required_pairs = Scan_state.work_statements_for_new_diff t.scan_state in
    [%log internal] "Check_for_sufficient_snark_work"
      ~metadata:
        [ ("required_pairs", `Int (List.length required_pairs))
        ; ("work_count", `Int work_count)
        ; ("slots", `Int slots)
        ; ("free_space", `Int (Scan_state.free_space t.scan_state))
        ] ;
    let%bind () =
      O1trace.thread "check_for_sufficient_snark_work" (fun () ->
          let required = List.length required_pairs in
          if
            work_count < required
            && List.length data
               > Scan_state.free_space t.scan_state - required + work_count
          then
            Deferred.Result.fail
              (Staged_ledger_error.Insufficient_work
                 (sprintf
                    !"Insufficient number of transaction snark work (slots \
                      occupying: %d)  required %d, got %d"
                    slots required work_count ) )
          else Deferred.Result.return () )
    in
    [%log internal] "Check_zero_fee_excess" ;
    let%bind () = Deferred.return (check_zero_fee_excess t.scan_state data) in
    [%log internal] "Fill_work_and_enqueue_transactions" ;
    let%bind res_opt, scan_state' =
      O1trace.thread "fill_work_and_enqueue_transactions" (fun () ->
          let r =
            Scan_state.fill_work_and_enqueue_transactions t.scan_state ~logger
              data works
          in
          Or_error.iter_error r ~f:(fun e ->
              let data_json =
                `List
                  (List.map data
                     ~f:(fun
                          { Scan_state.Transaction_with_witness.statement; _ }
                        -> Transaction_snark.Statement.to_yojson statement ) )
              in
              [%log error]
                ~metadata:
                  [ ( "scan_state"
                    , `String (Scan_state.snark_job_list_json t.scan_state) )
                  ; ("data", data_json)
                  ; ("error", Error_json.error_to_yojson e)
                  ; ("prefix", `String log_prefix)
                  ]
                !"$prefix: Unexpected error when applying diff data $data to \
                  the scan_state $scan_state: $error" ) ;
          Deferred.return (to_staged_ledger_or_error r) )
    in
    let%bind () = yield_result () in
    [%log internal] "Update_pending_coinbase_collection" ;
    let%bind updated_pending_coinbase_collection' =
      O1trace.thread "update_pending_coinbase_collection" (fun () ->
          update_pending_coinbase_collection
            ~depth:t.constraint_constants.pending_coinbase_depth
            t.pending_coinbase_collection stack_update ~is_new_stack
            ~ledger_proof:res_opt
          |> Deferred.return )
    in
    let%bind () = yield_result () in
    let%bind coinbase_amount =
      Deferred.return (coinbase_for_blockchain_snark coinbases)
    in
    let%bind latest_pending_coinbase_stack =
      Pending_coinbase.latest_stack ~is_new_stack:false
        updated_pending_coinbase_collection'
      |> to_staged_ledger_or_error |> Deferred.return
    in
    let%bind () = yield_result () in
    let%map () =
      if skip_verification || List.is_empty data then Deferred.return (Ok ())
      else (
        [%log internal] "Verify_scan_state_after_apply" ;
        O1trace.thread "verify_scan_state_after_apply" (fun () ->
            Deferred.(
              verify_scan_state_after_apply ~constraint_constants
                ~first_pass_ledger_end
                ~second_pass_ledger_end:
                  (Frozen_ledger_hash.of_ledger_hash
                     (Ledger.merkle_root new_ledger) )
                ~pending_coinbase_stack:latest_pending_coinbase_stack
                scan_state'
              >>| to_staged_ledger_or_error) ) )
    in
    [%log debug]
      ~metadata:
        [ ("user_command_count", `Int commands_count)
        ; ("coinbase_count", `Int (List.length coinbases))
        ; ("spots_available", `Int spots_available)
        ; ("proof_bundles_waiting", `Int proofs_waiting)
        ; ("work_count", `Int (List.length works))
        ; ("prefix", `String log_prefix)
        ]
      "$prefix: apply_diff block info: No of transactions \
       included:$user_command_count\n\
      \      Coinbase parts:$coinbase_count Spots\n\
      \      available:$spots_available Pending work in the \
       scan-state:$proof_bundles_waiting Work included:$work_count" ;
    let new_staged_ledger =
      { scan_state = scan_state'
      ; ledger = new_ledger
      ; constraint_constants = t.constraint_constants
      ; pending_coinbase_collection = updated_pending_coinbase_collection'
      }
    in
    [%log internal] "Hash_new_staged_ledger" ;
    let staged_ledger_hash = hash new_staged_ledger in
    [%log internal] "Hash_new_staged_ledger_done" ;
    ( `Hash_after_applying staged_ledger_hash
    , `Ledger_proof res_opt
    , `Staged_ledger new_staged_ledger
    , `Pending_coinbase_update
        ( is_new_stack
        , { Pending_coinbase.Update.Poly.action = stack_update_in_snark
          ; coinbase_amount
          } ) )

  let update_metrics (t : t) (witness : Staged_ledger_diff.t) =
    let open Or_error.Let_syntax in
    let commands = Staged_ledger_diff.commands witness in
    let work = Staged_ledger_diff.completed_works witness in
    let%bind total_txn_fee =
      sum_fees commands ~f:(fun { data = cmd; _ } -> User_command.fee cmd)
    in
    let%bind total_snark_fee = sum_fees work ~f:Transaction_snark_work.fee in
    let%bind () = Scan_state.update_metrics t.scan_state in
    Or_error.try_with (fun () ->
        let open Mina_metrics in
        Gauge.set Scan_state_metrics.snark_fee_per_block
          (Int.to_float @@ Fee.to_nanomina_int total_snark_fee) ;
        Gauge.set Scan_state_metrics.transaction_fees_per_block
          (Int.to_float @@ Fee.to_nanomina_int total_txn_fee) ;
        Gauge.set Scan_state_metrics.purchased_snark_work_per_block
          (Float.of_int @@ List.length work) ;
        Gauge.set Scan_state_metrics.snark_work_required
          (Float.of_int
             (List.length (Scan_state.all_work_statements_exn t.scan_state)) ) )

  let forget_prediff_info ((a : Transaction.Valid.t With_status.t list), b, c, d)
      =
    (List.map ~f:(With_status.map ~f:Transaction.forget) a, b, c, d)

  let check_commands ledger ~verifier (cs : User_command.t With_status.t list) =
    let open Deferred.Or_error.Let_syntax in
    let%bind cs =
      User_command.Last.to_all_verifiable cs
        ~find_vk:
          (Zkapp_command.Verifiable.find_vk_via_ledger ~ledger ~get:Ledger.get
             ~location_of_account:Ledger.location_of_account )
      |> Deferred.return
    in
    let%map xs = Verifier.verify_commands verifier cs in
    Result.all
      (List.map xs ~f:(function
        | `Valid x ->
            Ok x
        | ( `Invalid_keys _
          | `Invalid_signature _
          | `Invalid_proof _
          | `Missing_verification_key _
          | `Unexpected_verification_key _
          | `Mismatched_authorization_kind _ ) as invalid ->
            Error
              (Verifier.Failure.Verification_failed
                 (Error.tag ~tag:"verification failed on command"
                    (Verifier.invalid_to_error invalid) ) )
        | `Valid_assuming _ ->
            Error
              (Verifier.Failure.Verification_failed
                 (Error.of_string "batch verification failed") ) ) )

  let apply ?skip_verification ~constraint_constants ~global_slot t
      (witness : Staged_ledger_diff.t) ~logger ~verifier ~current_state_view
      ~state_and_body_hash ~coinbase_receiver ~supercharge_coinbase =
    let open Deferred.Result.Let_syntax in
    let work = Staged_ledger_diff.completed_works witness in
    let%bind () =
      O1trace.thread "check_completed_works" (fun () ->
          match skip_verification with
          | Some `All | Some `Proofs ->
              return ()
          | None ->
              [%log internal] "Check_completed_works"
                ~metadata:[ ("work_count", `Int (List.length work)) ] ;
              check_completed_works ~logger ~verifier t.scan_state work )
    in
    [%log internal] "Prediff" ;
    let%bind prediff =
      Pre_diff_info.get witness ~constraint_constants ~coinbase_receiver
        ~supercharge_coinbase
        ~check:(check_commands t.ledger ~verifier)
      |> Deferred.map
           ~f:
             (Result.map_error ~f:(fun error ->
                  Staged_ledger_error.Pre_diff error ) )
    in
    let apply_diff_start_time = Core.Time.now () in
    [%log internal] "Apply_diff" ;
    let%map ((_, _, `Staged_ledger new_staged_ledger, _) as res) =
      apply_diff
        ~skip_verification:
          ([%equal: [ `All | `Proofs ] option] skip_verification (Some `All))
        ~constraint_constants ~global_slot t
        (forget_prediff_info prediff)
        ~logger ~current_state_view ~state_and_body_hash
        ~log_prefix:"apply_diff"
    in
    [%log internal] "Diff_applied" ;
    [%log debug]
      ~metadata:
        [ ( "time_elapsed"
          , `Float Core.Time.(Span.to_ms @@ diff (now ()) apply_diff_start_time)
          )
        ]
      "Staged_ledger.apply_diff take $time_elapsed" ;
    let () =
      Or_error.iter_error (update_metrics new_staged_ledger witness)
        ~f:(fun e ->
          [%log error]
            ~metadata:[ ("error", Error_json.error_to_yojson e) ]
            !"Error updating metrics after applying staged_ledger diff: $error" )
    in
    res

  let apply_diff_unchecked ~constraint_constants ~global_slot t
      (sl_diff : Staged_ledger_diff.With_valid_signatures_and_proofs.t) ~logger
      ~current_state_view ~state_and_body_hash ~coinbase_receiver
      ~supercharge_coinbase =
    let open Deferred.Result.Let_syntax in
    let%bind prediff =
      Result.map_error ~f:(fun error -> Staged_ledger_error.Pre_diff error)
      @@ Pre_diff_info.get_unchecked ~constraint_constants ~coinbase_receiver
           ~supercharge_coinbase sl_diff
      |> Deferred.return
    in
    apply_diff t
      (forget_prediff_info prediff)
      ~constraint_constants ~global_slot ~logger ~current_state_view
      ~state_and_body_hash ~log_prefix:"apply_diff_unchecked"

  module Resources = struct
    module Discarded = struct
      type t =
        { commands_rev : User_command.Valid.t Sequence.t
        ; completed_work : Transaction_snark_work.Checked.t Sequence.t
        }
      [@@deriving sexp_of]

      let add_user_command t uc =
        { t with
          commands_rev = Sequence.append t.commands_rev (Sequence.singleton uc)
        }

      let add_completed_work t cw =
        { t with
          completed_work =
            Sequence.append (Sequence.singleton cw) t.completed_work
        }
    end

    type t =
      { max_space : int (*max space available currently*)
      ; max_jobs : int
            (*Required amount of work for max_space that can be purchased*)
      ; commands_rev : User_command.Valid.t Sequence.t
      ; completed_work_rev : Transaction_snark_work.Checked.t Sequence.t
      ; fee_transfers : Fee.t Public_key.Compressed.Map.t
      ; add_coinbase : bool
      ; coinbase : Coinbase.Fee_transfer.t Staged_ledger_diff.At_most_two.t
      ; supercharge_coinbase : bool
      ; receiver_pk : Public_key.Compressed.t
      ; budget : Fee.t Or_error.t
      ; discarded : Discarded.t
      ; is_coinbase_receiver_new : bool
      ; logger : (Logger.t[@sexp.opaque])
      }
    [@@deriving sexp_of]

    let coinbase_ft (cw : Transaction_snark_work.t) =
      (* Here we could not add the fee transfer if the prover=receiver_pk but
         retaining it to preserve that information in the
         staged_ledger_diff. It will be checked in apply_diff before adding*)
      Option.some_if
        Fee.(cw.fee > Fee.zero)
        (Coinbase.Fee_transfer.create ~receiver_pk:cw.prover ~fee:cw.fee)

    let cheapest_two_work (works : Transaction_snark_work.Checked.t Sequence.t)
        =
      Sequence.fold works ~init:(None, None) ~f:(fun (w1, w2) w ->
          match (w1, w2) with
          | None, _ ->
              (Some w, None)
          | Some x, None ->
              if Currency.Fee.compare w.fee x.fee < 0 then (Some w, w1)
              else (w1, Some w)
          | Some x, Some y ->
              if Currency.Fee.compare w.fee x.fee < 0 then (Some w, w1)
              else if Currency.Fee.compare w.fee y.fee < 0 then (w1, Some w)
              else (w1, w2) )

    let coinbase_work
        ~(constraint_constants : Genesis_constants.Constraint_constants.t)
        ?(is_two = false) (works : Transaction_snark_work.Checked.t Sequence.t)
        ~is_coinbase_receiver_new ~supercharge_coinbase =
      let open Option.Let_syntax in
      let min1, min2 = cheapest_two_work works in
      let diff ws ws' =
        Sequence.filter ws ~f:(fun w ->
            Sequence.mem ws'
              (Transaction_snark_work.statement w)
              ~equal:Transaction_snark_work.Statement.equal
            |> not )
      in
      let%bind coinbase_amount =
        coinbase_amount ~supercharge_coinbase ~constraint_constants
      in
      let%bind budget =
        (*if the coinbase receiver is new then the account creation fee will be deducted from the reward*)
        if is_coinbase_receiver_new then
          Currency.Amount.(
            sub coinbase_amount
              (of_fee constraint_constants.account_creation_fee))
        else Some coinbase_amount
      in
      let stmt = Transaction_snark_work.statement in
      if is_two then
        match (min1, min2) with
        | None, _ ->
            None
        | Some w, None ->
            if Amount.(of_fee w.fee <= budget) then
              let cb =
                Staged_ledger_diff.At_most_two.Two
                  (Option.map (coinbase_ft w) ~f:(fun ft -> (ft, None)))
              in
              Some (cb, diff works (Sequence.of_list [ stmt w ]))
            else
              let cb = Staged_ledger_diff.At_most_two.Two None in
              Some (cb, works)
        | Some w1, Some w2 ->
            let%map sum = Fee.add w1.fee w2.fee in
            if Amount.(of_fee sum <= budget) then
              let cb =
                Staged_ledger_diff.At_most_two.Two
                  (Option.map (coinbase_ft w1) ~f:(fun ft ->
                       (ft, coinbase_ft w2) ) )
                (*Why add work without checking if work constraints are
                  satisfied? If we reach here then it means that we are trying to
                  fill the last two slots of the tree with coinbase trnasactions
                  and if there's any work in [works] then that has to be included,
                  either in the coinbase or as fee transfers that gets paid by
                  the transaction fees. So having it as coinbase ft will at least
                  reduce the slots occupied by fee transfers*)
              in
              (cb, diff works (Sequence.of_list [ stmt w1; stmt w2 ]))
            else if Amount.(of_fee w1.fee <= coinbase_amount) then
              let cb =
                Staged_ledger_diff.At_most_two.Two
                  (Option.map (coinbase_ft w1) ~f:(fun ft -> (ft, None)))
              in
              (cb, diff works (Sequence.of_list [ stmt w1 ]))
            else
              let cb = Staged_ledger_diff.At_most_two.Two None in
              (cb, works)
      else
        Option.map min1 ~f:(fun w ->
            if Amount.(of_fee w.fee <= budget) then
              let cb = Staged_ledger_diff.At_most_two.One (coinbase_ft w) in
              (cb, diff works (Sequence.of_list [ stmt w ]))
            else
              let cb = Staged_ledger_diff.At_most_two.One None in
              (cb, works) )

    let init_coinbase_and_fee_transfers ~constraint_constants cw_seq
        ~add_coinbase ~job_count ~slots ~is_coinbase_receiver_new
        ~supercharge_coinbase =
      let cw_unchecked work =
        Sequence.map work ~f:Transaction_snark_work.forget
      in
      let coinbase, rem_cw =
        match
          ( add_coinbase
          , coinbase_work ~constraint_constants cw_seq ~is_coinbase_receiver_new
              ~supercharge_coinbase )
        with
        | true, Some (ft, rem_cw) ->
            (ft, rem_cw)
        | true, None ->
            (*Coinbase could not be added because work-fees > coinbase-amount*)
            if job_count = 0 || slots - job_count >= 1 then
              (*Either no jobs are required or there is a free slot that can be filled without having to include any work*)
              (One None, cw_seq)
            else (Zero, cw_seq)
        | _ ->
            (Zero, cw_seq)
      in
      let rem_cw = cw_unchecked rem_cw in
      let singles =
        Sequence.filter_map rem_cw
          ~f:(fun { Transaction_snark_work.fee; prover; _ } ->
            if Fee.equal fee Fee.zero then None else Some (prover, fee) )
        |> Sequence.to_list_rev
      in
      (coinbase, singles)

    let init ~constraint_constants (uc_seq : User_command.Valid.t Sequence.t)
        (cw_seq : Transaction_snark_work.Checked.t Sequence.t)
        (slots, job_count) ~receiver_pk ~add_coinbase ~supercharge_coinbase
        logger ~is_coinbase_receiver_new =
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
      let coinbase, singles =
        init_coinbase_and_fee_transfers ~constraint_constants cw_seq
          ~add_coinbase ~job_count ~slots ~is_coinbase_receiver_new
          ~supercharge_coinbase
      in
      let fee_transfers =
        Public_key.Compressed.Map.of_alist_reduce singles ~f:(fun f1 f2 ->
            Option.value_exn (Fee.add f1 f2) )
      in
      let budget =
        Or_error.map2
          (sum_fees (Sequence.to_list uc_seq) ~f:(fun t ->
               User_command.fee (User_command.forget_check t) ) )
          (sum_fees
             (List.filter
                ~f:(fun (k, _) ->
                  not (Public_key.Compressed.equal k receiver_pk) )
                singles )
             ~f:snd )
          ~f:(fun r c -> option "budget did not suffice" (Fee.sub r c))
        |> Or_error.join
      in
      let discarded =
        { Discarded.completed_work = Sequence.empty
        ; commands_rev = Sequence.empty
        }
      in
      { max_space = slots
      ; max_jobs = job_count
      ; commands_rev =
          uc_seq
          (*Completed work in reverse order for faster removal of proofs if budget doesn't suffice*)
      ; completed_work_rev = seq_rev cw_seq
      ; fee_transfers
      ; add_coinbase
      ; supercharge_coinbase
      ; receiver_pk
      ; coinbase
      ; budget
      ; discarded
      ; is_coinbase_receiver_new
      ; logger
      }

    let reselect_coinbase_work ~constraint_constants t =
      let cw_unchecked work =
        Sequence.map work ~f:Transaction_snark_work.forget
      in
      let coinbase, rem_cw =
        match t.coinbase with
        | Staged_ledger_diff.At_most_two.Zero ->
            (t.coinbase, t.completed_work_rev)
        | One _ -> (
            match
              coinbase_work ~constraint_constants t.completed_work_rev
                ~is_coinbase_receiver_new:t.is_coinbase_receiver_new
                ~supercharge_coinbase:t.supercharge_coinbase
            with
            | None ->
                (One None, t.completed_work_rev)
            | Some (ft, rem_cw) ->
                (ft, rem_cw) )
        | Two _ -> (
            match
              coinbase_work ~constraint_constants t.completed_work_rev
                ~is_two:true
                ~is_coinbase_receiver_new:t.is_coinbase_receiver_new
                ~supercharge_coinbase:t.supercharge_coinbase
            with
            | None ->
                (Two None, t.completed_work_rev)
                (*Check for work constraint will be done in [check_constraints_and_update]*)
            | Some (fts', rem_cw) ->
                (fts', rem_cw) )
      in
      let rem_cw = cw_unchecked rem_cw in
      let singles =
        Sequence.filter_map rem_cw
          ~f:(fun { Transaction_snark_work.fee; prover; _ } ->
            if Fee.equal fee Fee.zero then None else Some (prover, fee) )
        |> Sequence.to_list_rev
      in
      let fee_transfers =
        Public_key.Compressed.Map.of_alist_reduce singles ~f:(fun f1 f2 ->
            Option.value_exn (Fee.add f1 f2) )
      in
      { t with coinbase; fee_transfers }

    let rebudget t =
      (*get the correct coinbase and calculate the fee transfers*)
      let open Or_error.Let_syntax in
      let payment_fees =
        sum_fees (Sequence.to_list t.commands_rev) ~f:(fun t ->
            User_command.(fee (forget_check t)) )
      in
      let prover_fee_others =
        Public_key.Compressed.Map.fold t.fee_transfers ~init:(Ok Fee.zero)
          ~f:(fun ~key ~data fees ->
            let%bind others = fees in
            if Public_key.Compressed.equal t.receiver_pk key then Ok others
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
            if Fee.(b > Fee.zero) then 1 else 0
      in
      let other_provers =
        Public_key.Compressed.Map.filter_keys t.fee_transfers
          ~f:(Fn.compose not (Public_key.Compressed.equal t.receiver_pk))
      in
      let total_fee_transfer_pks =
        Public_key.Compressed.Map.length other_provers + fee_for_self
      in
      Sequence.length t.commands_rev
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

    let discard_last_work ~constraint_constants t =
      match Sequence.next t.completed_work_rev with
      | None ->
          (t, None)
      | Some (w, rem_seq) ->
          let to_be_discarded = Transaction_snark_work.forget w in
          let discarded = Discarded.add_completed_work t.discarded w in
          let new_t =
            reselect_coinbase_work ~constraint_constants
              { t with completed_work_rev = rem_seq; discarded }
          in
          let budget =
            match t.budget with
            | Ok b ->
                option "Currency overflow" (Fee.add b to_be_discarded.fee)
            | _ ->
                rebudget new_t
          in
          ({ new_t with budget }, Some w)

    let discard_user_command t =
      let decr_coinbase t =
        (*When discarding coinbase's fee transfer, add the fee transfer to the fee_transfers map so that budget checks can be done *)
        let update_fee_transfers t (ft : Coinbase.Fee_transfer.t) coinbase =
          let updated_fee_transfers =
            Public_key.Compressed.Map.update t.fee_transfers ft.receiver_pk
              ~f:(fun _ -> ft.fee)
          in
          let new_t =
            { t with coinbase; fee_transfers = updated_fee_transfers }
          in
          let updated_budget = rebudget new_t in
          { new_t with budget = updated_budget }
        in
        match t.coinbase with
        | Staged_ledger_diff.At_most_two.Zero ->
            t
        | One None ->
            { t with coinbase = Staged_ledger_diff.At_most_two.Zero }
        | Two None ->
            { t with coinbase = One None }
        | Two (Some (ft, None)) ->
            { t with coinbase = One (Some ft) }
        | One (Some ft) ->
            update_fee_transfers t ft Zero
        | Two (Some (ft1, Some ft2)) ->
            update_fee_transfers t ft2 (One (Some ft1))
      in
      match Sequence.next t.commands_rev with
      | None ->
          (* If we have reached here then it means we couldn't afford a slot for coinbase as well *)
          (decr_coinbase t, None)
      | Some (uc, rem_seq) ->
          let discarded = Discarded.add_user_command t.discarded uc in
          let new_t = { t with commands_rev = rem_seq; discarded } in
          let budget =
            match t.budget with
            | Ok b ->
                option "Fee insufficient"
                  (Fee.sub b User_command.(fee (forget_check uc)))
            | _ ->
                rebudget new_t
          in
          ({ new_t with budget }, Some uc)

    let worked_more ~constraint_constants resources =
      (*Is the work constraint satisfied even after discarding a work bundle?
         We reach here after having more than enough work*)
      let more_work t =
        let slots = slots_occupied t in
        let cw_count = Sequence.length t.completed_work_rev in
        cw_count > 0 && cw_count >= slots
      in
      let r, _ = discard_last_work ~constraint_constants resources in
      more_work r

    let incr_coinbase_part_by ~constraint_constants t count =
      let open Or_error.Let_syntax in
      let incr = function
        | Staged_ledger_diff.At_most_two.Zero ->
            Ok (Staged_ledger_diff.At_most_two.One None)
        | One None ->
            Ok (Two None)
        | One (Some ft) ->
            Ok (Two (Some (ft, None)))
        | _ ->
            Or_error.error_string "Coinbase count cannot be more than two"
      in
      let by_one res =
        let res' =
          match Sequence.next res.discarded.completed_work with
          (*add one from the discarded list to [completed_work_rev] and then select a work from [completed_work_rev] except the one already used*)
          | Some (w, rem_work) ->
              let%map coinbase = incr res.coinbase in
              let res' =
                { res with
                  completed_work_rev =
                    Sequence.append (Sequence.singleton w)
                      res.completed_work_rev
                ; discarded = { res.discarded with completed_work = rem_work }
                ; coinbase
                }
              in
              reselect_coinbase_work ~constraint_constants res'
          | None ->
              let%bind coinbase = incr res.coinbase in
              let res = { res with coinbase } in
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
            [%log' error t.logger] "Error when increasing coinbase: $error"
              ~metadata:[ ("error", Error_json.error_to_yojson e) ] ;
            res
      in
      match count with `One -> by_one t | `Two -> by_one (by_one t)
  end

  let rec check_constraints_and_update ~constraint_constants
      (resources : Resources.t) log =
    if Resources.slots_occupied resources = 0 then (resources, log)
    else if Resources.work_constraint_satisfied resources then
      if
        (*There's enough work. Check if they satisfy other constraints*)
        Resources.budget_sufficient resources
      then
        if Resources.space_constraint_satisfied resources then (resources, log)
        else if Resources.worked_more ~constraint_constants resources then
          (*There are too many fee_transfers(from the proofs) occupying the slots. discard one and check*)
          let resources', work_opt =
            Resources.discard_last_work ~constraint_constants resources
          in
          check_constraints_and_update ~constraint_constants resources'
            (Option.value_map work_opt ~default:log ~f:(fun work ->
                 Diff_creation_log.discard_completed_work `Extra_work work log )
            )
        else
          (*Well, there's no space; discard a user command *)
          let resources', uc_opt = Resources.discard_user_command resources in
          check_constraints_and_update ~constraint_constants resources'
            (Option.value_map uc_opt ~default:log ~f:(fun uc ->
                 Diff_creation_log.discard_command `No_space
                   (User_command.forget_check uc)
                   log ) )
      else
        (* insufficient budget; reduce the cost*)
        let resources', work_opt =
          Resources.discard_last_work ~constraint_constants resources
        in
        check_constraints_and_update ~constraint_constants resources'
          (Option.value_map work_opt ~default:log ~f:(fun work ->
               Diff_creation_log.discard_completed_work `Insufficient_fees work
                 log ) )
    else
      (* There isn't enough work for the transactions. Discard a transaction and check again *)
      let resources', uc_opt = Resources.discard_user_command resources in
      check_constraints_and_update ~constraint_constants resources'
        (Option.value_map uc_opt ~default:log ~f:(fun uc ->
             Diff_creation_log.discard_command `No_work
               (User_command.forget_check uc)
               log ) )

  let one_prediff ~constraint_constants cw_seq ts_seq ~receiver ~add_coinbase
      slot_job_count logger ~is_coinbase_receiver_new partition
      ~supercharge_coinbase =
    O1trace.sync_thread "create_staged_ledger_diff_one_prediff" (fun () ->
        let init_resources =
          Resources.init ~constraint_constants ts_seq cw_seq slot_job_count
            ~receiver_pk:receiver ~add_coinbase logger ~is_coinbase_receiver_new
            ~supercharge_coinbase
        in
        let log =
          Diff_creation_log.init
            ~completed_work:init_resources.completed_work_rev
            ~commands:init_resources.commands_rev
            ~coinbase:init_resources.coinbase ~partition
            ~available_slots:(fst slot_job_count)
            ~required_work_count:(snd slot_job_count)
        in
        check_constraints_and_update ~constraint_constants init_resources log )

  let generate ~constraint_constants logger cw_seq ts_seq ~receiver
      ~is_coinbase_receiver_new ~supercharge_coinbase
      (partitions : Scan_state.Space_partition.t) =
    let pre_diff_with_one (res : Resources.t) :
        ( Transaction_snark_work.Checked.t
        , User_command.Valid.t )
        Staged_ledger_diff.Pre_diff_one.t =
      O1trace.sync_thread "create_staged_ledger_pre_diff_with_one" (fun () ->
          let to_at_most_one = function
            | Staged_ledger_diff.At_most_two.Zero ->
                Staged_ledger_diff.At_most_one.Zero
            | One x ->
                One x
            | _ ->
                [%log error]
                  "Error creating staged ledger diff: Should have at most one \
                   coinbase in the second pre_diff" ;
                Zero
          in
          (* We have to reverse here because we only know they work in THIS order *)
          { Staged_ledger_diff.Pre_diff_one.commands =
              Sequence.to_list_rev res.commands_rev
          ; completed_works = Sequence.to_list_rev res.completed_work_rev
          ; coinbase = to_at_most_one res.coinbase
          ; internal_command_statuses =
              [] (*updated later based on application result*)
          } )
    in
    let pre_diff_with_two (res : Resources.t) :
        ( Transaction_snark_work.Checked.t
        , User_command.Valid.t )
        Staged_ledger_diff.Pre_diff_two.t =
      (* We have to reverse here because we only know they work in THIS order *)
      { commands = Sequence.to_list_rev res.commands_rev
      ; completed_works = Sequence.to_list_rev res.completed_work_rev
      ; coinbase = res.coinbase
      ; internal_command_statuses =
          [] (*updated later based on application result*)
      }
    in
    let end_log ((res : Resources.t), (log : Diff_creation_log.t)) =
      Diff_creation_log.end_log log ~completed_work:res.completed_work_rev
        ~commands:res.commands_rev ~coinbase:res.coinbase
    in
    let make_diff res1 = function
      | Some res2 ->
          ( (pre_diff_with_two (fst res1), Some (pre_diff_with_one (fst res2)))
          , List.map ~f:end_log [ res1; res2 ] )
      | None ->
          ((pre_diff_with_two (fst res1), None), [ end_log res1 ])
    in
    let has_no_commands (res : Resources.t) =
      Sequence.length res.commands_rev = 0
    in
    let second_pre_diff (res : Resources.t) partition ~add_coinbase work =
      one_prediff ~constraint_constants work res.discarded.commands_rev
        ~receiver partition ~add_coinbase logger ~is_coinbase_receiver_new
        ~supercharge_coinbase `Second
    in
    let isEmpty (res : Resources.t) =
      has_no_commands res && Resources.coinbase_added res = 0
    in
    (*Partitioning explained in PR #687 *)
    match partitions.second with
    | None ->
        let res, log =
          one_prediff ~constraint_constants cw_seq ts_seq ~receiver
            partitions.first ~add_coinbase:true logger ~is_coinbase_receiver_new
            ~supercharge_coinbase `First
        in
        make_diff (res, log) None
    | Some y ->
        assert (Sequence.length cw_seq <= snd partitions.first + snd y) ;
        let cw_seq_1 = Sequence.take cw_seq (snd partitions.first) in
        let cw_seq_2 = Sequence.drop cw_seq (snd partitions.first) in
        let res, log1 =
          one_prediff ~constraint_constants cw_seq_1 ts_seq ~receiver
            partitions.first ~add_coinbase:false logger
            ~is_coinbase_receiver_new ~supercharge_coinbase `First
        in
        let incr_coinbase_and_compute res count =
          let new_res =
            Resources.incr_coinbase_part_by ~constraint_constants res count
          in
          if Resources.space_available new_res then
            (*All slots could not be filled either because of budget constraints or not enough work done. Don't create the second prediff instead recompute first diff with just once coinbase*)
            ( one_prediff ~constraint_constants cw_seq_1 ts_seq ~receiver
                partitions.first ~add_coinbase:true logger
                ~is_coinbase_receiver_new ~supercharge_coinbase `First
            , None )
          else
            let res2, log2 =
              second_pre_diff new_res y ~add_coinbase:false cw_seq_2
            in
            if isEmpty res2 then
              (*Don't create the second prediff instead recompute first diff with just once coinbase*)
              ( one_prediff ~constraint_constants cw_seq_1 ts_seq ~receiver
                  partitions.first ~add_coinbase:true logger
                  ~is_coinbase_receiver_new ~supercharge_coinbase `First
              , None )
            else ((new_res, log1), Some (res2, log2))
        in
        let try_with_coinbase () =
          one_prediff ~constraint_constants cw_seq_1 ts_seq ~receiver
            partitions.first ~add_coinbase:true logger ~is_coinbase_receiver_new
            ~supercharge_coinbase `First
        in
        let res1, res2 =
          if Sequence.is_empty res.commands_rev then
            let res = try_with_coinbase () in
            (res, None)
          else
            match Resources.available_space res with
            | 0 ->
                (*generate the next prediff with a coinbase at least*)
                let res2 = second_pre_diff res y ~add_coinbase:true cw_seq_2 in
                ((res, log1), Some res2)
            | 1 ->
                (*There's a slot available in the first partition, fill it with coinbase and create another pre_diff for the slots in the second partiton with the remaining user commands and work *)
                incr_coinbase_and_compute res `One
            | 2 ->
                (*There are two slots which cannot be filled using user commands, so we split the coinbase into two parts and fill those two spots*)
                incr_coinbase_and_compute res `Two
            | _ ->
                (* Too many slots left in the first partition. Either there wasn't enough work to add transactions or there weren't enough transactions. Create a new pre_diff for just the first partition*)
                let res = try_with_coinbase () in
                (res, None)
        in
        let coinbase_added =
          Resources.coinbase_added (fst res1)
          + Option.value_map
              ~f:(Fn.compose Resources.coinbase_added fst)
              res2 ~default:0
        in
        if coinbase_added > 0 then make_diff res1 res2
        else
          (*Coinbase takes priority over user-commands. Create a diff in partitions.first with coinbase first and user commands if possible*)
          let res = try_with_coinbase () in
          make_diff res None

  let can_apply_supercharged_coinbase_exn ~winner ~epoch_ledger ~global_slot =
    Sparse_ledger.has_locked_tokens_exn ~global_slot
      ~account_id:(Account_id.create winner Token_id.default)
      epoch_ledger
    |> not

  let with_ledger_mask base_ledger ~f =
    let mask =
      Ledger.register_mask base_ledger
        (Ledger.Mask.create ~depth:(Ledger.depth base_ledger) ())
    in
    let r = f mask in
    ignore
      ( Ledger.unregister_mask_exn ~loc:Caml.__LOC__ mask
        : Ledger.unattached_mask ) ;
    r

  let create_diff
      ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ~(global_slot : Mina_numbers.Global_slot_since_genesis.t)
      ?(log_block_creation = false) t ~coinbase_receiver ~logger
      ~current_state_view
      ~(transactions_by_fee : User_command.Valid.t Sequence.t)
      ~(get_completed_work :
            Transaction_snark_work.Statement.t
         -> Transaction_snark_work.Checked.t option ) ~supercharge_coinbase =
    O1trace.sync_thread "create_staged_ledger_diff" (fun () ->
        let open Result.Let_syntax in
        let module Transaction_validator =
          Transaction_snark.Transaction_validator
        in
        with_ledger_mask t.ledger ~f:(fun validating_ledger ->
            let is_new_account pk =
              Ledger.location_of_account validating_ledger
                (Account_id.create pk Token_id.default)
              |> Option.is_none
            in
            let is_coinbase_receiver_new = is_new_account coinbase_receiver in
            if supercharge_coinbase then
              [%log info]
                "No locked tokens in the delegator/delegatee account, applying \
                 supercharged coinbase" ;
            [%log internal] "Get_snark_work_for_pending_transactions" ;
            let partitions = Scan_state.partition_if_overflowing t.scan_state in
            let work_to_do =
              Scan_state.work_statements_for_new_diff t.scan_state
            in
            let completed_works_seq, proof_count =
              List.fold_until work_to_do ~init:(Sequence.empty, 0)
                ~f:(fun (seq, count) w ->
                  match get_completed_work w with
                  | Some cw_checked ->
                      (*If new provers can't pay the account-creation-fee then discard
                        their work unless their fee is zero in which case their account
                        won't be created. This is to encourage using an existing accounts
                        for snarking.
                        This also imposes new snarkers to have a min fee until one of
                        their snarks are purchased and their accounts get created*)
                      if
                        Currency.Fee.(cw_checked.fee = zero)
                        || Currency.Fee.(
                             cw_checked.fee
                             >= constraint_constants.account_creation_fee)
                        || not (is_new_account cw_checked.prover)
                      then
                        Continue
                          ( Sequence.append seq (Sequence.singleton cw_checked)
                          , One_or_two.length cw_checked.proofs + count )
                      else (
                        [%log debug]
                          ~metadata:
                            [ ( "work"
                              , Transaction_snark_work.Checked.to_yojson
                                  cw_checked )
                            ; ( "work_ids"
                              , Transaction_snark_work.Statement.compact_json w
                              )
                            ; ( "snark_fee"
                              , Currency.Fee.to_yojson cw_checked.fee )
                            ; ( "account_creation_fee"
                              , Currency.Fee.to_yojson
                                  constraint_constants.account_creation_fee )
                            ]
                          !"Staged_ledger_diff creation: Snark fee $snark_fee \
                            insufficient to create the snark worker account" ;
                        [%log internal] "@block_metadata"
                          ~metadata:
                            [ ("interrupt_get_completed_work_at", `Int count)
                            ; ( "interrupt_get_completed_work_reason"
                              , `String
                                  "Snark fee insufficient to create snark \
                                   worker account" )
                            ] ;
                        Stop (seq, count) )
                  | None ->
                      [%log debug]
                        ~metadata:
                          [ ( "statement"
                            , Transaction_snark_work.Statement.to_yojson w )
                          ; ( "work_ids"
                            , Transaction_snark_work.Statement.compact_json w )
                          ]
                        !"Staged_ledger_diff creation: No snark work found for \
                          $statement" ;
                      [%log internal] "@block_metadata"
                        ~metadata:
                          [ ("interrupt_get_completed_work_at", `Int count)
                          ; ( "interrupt_get_completed_work_reason"
                            , `String "Snark work for statement not found" )
                          ] ;
                      Stop (seq, count) )
                ~finish:Fn.id
            in
            [%log internal] "@metadata"
              ~metadata:
                [ ("work_to_do_count", `Int (List.length work_to_do))
                ; ("proof_count", `Int proof_count)
                ] ;
            [%log internal] "Validate_and_apply_transactions" ;
            (*Transactions in reverse order for faster removal if there is no space when creating the diff*)
            let valid_on_this_ledger, invalid_on_this_ledger =
              Sequence.fold_until transactions_by_fee
                ~init:(Sequence.empty, [], 0)
                ~f:(fun (valid_seq, invalid_txns, count) txn ->
                  match
                    O1trace.sync_thread
                      "validate_transaction_against_staged_ledger" (fun () ->
                        Transaction_validator.apply_transaction_first_pass
                          ~constraint_constants ~global_slot validating_ledger
                          ~txn_state_view:current_state_view
                          (Command (User_command.forget_check txn)) )
                  with
                  | Error e ->
                      [%log error]
                        ~metadata:
                          [ ("user_command", User_command.Valid.to_yojson txn)
                          ; ("error", Error_json.error_to_yojson e)
                          ]
                        "Staged_ledger_diff creation: Skipping user command: \
                         $user_command due to error: $error" ;
                      Continue (valid_seq, (txn, e) :: invalid_txns, count)
                  | Ok _txn_partially_applied ->
                      let valid_seq' =
                        Sequence.append (Sequence.singleton txn) valid_seq
                      in
                      let count' = count + 1 in
                      if count' >= Scan_state.free_space t.scan_state then
                        Stop (valid_seq', invalid_txns)
                      else Continue (valid_seq', invalid_txns, count') )
                ~finish:(fun (valid, invalid, _) -> (valid, invalid))
            in
            [%log internal] "Generate_staged_ledger_diff" ;
            let diff, log =
              O1trace.sync_thread "generate_staged_ledger_diff" (fun () ->
                  generate ~constraint_constants logger completed_works_seq
                    valid_on_this_ledger ~receiver:coinbase_receiver
                    ~is_coinbase_receiver_new ~supercharge_coinbase partitions )
            in
            let summaries = List.map ~f:fst log in
            [%log internal] "@block_metadata"
              ~metadata:
                [ ("proof_count", `Int proof_count)
                ; ("txn_count", `Int (Sequence.length valid_on_this_ledger))
                ; ( "diff_log"
                  , Diff_creation_log.summary_list_to_yojson summaries )
                ] ;
            [%log internal] "Generate_staged_ledger_diff_done" ;
            let%map diff =
              (* Fill in the statuses for commands. *)
              with_ledger_mask t.ledger ~f:(fun status_ledger ->
                  Pre_diff_info.compute_statuses ~constraint_constants ~diff
                    ~coinbase_amount:
                      (Option.value_exn
                         (coinbase_amount ~constraint_constants
                            ~supercharge_coinbase ) )
                    ~coinbase_receiver ~global_slot
                    ~txn_state_view:current_state_view ~ledger:status_ledger )
            in
            let summaries, detailed = List.unzip log in
            [%log debug]
              "Number of proofs ready for purchase: $proof_count Number of \
               user commands ready to be included: $txn_count Diff creation \
               log: $diff_log"
              ~metadata:
                [ ("proof_count", `Int proof_count)
                ; ("txn_count", `Int (Sequence.length valid_on_this_ledger))
                ; ( "diff_log"
                  , Diff_creation_log.summary_list_to_yojson summaries )
                ] ;
            if log_block_creation then
              [%log debug] "Detailed diff creation log: $diff_log"
                ~metadata:
                  [ ( "diff_log"
                    , Diff_creation_log.detail_list_to_yojson
                        (List.map ~f:List.rev detailed) )
                  ] ;
            ( { Staged_ledger_diff.With_valid_signatures_and_proofs.diff }
            , invalid_on_this_ledger ) ) )

  let latest_block_accounts_created t ~previous_block_state_hash =
    let scan_state = scan_state t in
    (* filter leaves by state hash from previous block *)
    let block_transactions_applied =
      let f
          ({ state_hash = leaf_block_hash, _; transaction_with_info; _ } :
            Scan_state.Transaction_with_witness.t ) =
        if State_hash.equal leaf_block_hash previous_block_state_hash then
          Some transaction_with_info.varying
        else None
      in
      List.filter_map (Scan_state.base_jobs_on_latest_tree scan_state) ~f
      @ List.filter_map
          (Scan_state.base_jobs_on_earlier_tree ~index:0 scan_state)
          ~f
    in
    List.map block_transactions_applied ~f:(function
      | Command (Signed_command cmd) -> (
          match cmd.body with
          | Payment { new_accounts } ->
              new_accounts
          | Stake_delegation _ ->
              []
          | Failed ->
              [] )
      | Command (Zkapp_command { new_accounts; _ }) ->
          new_accounts
      | Fee_transfer { new_accounts; _ } ->
          new_accounts
      | Coinbase { new_accounts; _ } ->
          new_accounts )
    |> List.concat
end

include T

let%test_module "staged ledger tests" =
  ( module struct
    module Sl = T

    let () =
      Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true

    let self_pk =
      Quickcheck.random_value ~seed:(`Deterministic "self_pk")
        Public_key.Compressed.gen

    let coinbase_receiver =
      Quickcheck.random_value ~seed:(`Deterministic "receiver_pk")
        Public_key.Compressed.gen

    let proof_level = Genesis_constants.Proof_level.for_unit_tests

    let constraint_constants =
      Genesis_constants.Constraint_constants.for_unit_tests

    let logger = Logger.null ()

    let `VK vk, `Prover zkapp_prover =
      Transaction_snark.For_tests.create_trivial_snapp ~constraint_constants ()

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.create ~logger ~proof_level ~constraint_constants
            ~conf_dir:None
            ~pids:(Child_processes.Termination.create_pid_table ())
            () )

    let supercharge_coinbase ~ledger ~winner ~global_slot =
      (*using staged ledger to confirm coinbase amount is correctly generated*)
      let epoch_ledger =
        Sparse_ledger.of_ledger_subset_exn ledger
          (List.map [ winner ] ~f:(fun k ->
               Account_id.create k Token_id.default ) )
      in
      Sl.can_apply_supercharged_coinbase_exn ~winner ~global_slot ~epoch_ledger

    (* Functor for testing with different instantiated staged ledger modules. *)
    let create_and_apply_with_state_body_hash
        ?(coinbase_receiver = coinbase_receiver) ?(winner = self_pk)
        ~(current_state_view : Zkapp_precondition.Protocol_state.View.t)
        ~global_slot ~state_and_body_hash sl txns stmt_to_work =
      let open Deferred.Let_syntax in
      let supercharge_coinbase =
        supercharge_coinbase ~ledger:(Sl.ledger !sl) ~winner ~global_slot
      in
      let diff =
        Sl.create_diff ~constraint_constants ~global_slot !sl ~logger
          ~current_state_view ~transactions_by_fee:txns
          ~get_completed_work:stmt_to_work ~supercharge_coinbase
          ~coinbase_receiver
      in
      let diff, _invalid_txns =
        match diff with
        | Ok x ->
            x
        | Error e ->
            Error.raise (Pre_diff_info.Error.to_error e)
      in
      let diff' = Staged_ledger_diff.forget diff in
      let%map ( `Hash_after_applying hash
              , `Ledger_proof ledger_proof
              , `Staged_ledger sl'
              , `Pending_coinbase_update (is_new_stack, pc_update) ) =
        match%map
          Sl.apply ~constraint_constants ~global_slot !sl diff' ~logger
            ~verifier ~current_state_view ~state_and_body_hash
            ~coinbase_receiver ~supercharge_coinbase
        with
        | Ok x ->
            x
        | Error e ->
            Error.raise (Sl.Staged_ledger_error.to_error e)
      in
      assert (Staged_ledger_hash.equal hash (Sl.hash sl')) ;
      sl := sl' ;
      (ledger_proof, diff', is_new_stack, pc_update, supercharge_coinbase)

    let dummy_state_and_view ?global_slot () =
      let state =
        let consensus_constants =
          let genesis_constants = Genesis_constants.for_unit_tests in
          Consensus.Constants.create ~constraint_constants
            ~protocol_constants:genesis_constants.protocol
        in
        let compile_time_genesis =
          let open Staged_ledger_diff in
          (*not using Precomputed_values.for_unit_test because of dependency cycle*)
          Mina_state.Genesis_protocol_state.t
            ~genesis_ledger:Genesis_ledger.(Packed.t for_unit_tests)
            ~genesis_epoch_data:Consensus.Genesis_epoch_data.for_unit_tests
            ~constraint_constants ~consensus_constants ~genesis_body_reference
        in
        compile_time_genesis.data
      in
      let state_with_global_slot =
        match global_slot with
        | None ->
            state
        | Some global_slot ->
            (*Protocol state views are always from previous block*)
            let prev_global_slot =
              Option.value ~default:Mina_numbers.Global_slot_since_genesis.zero
                (Mina_numbers.Global_slot_since_genesis.sub global_slot
                   Mina_numbers.Global_slot_span.one )
            in
            let consensus_state =
              Consensus.Proof_of_stake.Exported.Consensus_state.Unsafe
              .dummy_advance
                (Mina_state.Protocol_state.consensus_state state)
                ~new_global_slot_since_genesis:prev_global_slot
                ~increase_epoch_count:false
            in
            let body =
              Mina_state.Protocol_state.Body.For_tests.with_consensus_state
                (Mina_state.Protocol_state.body state)
                consensus_state
            in
            Mina_state.Protocol_state.create
              ~previous_state_hash:
                (Mina_state.Protocol_state.previous_state_hash state)
              ~body
      in
      ( state_with_global_slot
      , Mina_state.Protocol_state.Body.view
          (Mina_state.Protocol_state.body state_with_global_slot) )

    let dummy_state_view ?global_slot () =
      dummy_state_and_view ?global_slot () |> snd

    let create_and_apply ?(coinbase_receiver = coinbase_receiver)
        ?(winner = self_pk) ~global_slot ~protocol_state_view
        ~state_and_body_hash sl txns stmt_to_work =
      let open Deferred.Let_syntax in
      let%map ledger_proof, diff, _, _, _ =
        create_and_apply_with_state_body_hash ~coinbase_receiver ~winner
          ~current_state_view:protocol_state_view ~global_slot
          ~state_and_body_hash sl txns stmt_to_work
      in
      (ledger_proof, diff)

    module Transfer = Mina_ledger.Ledger_transfer.Make (Ledger) (Ledger)

    (* Run the given function inside of the Deferred monad, with a staged
         ledger and a separate test ledger, after applying the given
         init_state to both. In the below tests we apply the same commands to
         the staged and test ledgers, and verify they are in the same state.
    *)
    let async_with_given_ledger ledger
        (f :
             snarked_ledger:Ledger.t
          -> Sl.t ref
          -> Ledger.Mask.Attached.t
          -> unit Deferred.t ) =
      let casted = Ledger.Any_ledger.cast (module Ledger) ledger in
      let test_mask =
        Ledger.Maskable.register_mask casted
          (Ledger.Mask.create ~depth:(Ledger.depth ledger) ())
      in
      let snarked_ledger_mask =
        Ledger.Maskable.register_mask casted
          (Ledger.Mask.create ~depth:(Ledger.depth ledger) ())
      in
      let sl = ref @@ Sl.create_exn ~constraint_constants ~ledger in
      Async.Thread_safe.block_on_async_exn (fun () ->
          f ~snarked_ledger:snarked_ledger_mask sl test_mask ) ;
      ignore @@ Ledger.Maskable.unregister_mask_exn ~loc:__LOC__ test_mask

    (* populate the ledger from an initial state before running the function *)
    let async_with_ledgers ledger_init_state
        (f :
             snarked_ledger:Ledger.t
          -> Sl.t ref
          -> Ledger.Mask.Attached.t
          -> unit Deferred.t ) =
      Ledger.with_ephemeral_ledger ~depth:constraint_constants.ledger_depth
        ~f:(fun ledger ->
          Ledger.apply_initial_ledger_state ledger ledger_init_state ;
          async_with_given_ledger ledger f )

    (* Assert the given staged ledger is in the correct state after applying
         the first n user commands passed to the given base ledger. Checks the
         states of the block producer account and user accounts but ignores
         snark workers for simplicity. *)
    let assert_ledger :
           Ledger.t
        -> coinbase_cost:Currency.Fee.t
        -> global_slot:Mina_numbers.Global_slot_since_genesis.t
        -> protocol_state_view:Zkapp_precondition.Protocol_state.View.t
        -> Sl.t
        -> User_command.Valid.t list
        -> int
        -> Account_id.t list
        -> unit =
     fun test_ledger ~coinbase_cost ~global_slot ~protocol_state_view
         staged_ledger cmds_all cmds_used pks_to_check ->
      let producer_account_id =
        Account_id.create coinbase_receiver Token_id.default
      in
      let producer_account =
        Option.bind
          (Ledger.location_of_account test_ledger producer_account_id)
          ~f:(Ledger.get test_ledger)
      in
      let is_producer_acc_new = Option.is_none producer_account in
      let old_producer_balance =
        Option.value_map producer_account ~default:Currency.Balance.zero
          ~f:(fun a -> a.balance)
      in
      let apply_cmds cmds =
        cmds
        |> List.map ~f:(fun cmd ->
               Transaction.Command (User_command.forget_check cmd) )
        |> Ledger.apply_transactions ~constraint_constants ~global_slot
             ~txn_state_view:protocol_state_view test_ledger
        |> Or_error.ignore_m
      in
      Or_error.ok_exn @@ apply_cmds @@ List.take cmds_all cmds_used ;
      let get_account_exn ledger pk =
        Option.value_exn
          (Option.bind
             (Ledger.location_of_account ledger pk)
             ~f:(Ledger.get ledger) )
      in
      (* Check the user accounts in the updated staged ledger are as
         expected.
      *)
      List.iter pks_to_check ~f:(fun pk ->
          let expect = get_account_exn test_ledger pk in
          let actual = get_account_exn (Sl.ledger staged_ledger) pk in
          [%test_result: Account.t] ~expect actual ) ;
      (* We only test that the block producer got the coinbase reward here, since calculating the exact correct amount depends on the snark fees and tx fees. *)
      let producer_balance_with_coinbase =
        (let open Option.Let_syntax in
        let%bind total_cost =
          if is_producer_acc_new then
            Currency.Fee.add coinbase_cost
              constraint_constants.account_creation_fee
          else Some coinbase_cost
        in
        let%bind reward =
          Currency.Amount.(
            sub constraint_constants.coinbase_amount (of_fee total_cost))
        in
        Currency.Balance.add_amount old_producer_balance reward)
        |> Option.value_exn
      in
      let new_producer_balance =
        (get_account_exn (Sl.ledger staged_ledger) producer_account_id).balance
      in
      assert (
        Currency.Balance.(
          new_producer_balance >= producer_balance_with_coinbase) )

    let work_fee = constraint_constants.account_creation_fee

    (* Deterministically compute a prover public key from a snark work statement. *)
    let stmt_to_prover :
        Transaction_snark_work.Statement.t -> Public_key.Compressed.t =
     fun stmts ->
      let prover_seed =
        One_or_two.fold stmts ~init:"P" ~f:(fun p stmt ->
            p
            ^ Frozen_ledger_hash.to_bytes stmt.target.first_pass_ledger
            ^ Frozen_ledger_hash.to_bytes stmt.target.second_pass_ledger )
      in
      Quickcheck.random_value ~seed:(`Deterministic prover_seed)
        Public_key.Compressed.gen

    let proofs stmts : Ledger_proof.t One_or_two.t =
      let sok_digest = Sok_message.Digest.default in
      One_or_two.map stmts ~f:(fun statement ->
          Ledger_proof.create ~statement ~sok_digest
            ~proof:Proof.transaction_dummy )

    let stmt_to_work_random_prover (stmts : Transaction_snark_work.Statement.t)
        : Transaction_snark_work.Checked.t option =
      let prover = stmt_to_prover stmts in
      Some
        { Transaction_snark_work.Checked.fee = work_fee
        ; proofs = proofs stmts
        ; prover
        }

    let stmt_to_work_zero_fee ~prover
        (stmts : Transaction_snark_work.Statement.t) :
        Transaction_snark_work.Checked.t option =
      Some
        { Transaction_snark_work.Checked.fee = Currency.Fee.zero
        ; proofs = proofs stmts
        ; prover
        }

    (* Fixed public key for when there is only one snark worker. *)
    let snark_worker_pk =
      Quickcheck.random_value ~seed:(`Deterministic "snark worker")
        Public_key.Compressed.gen

    let stmt_to_work_one_prover (stmts : Transaction_snark_work.Statement.t) :
        Transaction_snark_work.Checked.t option =
      Some { fee = work_fee; proofs = proofs stmts; prover = snark_worker_pk }

    let coinbase_first_prediff = function
      | Staged_ledger_diff.At_most_two.Zero ->
          (0, [])
      | One None ->
          (1, [])
      | One (Some ft) ->
          (1, [ ft ])
      | Two None ->
          (2, [])
      | Two (Some (ft, None)) ->
          (2, [ ft ])
      | Two (Some (ft1, Some ft2)) ->
          (2, [ ft1; ft2 ])

    let coinbase_second_prediff = function
      | Staged_ledger_diff.At_most_one.Zero ->
          (0, [])
      | One None ->
          (1, [])
      | One (Some ft) ->
          (1, [ ft ])

    let coinbase_count (sl_diff : Staged_ledger_diff.t) =
      (coinbase_first_prediff (fst sl_diff.diff).coinbase |> fst)
      + Option.value_map ~default:0 (snd sl_diff.diff) ~f:(fun d ->
            coinbase_second_prediff d.coinbase |> fst )

    let coinbase_cost (sl_diff : Staged_ledger_diff.t) =
      let coinbase_fts =
        (coinbase_first_prediff (fst sl_diff.diff).coinbase |> snd)
        @ Option.value_map ~default:[] (snd sl_diff.diff) ~f:(fun d ->
              coinbase_second_prediff d.coinbase |> snd )
      in
      List.fold coinbase_fts ~init:Currency.Fee.zero ~f:(fun total ft ->
          Currency.Fee.add total ft.fee |> Option.value_exn )

    let () =
      Async.Scheduler.set_record_backtraces true ;
      Backtrace.elide := false

    (* The tests are still very slow, so we set ~trials very low for all the
       QuickCheck tests. We may be able to turn them up after #2759 and/or #2760
       happen.
    *)

    (* Get the public keys from a ledger init state. *)
    let init_pks (init : Ledger.init_state) =
      Array.to_sequence init
      |> Sequence.map ~f:(fun (kp, _, _, _) ->
             Account_id.create
               (Public_key.compress kp.public_key)
               Token_id.default )
      |> Sequence.to_list

    (* Fee excess at top level ledger proofs should always be zero *)
    let assert_fee_excess :
           ( Ledger_proof.t
           * (Transaction.t With_status.t * _ * _)
             Sl.Scan_state.Transactions_ordered.Poly.t
             list )
           option
        -> unit =
     fun proof_opt ->
      let fee_excess =
        Option.value_map ~default:Fee_excess.zero proof_opt
          ~f:(fun (proof, _txns) -> (Ledger_proof.statement proof).fee_excess)
      in
      assert (Fee_excess.is_zero fee_excess)

    let transaction_capacity =
      Int.pow 2 constraint_constants.transaction_capacity_log_2

    (* Abstraction for the pattern of taking a list of commands and applying it
       in chunks up to a given max size. *)
    let rec iter_cmds_acc :
           User_command.Valid.t list (** All the commands to apply. *)
        -> int option list
           (** A list of chunk sizes. If a chunk's size is None, apply as many
            commands as possible. *)
        -> 'acc
        -> (   User_command.Valid.t list (** All commands remaining. *)
            -> int option (* Current chunk size. *)
            -> User_command.Valid.t Sequence.t
               (* Sequence of commands to apply. *)
            -> 'acc
            -> (Staged_ledger_diff.t * 'acc) Deferred.t )
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
            List.length @@ Staged_ledger_diff.commands diff
          in
          iter_cmds_acc (List.drop cmds cmds_applied_count) counts_rest acc' f

    (** Generic test framework. *)
    let test_simple :
           global_slot:int
        -> Account_id.t list
        -> User_command.Valid.t list
        -> int option list
        -> Sl.t ref
        -> ?expected_proof_count:int option (*Number of ledger proofs expected*)
        -> ?allow_failures:bool
        -> ?check_snarked_ledger_transition:bool
        -> snarked_ledger:Ledger.t
        -> Ledger.Mask.Attached.t
        -> [ `One_prover | `Many_provers ]
        -> (   Transaction_snark_work.Statement.t
            -> Transaction_snark_work.Checked.t option )
        -> unit Deferred.t =
     fun ~global_slot account_ids_to_check cmds cmd_iters sl
         ?(expected_proof_count = None) ?(allow_failures = false)
         ?(check_snarked_ledger_transition = false) ~snarked_ledger test_mask
         provers stmt_to_work ->
      let global_slot =
        Mina_numbers.Global_slot_since_genesis.of_int global_slot
      in
      let state_tbl = State_hash.Table.create () in
      (*Add genesis state to the table*)
      let genesis, _ = dummy_state_and_view () in
      let state_hash = (Mina_state.Protocol_state.hashes genesis).state_hash in
      State_hash.Table.add state_tbl ~key:state_hash ~data:genesis |> ignore ;
      let%map `Proof_count total_ledger_proofs, _ =
        iter_cmds_acc cmds cmd_iters
          (`Proof_count 0, `Slot global_slot)
          (fun cmds_left count_opt cmds_this_iter
               (`Proof_count proof_count, `Slot global_slot) ->
            let current_state, current_view =
              dummy_state_and_view ~global_slot ()
            in
            let state_hash =
              (Mina_state.Protocol_state.hashes current_state).state_hash
            in
            State_hash.Table.add state_tbl ~key:state_hash ~data:current_state
            |> ignore ;
            let%bind ledger_proof, diff =
              create_and_apply ~global_slot ~protocol_state_view:current_view
                ~state_and_body_hash:
                  ( state_hash
                  , (Mina_state.Protocol_state.hashes current_state)
                      .state_body_hash |> Option.value_exn )
                sl cmds_this_iter stmt_to_work
            in
            List.iter (Staged_ledger_diff.commands diff) ~f:(fun c ->
                match With_status.status c with
                | Applied ->
                    ()
                | Failed ftl ->
                    if not allow_failures then
                      failwith
                        (sprintf
                           "Transaction application failed for command %s. \
                            Failures %s"
                           ( User_command.to_yojson (With_status.data c)
                           |> Yojson.Safe.to_string )
                           ( Transaction_status.Failure.Collection.to_yojson ftl
                           |> Yojson.Safe.to_string ) ) ) ;
            let do_snarked_ledger_transition proof_opt =
              let apply_first_pass =
                Ledger.apply_transaction_first_pass ~constraint_constants
              in
              let apply_second_pass = Ledger.apply_transaction_second_pass in
              let apply_first_pass_sparse_ledger ~global_slot ~txn_state_view
                  sparse_ledger txn =
                let open Or_error.Let_syntax in
                let%map _ledger, partial_txn =
                  Mina_ledger.Sparse_ledger.apply_transaction_first_pass
                    ~constraint_constants ~global_slot ~txn_state_view
                    sparse_ledger txn
                in
                partial_txn
              in
              let get_state state_hash =
                Ok (State_hash.Table.find_exn state_tbl state_hash)
              in
              let%bind () =
                match proof_opt with
                | Some (proof, _transactions) ->
                    (*update snarked ledger with the transactions in the most recently emitted proof*)
                    let%map res =
                      Sl.Scan_state.get_snarked_ledger_async
                        ~ledger:snarked_ledger ~get_protocol_state:get_state
                        ~apply_first_pass ~apply_second_pass
                        ~apply_first_pass_sparse_ledger !sl.scan_state
                    in
                    let target_snarked_ledger =
                      let stmt = Ledger_proof.statement proof in
                      stmt.target.first_pass_ledger
                    in
                    [%test_eq: Ledger_hash.t] target_snarked_ledger
                      (Ledger.merkle_root snarked_ledger) ;
                    Or_error.ok_exn res
                | None ->
                    Deferred.return ()
              in
              (*Check snarked_ledger to staged_ledger transition*)
              let casted =
                Ledger.Any_ledger.cast (module Ledger) snarked_ledger
              in
              let sl_of_snarked_ledger =
                Ledger.Maskable.register_mask casted
                  (Ledger.Mask.create ~depth:(Ledger.depth snarked_ledger) ())
              in
              let expected_staged_ledger_merkle_root =
                Ledger.merkle_root !sl.ledger
              in
              let%map construction_result =
                Sl.of_scan_state_pending_coinbases_and_snarked_ledger ~logger
                  ~snarked_local_state:
                    Mina_state.(
                      Protocol_state.blockchain_state current_state
                      |> Blockchain_state.snarked_local_state)
                  ~verifier ~constraint_constants ~scan_state:!sl.scan_state
                  ~snarked_ledger:sl_of_snarked_ledger
                  ~expected_merkle_root:expected_staged_ledger_merkle_root
                  ~pending_coinbases:!sl.pending_coinbase_collection ~get_state
              in
              let _result = Or_error.ok_exn construction_result in
              [%test_eq: Ledger_hash.t]
                (Ledger.merkle_root sl_of_snarked_ledger)
                (Ledger.merkle_root !sl.ledger) ;
              ignore
                (Ledger.unregister_mask_exn sl_of_snarked_ledger ~loc:__LOC__)
            in
            let%bind () =
              if check_snarked_ledger_transition then
                do_snarked_ledger_transition ledger_proof
              else Deferred.return ()
            in
            let proof_count' =
              Option.value_map ~default:proof_count
                ~f:(fun _ -> proof_count + 1)
                ledger_proof
            in
            assert_fee_excess ledger_proof ;
            let cmds_applied_this_iter =
              List.length @@ Staged_ledger_diff.commands diff
            in
            let cb = coinbase_count diff in
            ( match provers with
            | `One_prover ->
                assert (cb = 1)
            | `Many_provers ->
                assert (cb > 0 && cb < 3) ) ;
            ( match count_opt with
            | Some _ ->
                (* There is an edge case where cmds_applied_this_iter = 0, when
                   there is only enough space for coinbase transactions. *)
                assert (cmds_applied_this_iter <= Sequence.length cmds_this_iter) ;
                [%test_eq: User_command.t list]
                  (List.map (Staged_ledger_diff.commands diff)
                     ~f:(fun { With_status.data; _ } -> data) )
                  ( Sequence.take cmds_this_iter cmds_applied_this_iter
                  |> Sequence.map ~f:User_command.forget_check
                  |> Sequence.to_list )
            | None ->
                () ) ;
            let coinbase_cost = coinbase_cost diff in
            assert_ledger test_mask ~coinbase_cost ~global_slot
              ~protocol_state_view:current_view !sl cmds_left
              cmds_applied_this_iter account_ids_to_check ;
            (*increment global slots to simulate multiple blocks*)
            return
              ( diff
              , ( `Proof_count proof_count'
                , `Slot
                    (Mina_numbers.Global_slot_since_genesis.succ global_slot) )
              ) )
      in
      (*Should have enough blocks to generate at least expected_proof_count
        proofs*)
      if Option.is_some expected_proof_count then
        assert (total_ledger_proofs = Option.value_exn expected_proof_count)

    (* How many blocks do we need to fully exercise the ledger
       behavior and produce one ledger proof *)
    let min_blocks_for_first_snarked_ledger_generic =
      (constraint_constants.transaction_capacity_log_2 + 1)
      * (constraint_constants.work_delay + 1)
      + 1

    (* n-1 extra blocks for n ledger proofs since we are already producing one
       proof *)
    let max_blocks_for_coverage n =
      min_blocks_for_first_snarked_ledger_generic + n - 1

    (** Generator for when we always have enough commands to fill all slots. *)

    let gen_at_capacity :
        (Ledger.init_state * User_command.Valid.t list * int option list)
        Quickcheck.Generator.t =
      let open Quickcheck.Generator.Let_syntax in
      let%bind ledger_init_state = Ledger.gen_initial_ledger_state in
      let%bind iters = Int.gen_incl 1 (max_blocks_for_coverage 0) in
      let num_cmds = transaction_capacity * iters in
      let%bind cmds =
        User_command.Valid.Gen.sequence ~length:num_cmds ~sign_type:`Real
          ledger_init_state
      in
      assert (List.length cmds = num_cmds) ;
      return (ledger_init_state, cmds, List.init iters ~f:(Fn.const None))

    let gen_zkapps ?failure ~num_zkapps zkapps_per_iter :
        (Ledger.t * User_command.Valid.t list * int option list)
        Quickcheck.Generator.t =
      let open Quickcheck.Generator.Let_syntax in
      let%bind zkapp_command_and_fee_payer_keypairs, ledger =
        Mina_generators.User_command_generators
        .sequence_zkapp_command_with_ledger ~max_token_updates:1
          ~length:num_zkapps ~vk ?failure ()
      in
      let zkapps =
        List.map zkapp_command_and_fee_payer_keypairs ~f:(function
          | Zkapp_command zkapp_command_valid, _fee_payer_keypair, keymap ->
              let zkapp_command_with_auths =
                Async.Thread_safe.block_on_async_exn (fun () ->
                    Zkapp_command_builder.replace_authorizations ~keymap
                      (Zkapp_command.Valid.forget zkapp_command_valid) )
              in
              let valid_zkapp_command_with_auths : Zkapp_command.Valid.t =
                match
                  Zkapp_command.Valid.to_valid ~status:Applied
                    ~find_vk:
                      (Zkapp_command.Verifiable.find_vk_via_ledger ~ledger
                         ~get:Ledger.get
                         ~location_of_account:Ledger.location_of_account )
                    zkapp_command_with_auths
                with
                | Ok ps ->
                    ps
                | Error err ->
                    Error.raise
                    @@ Error.tag ~tag:"Could not create Zkapp_command.Valid.t"
                         err
              in
              User_command.Zkapp_command valid_zkapp_command_with_auths
          | Signed_command _, _, _ ->
              failwith "Expected a Zkapp_command, got a Signed command" )
      in
      assert (List.length zkapps = num_zkapps) ;
      return (ledger, zkapps, zkapps_per_iter)

    let gen_failing_zkapps_at_capacity :
        (Ledger.t * User_command.Valid.t list * int option list)
        Quickcheck.Generator.t =
      let open Quickcheck.Generator.Let_syntax in
      let%bind iters = Int.gen_incl 1 (max_blocks_for_coverage 0) in
      let num_zkapps = transaction_capacity * iters in
      gen_zkapps
        ~failure:
          Mina_generators.Zkapp_command_generators.Invalid_account_precondition
        ~num_zkapps
        (List.init iters ~f:(Fn.const None))

    let gen_zkapps_at_capacity :
        (Ledger.t * User_command.Valid.t list * int option list)
        Quickcheck.Generator.t =
      let open Quickcheck.Generator.Let_syntax in
      let%bind iters = Int.gen_incl 1 (max_blocks_for_coverage 0) in
      let num_zkapps = transaction_capacity * iters in
      gen_zkapps ~num_zkapps (List.init iters ~f:(Fn.const None))

    (*Same as gen_at_capacity except that the number of iterations[iters] is
      the function of [extra_block_count] and is same for all generated values*)
    let gen_zkapps_at_capacity_fixed_blocks extra_block_count :
        (Ledger.t * User_command.Valid.t list * int option list)
        Quickcheck.Generator.t =
      let iters = max_blocks_for_coverage extra_block_count in
      let num_zkapps = transaction_capacity * iters in
      gen_zkapps ~num_zkapps (List.init iters ~f:(Fn.const None))

    let gen_zkapps_below_capacity ?(extra_blocks = false) () :
        (Ledger.t * User_command.Valid.t list * int option list)
        Quickcheck.Generator.t =
      let open Quickcheck.Generator.Let_syntax in
      let iters_max =
        max_blocks_for_coverage 0 * if extra_blocks then 4 else 2
      in
      let iters_min = max_blocks_for_coverage 0 in
      let%bind iters = Int.gen_incl iters_min iters_max in
      (* see comment in gen_below_capacity for rationale *)
      let%bind zkapps_per_iter =
        Quickcheck.Generator.list_with_length iters
          (Int.gen_incl 1 ((transaction_capacity / 2) - 1))
      in
      let num_zkapps = List.fold zkapps_per_iter ~init:0 ~f:( + ) in
      gen_zkapps ~num_zkapps (List.map ~f:Option.some zkapps_per_iter)

    (*Same as gen_at_capacity except that the number of iterations[iters] is
      the function of [extra_block_count] and is same for all generated values*)
    let gen_at_capacity_fixed_blocks extra_block_count :
        (Ledger.init_state * User_command.Valid.t list * int option list)
        Quickcheck.Generator.t =
      let open Quickcheck.Generator.Let_syntax in
      let%bind ledger_init_state = Ledger.gen_initial_ledger_state in
      let iters = max_blocks_for_coverage extra_block_count in
      let total_cmds = transaction_capacity * iters in
      let%bind cmds =
        User_command.Valid.Gen.sequence ~length:total_cmds ~sign_type:`Real
          ledger_init_state
      in
      assert (List.length cmds = total_cmds) ;
      return (ledger_init_state, cmds, List.init iters ~f:(Fn.const None))

    (* Generator for when we have less commands than needed to fill all slots. *)
    let gen_below_capacity ?(extra_blocks = false) () =
      let open Quickcheck.Generator.Let_syntax in
      let%bind ledger_init_state = Ledger.gen_initial_ledger_state in
      let iters_max =
        max_blocks_for_coverage 0 * if extra_blocks then 4 else 2
      in
      let iters_min = max_blocks_for_coverage 0 in
      let%bind iters = Int.gen_incl iters_min iters_max in
      (* N.B. user commands per block is much less than transactions per block
         due to fee transfers and coinbases, especially with worse case number
         of provers, so in order to exercise not filling the scan state
         completely we always apply <= 1/2 transaction_capacity commands.
      *)
      let%bind cmds_per_iter =
        Quickcheck.Generator.list_with_length iters
          (Int.gen_incl 1 ((transaction_capacity / 2) - 1))
      in
      let total_cmds = List.fold cmds_per_iter ~init:0 ~f:( + ) in
      let%bind cmds =
        User_command.Valid.Gen.sequence ~length:total_cmds ~sign_type:`Real
          ledger_init_state
      in
      assert (List.length cmds = total_cmds) ;
      return (ledger_init_state, cmds, List.map ~f:Option.some cmds_per_iter)

    let gen_all_user_commands_below_capacity () =
      let open Quickcheck.Generator.Let_syntax in
      let%bind ledger, zkapps, iters_zkapps = gen_zkapps_below_capacity () in
      let%bind ledger_init_state, cmds, iters_signed_commands =
        gen_below_capacity ()
      in
      Ledger.apply_initial_ledger_state ledger ledger_init_state ;
      let iters = iters_zkapps @ iters_signed_commands in
      let%map cmds =
        let rec go zkapps payments acc =
          match (zkapps, payments) with
          | [], [] ->
              return acc
          | [], payments ->
              return (payments @ acc)
          | zkapps, [] ->
              return (zkapps @ acc)
          | zkapps, payments ->
              let%bind n = Int.gen_incl 1 transaction_capacity in
              let%bind take_zkapps = Quickcheck.Generator.bool in
              if take_zkapps then
                let take_list, leave_list = List.split_n zkapps n in
                go leave_list payments (List.rev take_list @ acc)
              else
                let take_list, leave_list = List.split_n payments n in
                go zkapps leave_list (List.rev take_list @ acc)
        in
        go zkapps cmds []
      in
      (ledger, List.rev cmds, iters)

    let ledger_account_ids ledger =
      Ledger.to_list_sequential ledger |> List.map ~f:Account.identifier

    let%test_unit "Max throughput-ledger proof count-fixed blocks" =
      let expected_proof_count = 3 in
      Quickcheck.test
        Quickcheck.Generator.(
          tuple2
            (gen_at_capacity_fixed_blocks expected_proof_count)
            small_positive_int)
        ~sexp_of:
          [%sexp_of:
            ( Ledger.init_state
            * Mina_base.User_command.Valid.t list
            * int option list )
            * int]
        ~trials:1
        ~f:(fun ((ledger_init_state, cmds, iters), global_slot) ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger sl test_mask ->
              test_simple ~global_slot
                (init_pks ledger_init_state)
                cmds iters sl ~expected_proof_count:(Some expected_proof_count)
                test_mask ~snarked_ledger `Many_provers
                stmt_to_work_random_prover ) )

    let%test_unit "Max throughput" =
      Quickcheck.test
        Quickcheck.Generator.(tuple2 gen_at_capacity small_positive_int)
        ~sexp_of:
          [%sexp_of:
            ( Ledger.init_state
            * Mina_base.User_command.Valid.t list
            * int option list )
            * int]
        ~trials:15
        ~f:(fun ((ledger_init_state, cmds, iters), global_slot) ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger sl test_mask ->
              test_simple ~global_slot
                (init_pks ledger_init_state)
                cmds iters sl test_mask ~snarked_ledger `Many_provers
                stmt_to_work_random_prover ) )

    let%test_unit "Max_throughput (zkapps)" =
      (* limit trials to prevent too-many-open-files failure *)
      Quickcheck.test ~trials:3
        Quickcheck.Generator.(tuple2 gen_zkapps_at_capacity small_positive_int)
        ~f:(fun ((ledger, zkapps, iters), global_slot) ->
          async_with_given_ledger ledger (fun ~snarked_ledger sl test_mask ->
              let account_ids = ledger_account_ids ledger in
              test_simple ~global_slot account_ids zkapps iters sl test_mask
                ~snarked_ledger `Many_provers stmt_to_work_random_prover ) )

    let%test_unit "Max_throughput with zkApp transactions that may fail" =
      (* limit trials to prevent too-many-open-files failure *)
      Quickcheck.test ~trials:2
        Quickcheck.Generator.(
          tuple2 gen_failing_zkapps_at_capacity small_positive_int)
        ~f:(fun ((ledger, zkapps, iters), global_slot) ->
          async_with_given_ledger ledger (fun ~snarked_ledger sl test_mask ->
              let account_ids = ledger_account_ids ledger in
              test_simple ~global_slot account_ids zkapps iters
                ~allow_failures:true sl test_mask ~snarked_ledger `Many_provers
                stmt_to_work_random_prover ) )

    let%test_unit "Max throughput-ledger proof count-fixed blocks (zkApps)" =
      let expected_proof_count = 3 in
      Quickcheck.test
        Quickcheck.Generator.(
          tuple2
            (gen_zkapps_at_capacity_fixed_blocks expected_proof_count)
            small_positive_int)
        ~sexp_of:
          [%sexp_of:
            (Ledger.t * Mina_base.User_command.Valid.t list * int option list)
            * int]
        ~trials:1
        ~f:(fun ((ledger, zkapps, iters), global_slot) ->
          async_with_given_ledger ledger (fun ~snarked_ledger sl test_mask ->
              let account_ids = ledger_account_ids ledger in
              test_simple ~global_slot account_ids zkapps iters sl
                ~expected_proof_count:(Some expected_proof_count)
                ~check_snarked_ledger_transition:true test_mask ~snarked_ledger
                `Many_provers stmt_to_work_random_prover ) )

    let%test_unit "Random number of commands (zkapp + signed command)" =
      Quickcheck.test
        Quickcheck.Generator.(
          tuple2 (gen_all_user_commands_below_capacity ()) small_positive_int)
        ~trials:3
        ~f:(fun ((ledger, cmds, iters), global_slot) ->
          async_with_given_ledger ledger (fun ~snarked_ledger sl test_mask ->
              let account_ids = ledger_account_ids ledger in
              test_simple ~global_slot account_ids cmds iters sl test_mask
                ~snarked_ledger ~check_snarked_ledger_transition:true
                `Many_provers stmt_to_work_random_prover ) )

    let%test_unit "Be able to include random number of commands" =
      Quickcheck.test
        Quickcheck.Generator.(tuple2 (gen_below_capacity ()) small_positive_int)
        ~trials:20
        ~f:(fun ((ledger_init_state, cmds, iters), global_slot) ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger sl test_mask ->
              test_simple ~global_slot
                (init_pks ledger_init_state)
                cmds iters sl test_mask ~snarked_ledger `Many_provers
                stmt_to_work_random_prover ) )

    let%test_unit "Be able to include random number of commands (zkapps)" =
      Quickcheck.test
        Quickcheck.Generator.(
          tuple2 (gen_zkapps_below_capacity ()) small_positive_int)
        ~trials:2
        ~f:(fun ((ledger, zkapps, iters), global_slot) ->
          async_with_given_ledger ledger (fun ~snarked_ledger sl test_mask ->
              let account_ids = ledger_account_ids ledger in
              test_simple ~global_slot account_ids zkapps iters sl test_mask
                ~snarked_ledger `Many_provers stmt_to_work_random_prover ) )

    let%test_unit "Be able to include random number of commands (One prover)" =
      Quickcheck.test
        Quickcheck.Generator.(tuple2 (gen_below_capacity ()) small_positive_int)
        ~trials:20
        ~f:(fun ((ledger_init_state, cmds, iters), global_slot) ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger sl test_mask ->
              test_simple ~global_slot
                (init_pks ledger_init_state)
                cmds iters sl test_mask ~snarked_ledger `One_prover
                stmt_to_work_one_prover ) )

    let%test_unit "Be able to include random number of commands (One prover, \
                   zkapps)" =
      Quickcheck.test
        Quickcheck.Generator.(
          tuple2
            (gen_zkapps_below_capacity ~extra_blocks:true ())
            small_positive_int)
        ~trials:2
        ~f:(fun ((ledger, zkapps, iters), global_slot) ->
          async_with_given_ledger ledger (fun ~snarked_ledger sl test_mask ->
              let account_ids = ledger_account_ids ledger in
              test_simple ~global_slot account_ids zkapps iters sl test_mask
                ~snarked_ledger ~check_snarked_ledger_transition:true
                `One_prover stmt_to_work_one_prover ) )

    let%test_unit "Zero proof-fee should not create a fee transfer" =
      let stmt_to_work_zero_fee stmts =
        Some
          { Transaction_snark_work.Checked.fee = Currency.Fee.zero
          ; proofs = proofs stmts
          ; prover = snark_worker_pk
          }
      in
      let expected_proof_count = 3 in
      Quickcheck.test
        Quickcheck.Generator.(
          tuple2
            (gen_at_capacity_fixed_blocks expected_proof_count)
            small_positive_int)
        ~trials:20
        ~f:(fun ((ledger_init_state, cmds, iters), global_slot) ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger sl test_mask ->
              let%map () =
                test_simple ~global_slot
                  ~expected_proof_count:(Some expected_proof_count)
                  (init_pks ledger_init_state)
                  cmds iters sl test_mask ~snarked_ledger `One_prover
                  stmt_to_work_zero_fee
              in
              assert (
                Option.is_none
                  (Ledger.location_of_account test_mask
                     (Account_id.create snark_worker_pk Token_id.default) ) ) )
          )

    let compute_statuses ~ledger ~coinbase_amount ~global_slot diff =
      with_ledger_mask ledger ~f:(fun status_ledger ->
          let diff =
            Pre_diff_info.compute_statuses ~constraint_constants ~diff
              ~coinbase_amount ~coinbase_receiver ~ledger:status_ledger
              ~global_slot
              ~txn_state_view:(dummy_state_view ~global_slot ())
            |> Result.map_error ~f:Pre_diff_info.Error.to_error
            |> Or_error.ok_exn
          in
          Staged_ledger_diff.forget { diff } )

    let%test_unit "Invalid diff test: check zero fee excess for partitions" =
      let create_diff_with_non_zero_fee_excess ~ledger ~coinbase_amount
          ~global_slot txns completed_works
          (partition : Sl.Scan_state.Space_partition.t) : Staged_ledger_diff.t =
        (*With exact number of user commands in partition.first, the fee transfers that settle the fee_excess would be added to the next tree causing a non-zero fee excess*)
        let slots, job_count1 = partition.first in
        match partition.second with
        | None ->
            compute_statuses ~ledger ~coinbase_amount ~global_slot
            @@ ( { completed_works = List.take completed_works job_count1
                 ; commands = List.take txns slots
                 ; coinbase = Zero
                 ; internal_command_statuses = []
                 }
               , None )
        | Some (_, _) ->
            let txns_in_second_diff = List.drop txns slots in
            compute_statuses ~ledger ~coinbase_amount ~global_slot
              ( { completed_works = List.take completed_works job_count1
                ; commands = List.take txns slots
                ; coinbase = Zero
                ; internal_command_statuses = []
                }
              , Some
                  { completed_works =
                      ( if List.is_empty txns_in_second_diff then []
                      else List.drop completed_works job_count1 )
                  ; commands = txns_in_second_diff
                  ; coinbase = Zero
                  ; internal_command_statuses = []
                  } )
      in
      let empty_diff = Staged_ledger_diff.empty_diff in
      Quickcheck.test
        Quickcheck.Generator.(tuple2 gen_at_capacity small_positive_int)
        ~sexp_of:
          [%sexp_of:
            (Ledger.init_state * User_command.Valid.t list * int option list)
            * int]
        ~trials:10
        ~f:(fun ((ledger_init_state, cmds, iters), global_slot) ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl _test_mask ->
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
                          { Transaction_snark_work.Checked.fee = Fee.zero
                          ; proofs = proofs stmts
                          ; prover = snark_worker_pk
                          } )
                        work
                    in
                    let cmds_this_iter = cmds_this_iter |> Sequence.to_list in
                    let global_slot =
                      Mina_numbers.Global_slot_since_genesis.of_int global_slot
                    in
                    let diff =
                      create_diff_with_non_zero_fee_excess
                        ~ledger:(Sl.ledger !sl)
                        ~coinbase_amount:constraint_constants.coinbase_amount
                        ~global_slot cmds_this_iter work_done partitions
                    in
                    let current_state, current_view =
                      dummy_state_and_view ~global_slot ()
                    in
                    let state_hashes =
                      Mina_state.Protocol_state.hashes current_state
                    in
                    let%bind apply_res =
                      Sl.apply ~constraint_constants ~global_slot !sl diff
                        ~logger ~verifier ~current_state_view:current_view
                        ~state_and_body_hash:
                          ( state_hashes.state_hash
                          , state_hashes.state_body_hash |> Option.value_exn )
                        ~coinbase_receiver ~supercharge_coinbase:true
                    in
                    let checked', diff' =
                      match apply_res with
                      | Error (Sl.Staged_ledger_error.Non_zero_fee_excess _) ->
                          (true, empty_diff)
                      | Error err ->
                          failwith
                          @@ sprintf
                               !"Expecting Non-zero-fee-excess error, got \
                                 %{sexp: Sl.Staged_ledger_error.t}"
                               err
                      | Ok
                          ( `Hash_after_applying _hash
                          , `Ledger_proof _ledger_proof
                          , `Staged_ledger sl'
                          , `Pending_coinbase_update _ ) ->
                          sl := sl' ;
                          (false, diff)
                    in
                    return (diff', checked || checked') )
              in
              (*Note: if this fails, try increasing the number of trials to get a diff that does fail*)
              assert checked ) )

    let%test_unit "Provers can't pay the account creation fee" =
      let no_work_included (diff : Staged_ledger_diff.t) =
        List.is_empty (Staged_ledger_diff.completed_works diff)
      in
      let stmt_to_work stmts =
        let prover = stmt_to_prover stmts in
        Some
          { Transaction_snark_work.Checked.fee =
              Currency.Fee.(sub work_fee (of_nanomina_int_exn 1))
              |> Option.value_exn
          ; proofs = proofs stmts
          ; prover
          }
      in
      Quickcheck.test
        Quickcheck.Generator.(tuple2 (gen_below_capacity ()) small_positive_int)
        ~sexp_of:
          [%sexp_of:
            (Ledger.init_state * User_command.Valid.t list * int option list)
            * int]
        ~shrinker:
          (Quickcheck.Shrinker.create
             (fun ((init_state, cmds, iters), global_slot) ->
               if List.length iters > 1 then
                 Sequence.singleton
                   ( ( init_state
                     , List.take cmds (List.length cmds - transaction_capacity)
                     , [ None ] )
                   , global_slot )
               else Sequence.empty ) )
        ~trials:1
        ~f:(fun ((ledger_init_state, cmds, iters), global_slot) ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl _test_mask ->
              iter_cmds_acc cmds iters ()
                (fun _cmds_left _count_opt cmds_this_iter () ->
                  let diff =
                    let global_slot =
                      Mina_numbers.Global_slot_since_genesis.of_int global_slot
                    in
                    let current_state_view = dummy_state_view ~global_slot () in
                    let diff_result =
                      Sl.create_diff ~constraint_constants ~global_slot !sl
                        ~logger ~current_state_view
                        ~transactions_by_fee:cmds_this_iter
                        ~get_completed_work:stmt_to_work ~coinbase_receiver
                        ~supercharge_coinbase:true
                    in
                    match diff_result with
                    | Ok (diff, _invalid_txns) ->
                        Staged_ledger_diff.forget diff
                    | Error e ->
                        Error.raise (Pre_diff_info.Error.to_error e)
                  in
                  (*No proofs were purchased since the fee for the proofs are not sufficient to pay for account creation*)
                  assert (no_work_included diff) ;
                  Deferred.return (diff, ()) ) ) )

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
               Transaction_snark_work.Statement.compare s stmts = 0 ) )
      then
        Some
          { Transaction_snark_work.Checked.fee = work_fee
          ; proofs = proofs stmts
          ; prover
          }
      else None

    (** Like test_simple but with a random number of completed jobs available.
                   *)

    let test_random_number_of_proofs :
           global_slot:int
        -> Ledger.init_state
        -> User_command.Valid.t list
        -> int option list
        -> int list
        -> Sl.t ref
        -> Ledger.Mask.Attached.t
        -> [ `One_prover | `Many_provers ]
        -> unit Deferred.t =
     fun ~global_slot init_state cmds cmd_iters proofs_available sl test_mask
         provers ->
      let%map proofs_available_left =
        iter_cmds_acc cmds cmd_iters proofs_available
          (fun cmds_left _count_opt cmds_this_iter proofs_available_left ->
            let work_list : Transaction_snark_work.Statement.t list =
              Transaction_snark_scan_state.all_work_statements_exn
                !sl.scan_state
            in
            let proofs_available_this_iter =
              List.hd_exn proofs_available_left
            in
            let global_slot =
              Mina_numbers.Global_slot_since_genesis.of_int global_slot
            in
            let current_state, current_state_view =
              dummy_state_and_view ~global_slot ()
            in
            let state_and_body_hash =
              let state_hashes =
                Mina_state.Protocol_state.hashes current_state
              in
              ( state_hashes.state_hash
              , state_hashes.state_body_hash |> Option.value_exn )
            in
            let%map proof, diff =
              create_and_apply ~global_slot ~state_and_body_hash
                ~protocol_state_view:current_state_view sl cmds_this_iter
                (stmt_to_work_restricted
                   (List.take work_list proofs_available_this_iter)
                   provers )
            in
            assert_fee_excess proof ;
            let cmds_applied_this_iter =
              List.length @@ Staged_ledger_diff.commands diff
            in
            let cb = coinbase_count diff in
            assert (proofs_available_this_iter = 0 || cb > 0) ;
            ( match provers with
            | `One_prover ->
                assert (cb <= 1)
            | `Many_provers ->
                assert (cb <= 2) ) ;
            let coinbase_cost = coinbase_cost diff in
            assert_ledger test_mask ~coinbase_cost ~global_slot
              ~protocol_state_view:current_state_view !sl cmds_left
              cmds_applied_this_iter (init_pks init_state) ;
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
        let%map global_slot = Quickcheck.Generator.small_positive_int in
        (ledger_init_state, cmds, iters, proofs_available, global_slot)
      in
      Quickcheck.test g ~trials:10
        ~f:(fun (ledger_init_state, cmds, iters, proofs_available, global_slot)
           ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl test_mask ->
              test_random_number_of_proofs ~global_slot ledger_init_state cmds
                iters proofs_available sl test_mask `Many_provers ) )

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
        let%map global_slot = Quickcheck.Generator.small_positive_int in
        (ledger_init_state, cmds, iters, proofs_available, global_slot)
      in
      let shrinker =
        Quickcheck.Shrinker.create
          (fun (ledger_init_state, cmds, iters, proofs_available, global_slot)
          ->
            let all_but_last xs = List.take xs (List.length xs - 1) in
            let iter_count = List.length iters in
            let mod_iters iters' =
              ( ledger_init_state
              , List.take cmds
                @@ List.sum (module Int) iters' ~f:(Option.value ~default:0)
              , iters'
              , List.take proofs_available (List.length iters')
              , global_slot )
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
            List.filter_map [ half_iters; one_less_iters ] ~f:Fn.id
            |> Sequence.of_list )
      in
      Quickcheck.test g ~shrinker ~shrink_attempts:`Exhaustive
        ~sexp_of:
          [%sexp_of:
            Ledger.init_state
            * User_command.Valid.t list
            * int option list
            * int list
            * int] ~trials:50
        ~f:(fun (ledger_init_state, cmds, iters, proofs_available, global_slot)
           ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl test_mask ->
              test_random_number_of_proofs ~global_slot ledger_init_state cmds
                iters proofs_available sl test_mask `Many_provers ) )

    let%test_unit "Random number of commands-random number of proofs-one \
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
        let%map global_slot = Quickcheck.Generator.small_positive_int in
        (ledger_init_state, cmds, iters, proofs_available, global_slot)
      in
      Quickcheck.test g ~trials:10
        ~f:(fun (ledger_init_state, cmds, iters, proofs_available, global_slot)
           ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl test_mask ->
              test_random_number_of_proofs ~global_slot ledger_init_state cmds
                iters proofs_available sl test_mask `One_prover ) )

    let stmt_to_work_random_fee work_list provers
        (stmts : Transaction_snark_work.Statement.t) :
        Transaction_snark_work.Checked.t option =
      let prover =
        match provers with
        | `Many_provers ->
            stmt_to_prover stmts
        | `One_prover ->
            snark_worker_pk
      in
      Option.map
        (List.find work_list ~f:(fun (s, _) ->
             Transaction_snark_work.Statement.compare s stmts = 0 ) )
        ~f:(fun (_, fee) ->
          { Transaction_snark_work.Checked.fee; proofs = proofs stmts; prover }
          )

    (** Like test_random_number_of_proofs but with random proof fees.
                   *)
    let test_random_proof_fee :
           global_slot:int
        -> Ledger.init_state
        -> User_command.Valid.t list
        -> int option list
        -> (int * Fee.t list) list
        -> Sl.t ref
        -> Ledger.Mask.Attached.t
        -> [ `One_prover | `Many_provers ]
        -> unit Deferred.t =
     fun ~global_slot _init_state cmds cmd_iters proofs_available sl _test_mask
         provers ->
      let%map proofs_available_left =
        iter_cmds_acc cmds cmd_iters proofs_available
          (fun _cmds_left _count_opt cmds_this_iter proofs_available_left ->
            let work_list : Transaction_snark_work.Statement.t list =
              Sl.Scan_state.work_statements_for_new_diff (Sl.scan_state !sl)
            in
            let proofs_available_this_iter, fees_for_each =
              List.hd_exn proofs_available_left
            in
            let work_to_be_done =
              let work_list = List.take work_list proofs_available_this_iter in
              List.(zip_exn work_list (take fees_for_each (length work_list)))
            in
            let global_slot =
              Mina_numbers.Global_slot_since_genesis.of_int global_slot
            in
            let current_state, current_state_view =
              dummy_state_and_view ~global_slot ()
            in
            let state_and_body_hash =
              let state_hashes =
                Mina_state.Protocol_state.hashes current_state
              in
              ( state_hashes.state_hash
              , state_hashes.state_body_hash |> Option.value_exn )
            in
            let%map _proof, diff =
              create_and_apply ~global_slot
                ~protocol_state_view:current_state_view ~state_and_body_hash sl
                cmds_this_iter
                (stmt_to_work_random_fee work_to_be_done provers)
            in
            let sorted_work_from_diff1
                (pre_diff :
                  Staged_ledger_diff.Pre_diff_with_at_most_two_coinbase.t ) =
              List.sort pre_diff.completed_works ~compare:(fun w w' ->
                  Fee.compare w.fee w'.fee )
            in
            let sorted_work_from_diff2
                (pre_diff :
                  Staged_ledger_diff.Pre_diff_with_at_most_one_coinbase.t option
                  ) =
              Option.value_map pre_diff ~default:[] ~f:(fun p ->
                  List.sort p.completed_works ~compare:(fun w w' ->
                      Fee.compare w.fee w'.fee ) )
            in
            let () =
              let assert_same_fee { Coinbase.Fee_transfer.fee; _ } fee' =
                assert (Fee.equal fee fee')
              in
              let first_pre_diff, second_pre_diff_opt = diff.diff in
              match
                ( first_pre_diff.coinbase
                , Option.value_map second_pre_diff_opt
                    ~default:Staged_ledger_diff.At_most_one.Zero ~f:(fun d ->
                      d.coinbase ) )
              with
              | ( Staged_ledger_diff.At_most_two.Zero
                , Staged_ledger_diff.At_most_one.Zero )
              | Two None, Zero ->
                  ()
              | One ft_opt, Zero ->
                  Option.value_map ft_opt ~default:() ~f:(fun single ->
                      let work =
                        List.hd_exn (sorted_work_from_diff1 first_pre_diff)
                        |> Transaction_snark_work.forget
                      in
                      assert_same_fee single work.fee )
              | Zero, One ft_opt ->
                  Option.value_map ft_opt ~default:() ~f:(fun single ->
                      let work =
                        List.hd_exn (sorted_work_from_diff2 second_pre_diff_opt)
                        |> Transaction_snark_work.forget
                      in
                      assert_same_fee single work.fee )
              | Two (Some (ft, ft_opt)), Zero ->
                  let work_done = sorted_work_from_diff1 first_pre_diff in
                  let work =
                    List.hd_exn work_done |> Transaction_snark_work.forget
                  in
                  assert_same_fee ft work.fee ;
                  Option.value_map ft_opt ~default:() ~f:(fun single ->
                      let work =
                        List.hd_exn (List.drop work_done 1)
                        |> Transaction_snark_work.forget
                      in
                      assert_same_fee single work.fee )
              | _ ->
                  failwith
                    (sprintf
                       !"Incorrect coinbase in the diff %{sexp: \
                         Staged_ledger_diff.t}"
                       diff )
            in
            (diff, List.tl_exn proofs_available_left) )
      in
      assert (List.is_empty proofs_available_left)

    let%test_unit "max throughput-random-random fee-number of proofs-worst \
                   case provers" =
      (* Always at worst case number of provers *)
      let g =
        let open Quickcheck.Generator.Let_syntax in
        let%bind ledger_init_state, cmds, iters = gen_at_capacity in
        (* How many proofs will be available at each iteration. *)
        let%bind proofs_available =
          Quickcheck_lib.map_gens iters ~f:(fun _ ->
              let%bind number_of_proofs =
                Int.gen_incl 0 (transaction_capacity * 2)
              in
              let%map fees =
                Quickcheck.Generator.list_with_length number_of_proofs
                  Fee.(
                    gen_incl (of_nanomina_int_exn 1) (of_nanomina_int_exn 20))
              in
              (number_of_proofs, fees) )
        in
        let%map global_slot = Quickcheck.Generator.small_positive_int in
        (ledger_init_state, cmds, iters, proofs_available, global_slot)
      in
      Quickcheck.test g ~trials:10
        ~f:(fun (ledger_init_state, cmds, iters, proofs_available, global_slot)
           ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl test_mask ->
              test_random_proof_fee ~global_slot ledger_init_state cmds iters
                proofs_available sl test_mask `Many_provers ) )

    let%test_unit "Max throughput-random fee" =
      let g =
        let open Quickcheck.Generator.Let_syntax in
        let%bind ledger_init_state, cmds, iters = gen_at_capacity in
        let%bind proofs_available =
          Quickcheck_lib.map_gens iters ~f:(fun _ ->
              let number_of_proofs =
                transaction_capacity
                (*All proofs are available*)
              in
              let%map fees =
                Quickcheck.Generator.list_with_length number_of_proofs
                  Fee.(
                    gen_incl (of_nanomina_int_exn 1) (of_nanomina_int_exn 20))
              in
              (number_of_proofs, fees) )
        in
        let%map global_slot = Quickcheck.Generator.small_positive_int in
        (ledger_init_state, cmds, iters, proofs_available, global_slot)
      in
      Quickcheck.test g
        ~sexp_of:
          [%sexp_of:
            Ledger.init_state
            * Mina_base.User_command.Valid.t list
            * int option list
            * (int * Fee.t list) list
            * int] ~trials:10
        ~f:(fun (ledger_init_state, cmds, iters, proofs_available, global_slot)
           ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl test_mask ->
              test_random_proof_fee ~global_slot ledger_init_state cmds iters
                proofs_available sl test_mask `Many_provers ) )

    let check_pending_coinbase ~supercharge_coinbase proof ~sl_before ~sl_after
        (_state_hash, state_body_hash) global_slot pc_update ~is_new_stack =
      let pending_coinbase_before = Sl.pending_coinbase_collection sl_before in
      let root_before = Pending_coinbase.merkle_root pending_coinbase_before in
      let unchecked_root_after =
        Pending_coinbase.merkle_root (Sl.pending_coinbase_collection sl_after)
      in
      let f_pop_and_add () =
        let open Snark_params.Tick in
        let open Pending_coinbase in
        let proof_emitted =
          if Option.is_some proof then Boolean.true_ else Boolean.false_
        in
        let%bind root_after_popping, _deleted_stack =
          Pending_coinbase.Checked.pop_coinbases ~constraint_constants
            ~proof_emitted
            (Hash.var_of_t root_before)
        in
        let pc_update_var = Update.var_of_t pc_update in
        let coinbase_receiver =
          Public_key.Compressed.(var_of_t coinbase_receiver)
        in
        let supercharge_coinbase = Boolean.var_of_value supercharge_coinbase in
        let state_body_hash_var = State_body_hash.var_of_t state_body_hash in
        let global_slot_var =
          Mina_numbers.Global_slot_since_genesis.Checked.constant global_slot
        in
        Pending_coinbase.Checked.add_coinbase ~constraint_constants
          root_after_popping pc_update_var ~coinbase_receiver
          ~supercharge_coinbase state_body_hash_var global_slot_var
      in
      let checked_root_after_update =
        let open Snark_params.Tick in
        let open Pending_coinbase in
        let comp =
          let%map result =
            handle f_pop_and_add
              (unstage
                 (handler ~depth:constraint_constants.pending_coinbase_depth
                    pending_coinbase_before ~is_new_stack ) )
          in
          As_prover.read Hash.typ result
        in
        let x = Or_error.ok_exn (run_and_check comp) in
        x
      in
      [%test_eq: Pending_coinbase.Hash.t] unchecked_root_after
        checked_root_after_update

    let test_pending_coinbase :
           global_slot:int
        -> Ledger.init_state
        -> User_command.Valid.t list
        -> int option list
        -> int list
        -> Sl.t ref
        -> Ledger.Mask.Attached.t
        -> [ `One_prover | `Many_provers ]
        -> unit Deferred.t =
     fun ~global_slot init_state cmds cmd_iters proofs_available sl test_mask
         provers ->
      let global_slot =
        Mina_numbers.Global_slot_since_genesis.of_int global_slot
      in
      let%map proofs_available_left, _ =
        iter_cmds_acc cmds cmd_iters (proofs_available, global_slot)
          (fun
            cmds_left
            _count_opt
            cmds_this_iter
            (proofs_available_left, global_slot)
          ->
            let work_list : Transaction_snark_work.Statement.t list =
              Sl.Scan_state.all_work_statements_exn !sl.scan_state
            in
            let proofs_available_this_iter =
              List.hd_exn proofs_available_left
            in
            let sl_before = !sl in
            let current_state, current_state_view =
              dummy_state_and_view ~global_slot ()
            in
            let state_and_body_hash =
              let state_hashes =
                Mina_state.Protocol_state.hashes current_state
              in
              ( state_hashes.state_hash
              , state_hashes.state_body_hash |> Option.value_exn )
            in
            let%map proof, diff, is_new_stack, pc_update, supercharge_coinbase =
              create_and_apply_with_state_body_hash ~current_state_view
                ~global_slot ~state_and_body_hash sl cmds_this_iter
                (stmt_to_work_restricted
                   (List.take work_list proofs_available_this_iter)
                   provers )
            in
            check_pending_coinbase proof ~supercharge_coinbase ~sl_before
              ~sl_after:!sl state_and_body_hash global_slot pc_update
              ~is_new_stack ;
            assert_fee_excess proof ;
            let cmds_applied_this_iter =
              List.length @@ Staged_ledger_diff.commands diff
            in
            let cb = coinbase_count diff in
            assert (proofs_available_this_iter = 0 || cb > 0) ;
            ( match provers with
            | `One_prover ->
                assert (cb <= 1)
            | `Many_provers ->
                assert (cb <= 2) ) ;
            let coinbase_cost = coinbase_cost diff in
            assert_ledger test_mask ~coinbase_cost ~global_slot
              ~protocol_state_view:current_state_view !sl cmds_left
              cmds_applied_this_iter (init_pks init_state) ;
            ( diff
            , ( List.tl_exn proofs_available_left
              , Mina_numbers.Global_slot_since_genesis.succ global_slot ) ) )
      in
      assert (List.is_empty proofs_available_left)

    let pending_coinbase_test prover =
      let g =
        let open Quickcheck.Generator.Let_syntax in
        let%bind ledger_init_state, cmds, iters =
          gen_below_capacity ~extra_blocks:true ()
        in
        let%bind proofs_available =
          Quickcheck_lib.map_gens iters ~f:(fun cmds_opt ->
              Int.gen_incl 0 (3 * Option.value_exn cmds_opt) )
        in
        let%map global_slot = Quickcheck.Generator.small_positive_int in
        (ledger_init_state, cmds, iters, proofs_available, global_slot)
      in
      Quickcheck.test g ~trials:5
        ~f:(fun (ledger_init_state, cmds, iters, proofs_available, global_slot)
           ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl test_mask ->
              test_pending_coinbase ~global_slot ledger_init_state cmds iters
                proofs_available sl test_mask prover ) )

    let%test_unit "Validate pending coinbase for random number of \
                   commands-random number of proofs-one prover)" =
      pending_coinbase_test `One_prover

    let%test_unit "Validate pending coinbase for random number of \
                   commands-random number of proofs-many provers)" =
      pending_coinbase_test `Many_provers

    let timed_account n =
      let keypair =
        Quickcheck.random_value
          ~seed:(`Deterministic (sprintf "timed_account_%d" n))
          Keypair.gen
      in
      let account_id =
        Account_id.create
          (Public_key.compress keypair.public_key)
          Token_id.default
      in
      let balance = Balance.of_mina_int_exn 100 in
      (*Should fully vest by slot = 7*)
      let acc =
        Account.create_timed account_id balance ~initial_minimum_balance:balance
          ~cliff_time:(Mina_numbers.Global_slot_since_genesis.of_int 4)
          ~cliff_amount:Amount.zero
          ~vesting_period:(Mina_numbers.Global_slot_span.of_int 2)
          ~vesting_increment:(Amount.of_mina_int_exn 50)
        |> Or_error.ok_exn
      in
      (keypair, acc)

    let untimed_account n =
      let keypair =
        Quickcheck.random_value
          ~seed:(`Deterministic (sprintf "untimed_account_%d" n))
          Keypair.gen
      in
      let account_id =
        Account_id.create
          (Public_key.compress keypair.public_key)
          Token_id.default
      in
      let balance = Balance.of_mina_int_exn 100 in
      let acc = Account.create account_id balance in
      (keypair, acc)

    let supercharge_coinbase_test ~(self : Account.t) ~(delegator : Account.t)
        ~block_count f_expected_balance sl =
      let coinbase_receiver = self in
      let init_balance = coinbase_receiver.balance in
      let check_receiver_account sl count =
        let location =
          Ledger.location_of_account (Sl.ledger sl)
            (Account.identifier coinbase_receiver)
          |> Option.value_exn
        in
        let account = Ledger.get (Sl.ledger sl) location |> Option.value_exn in
        [%test_eq: Balance.t]
          (f_expected_balance count init_balance)
          account.balance
      in
      Deferred.List.iter
        (List.init block_count ~f:(( + ) 1))
        ~f:(fun block_count ->
          let global_slot =
            Mina_numbers.Global_slot_since_genesis.of_int block_count
          in
          let current_state, current_state_view =
            dummy_state_and_view ~global_slot ()
          in
          let state_and_body_hash =
            let state_hashes = Mina_state.Protocol_state.hashes current_state in
            ( state_hashes.state_hash
            , state_hashes.state_body_hash |> Option.value_exn )
          in
          let%bind _ =
            create_and_apply_with_state_body_hash ~winner:delegator.public_key
              ~coinbase_receiver:coinbase_receiver.public_key sl
              ~current_state_view
              ~global_slot:
                (Mina_numbers.Global_slot_since_genesis.of_int block_count)
              ~state_and_body_hash Sequence.empty
              (stmt_to_work_zero_fee ~prover:self.public_key)
          in
          check_receiver_account !sl block_count ;
          return () )

    let normal_coinbase = constraint_constants.coinbase_amount

    let scale_exn amt i = Amount.scale amt i |> Option.value_exn

    let supercharged_coinbase =
      scale_exn constraint_constants.coinbase_amount
        constraint_constants.supercharged_coinbase_factor

    let g = Ledger.gen_initial_ledger_state

    let%test_unit "Supercharged coinbase - staking" =
      let keypair_self, self = timed_account 1 in
      let slots_with_locked_tokens =
        7
        (*calculated from the timing values for timed_accounts*)
      in
      let block_count = slots_with_locked_tokens + 5 in
      let f_expected_balance block_no init_balance =
        if block_no <= slots_with_locked_tokens then
          Balance.add_amount init_balance (scale_exn normal_coinbase block_no)
          |> Option.value_exn
        else
          (* init balance +
                (normal_coinbase * slots_with_locked_tokens) +
                (supercharged_coinbase * remaining slots))*)
          Balance.add_amount
            ( Balance.add_amount init_balance
                (scale_exn normal_coinbase slots_with_locked_tokens)
            |> Option.value_exn )
            (scale_exn supercharged_coinbase
               (block_no - slots_with_locked_tokens) )
          |> Option.value_exn
      in
      Quickcheck.test g ~trials:1 ~f:(fun ledger_init_state ->
          let ledger_init_state =
            Array.append
              [| ( keypair_self
                 , Balance.to_amount self.balance
                 , self.nonce
                 , self.timing )
              |]
              ledger_init_state
          in
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl _test_mask ->
              supercharge_coinbase_test ~self ~delegator:self ~block_count
                f_expected_balance sl ) )

    let%test_unit "Supercharged coinbase - unlocked account delegating to \
                   locked account" =
      let keypair_self, locked_self = timed_account 1 in
      let keypair_delegator, unlocked_delegator = untimed_account 1 in
      let slots_with_locked_tokens =
        7
        (*calculated from the timing values for timed_accounts*)
      in
      let block_count = slots_with_locked_tokens + 2 in
      let f_expected_balance block_no init_balance =
        Balance.add_amount init_balance
          (scale_exn supercharged_coinbase block_no)
        |> Option.value_exn
      in
      Quickcheck.test g ~trials:1 ~f:(fun ledger_init_state ->
          let ledger_init_state =
            Array.append
              [| ( keypair_self
                 , Balance.to_amount locked_self.balance
                 , locked_self.nonce
                 , locked_self.timing )
               ; ( keypair_delegator
                 , Balance.to_amount unlocked_delegator.balance
                 , unlocked_delegator.nonce
                 , unlocked_delegator.timing )
              |]
              ledger_init_state
          in
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl _test_mask ->
              supercharge_coinbase_test ~self:locked_self
                ~delegator:unlocked_delegator ~block_count f_expected_balance sl ) )

    let%test_unit "Supercharged coinbase - locked account delegating to \
                   unlocked account" =
      let keypair_self, unlocked_self = untimed_account 1 in
      let keypair_delegator, locked_delegator = timed_account 1 in
      let slots_with_locked_tokens =
        7
        (*calculated from the timing values for the timed_account*)
      in
      let block_count = slots_with_locked_tokens + 2 in
      let f_expected_balance block_no init_balance =
        if block_no <= slots_with_locked_tokens then
          Balance.add_amount init_balance (scale_exn normal_coinbase block_no)
          |> Option.value_exn
        else
          (* init balance +
                (normal_coinbase * slots_with_locked_tokens) +
                (supercharged_coinbase * remaining slots))*)
          Balance.add_amount
            ( Balance.add_amount init_balance
                (scale_exn normal_coinbase slots_with_locked_tokens)
            |> Option.value_exn )
            (scale_exn supercharged_coinbase
               (block_no - slots_with_locked_tokens) )
          |> Option.value_exn
      in
      Quickcheck.test g ~trials:1 ~f:(fun ledger_init_state ->
          let ledger_init_state =
            Array.append
              [| ( keypair_self
                 , Balance.to_amount unlocked_self.balance
                 , unlocked_self.nonce
                 , unlocked_self.timing )
               ; ( keypair_delegator
                 , Balance.to_amount locked_delegator.balance
                 , locked_delegator.nonce
                 , locked_delegator.timing )
              |]
              ledger_init_state
          in
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl _test_mask ->
              supercharge_coinbase_test ~self:unlocked_self
                ~delegator:locked_delegator ~block_count f_expected_balance sl ) )

    let%test_unit "Supercharged coinbase - locked account delegating to locked \
                   account" =
      let keypair_self, locked_self = timed_account 1 in
      let keypair_delegator, locked_delegator = timed_account 2 in
      let slots_with_locked_tokens =
        7
        (*calculated from the timing values for timed_accounts*)
      in
      let block_count = slots_with_locked_tokens in
      let f_expected_balance block_no init_balance =
        (*running the test as long as both the accounts remain locked and hence normal coinbase in all the blocks*)
        Balance.add_amount init_balance (scale_exn normal_coinbase block_no)
        |> Option.value_exn
      in
      Quickcheck.test g ~trials:1 ~f:(fun ledger_init_state ->
          let ledger_init_state =
            Array.append
              [| ( keypair_self
                 , Balance.to_amount locked_self.balance
                 , locked_self.nonce
                 , locked_self.timing )
               ; ( keypair_delegator
                 , Balance.to_amount locked_delegator.balance
                 , locked_delegator.nonce
                 , locked_delegator.timing )
              |]
              ledger_init_state
          in
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl _test_mask ->
              supercharge_coinbase_test ~self:locked_self
                ~delegator:locked_delegator ~block_count f_expected_balance sl ) )

    let command_insufficient_funds =
      let open Quickcheck.Generator.Let_syntax in
      let%map ledger_init_state = Ledger.gen_initial_ledger_state
      and global_slot = Quickcheck.Generator.small_positive_int in
      let kp, balance, nonce, _ = ledger_init_state.(0) in
      let receiver_pk =
        Quickcheck.random_value ~seed:(`Deterministic "receiver_pk")
          Public_key.Compressed.gen
      in
      let insufficient_account_creation_fee =
        Currency.Fee.to_nanomina_int constraint_constants.account_creation_fee
        / 2
        |> Currency.Amount.of_nanomina_int_exn
      in
      let source_pk = Public_key.compress kp.public_key in
      let body =
        Signed_command_payload.Body.Payment
          Payment_payload.Poly.
            { receiver_pk; amount = insufficient_account_creation_fee }
      in
      let fee = Currency.Amount.to_fee balance in
      let payload =
        Signed_command.Payload.create ~fee ~fee_payer_pk:source_pk ~nonce
          ~memo:Signed_command_memo.dummy ~valid_until:None ~body
      in
      let signed_command =
        User_command.Signed_command (Signed_command.sign kp payload)
      in
      (ledger_init_state, signed_command, global_slot)

    let%test_unit "Commands with Insufficient funds are not included" =
      let logger = Logger.null () in
      Quickcheck.test command_insufficient_funds ~trials:1
        ~f:(fun (ledger_init_state, invalid_command, global_slot) ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl _test_mask ->
              let global_slot =
                Mina_numbers.Global_slot_since_genesis.of_int global_slot
              in
              let current_state_view = dummy_state_view ~global_slot () in
              let diff_result =
                Sl.create_diff ~constraint_constants ~global_slot !sl ~logger
                  ~current_state_view
                  ~transactions_by_fee:(Sequence.of_list [ invalid_command ])
                  ~get_completed_work:(stmt_to_work_zero_fee ~prover:self_pk)
                  ~coinbase_receiver ~supercharge_coinbase:false
              in
              ( match diff_result with
              | Ok (diff, _invalid_txns) ->
                  assert (
                    List.is_empty
                      (Staged_ledger_diff.With_valid_signatures_and_proofs
                       .commands diff ) )
              | Error e ->
                  Error.raise (Pre_diff_info.Error.to_error e) ) ;
              Deferred.unit ) )

    let%test_unit "Blocks having commands with insufficient funds are rejected"
        =
      let logger = Logger.create () in
      let g =
        let open Quickcheck.Generator.Let_syntax in
        let%map ledger_init_state = Ledger.gen_initial_ledger_state
        and global_slot = Quickcheck.Generator.small_positive_int in
        let command (kp : Keypair.t) (balance : Currency.Amount.t)
            (nonce : Account.Nonce.t) (validity : [ `Valid | `Invalid ]) =
          let receiver_pk =
            Quickcheck.random_value ~seed:(`Deterministic "receiver_pk")
              Public_key.Compressed.gen
          in
          let account_creation_fee, fee =
            match validity with
            | `Valid ->
                let account_creation_fee =
                  constraint_constants.account_creation_fee
                  |> Currency.Amount.of_fee
                in
                ( account_creation_fee
                , Currency.Amount.to_fee
                    ( Currency.Amount.sub balance account_creation_fee
                    |> Option.value_exn ) )
            | `Invalid ->
                (* Not enough account creation fee and using full balance for fee*)
                ( Currency.Fee.to_nanomina_int
                    constraint_constants.account_creation_fee
                  / 2
                  |> Currency.Amount.of_nanomina_int_exn
                , Currency.Amount.to_fee balance )
          in
          let fee_payer_pk = Public_key.compress kp.public_key in
          let body =
            Signed_command_payload.Body.Payment
              Payment_payload.Poly.
                { receiver_pk; amount = account_creation_fee }
          in
          let payload =
            Signed_command.Payload.create ~fee ~fee_payer_pk ~nonce
              ~memo:Signed_command_memo.dummy ~valid_until:None ~body
          in
          User_command.Signed_command (Signed_command.sign kp payload)
        in
        let signed_command =
          let kp, balance, nonce, _ = ledger_init_state.(0) in
          command kp balance nonce `Valid
        in
        let invalid_command =
          let kp, balance, nonce, _ = ledger_init_state.(1) in
          command kp balance nonce `Invalid
        in
        (ledger_init_state, signed_command, invalid_command, global_slot)
      in
      Quickcheck.test g ~trials:1
        ~f:(fun (ledger_init_state, valid_command, invalid_command, global_slot)
           ->
          async_with_ledgers ledger_init_state
            (fun ~snarked_ledger:_ sl _test_mask ->
              let global_slot =
                Mina_numbers.Global_slot_since_genesis.of_int global_slot
              in
              let current_state, current_state_view =
                dummy_state_and_view ~global_slot ()
              in
              let state_and_body_hash =
                let state_hashes =
                  Mina_state.Protocol_state.hashes current_state
                in
                ( state_hashes.state_hash
                , state_hashes.state_body_hash |> Option.value_exn )
              in
              let diff_result =
                Sl.create_diff ~constraint_constants ~global_slot !sl ~logger
                  ~current_state_view
                  ~transactions_by_fee:(Sequence.of_list [ valid_command ])
                  ~get_completed_work:(stmt_to_work_zero_fee ~prover:self_pk)
                  ~coinbase_receiver ~supercharge_coinbase:false
              in
              match diff_result with
              | Error e ->
                  Error.raise (Pre_diff_info.Error.to_error e)
              | Ok (diff, _invalid_txns) -> (
                  assert (
                    List.length
                      (Staged_ledger_diff.With_valid_signatures_and_proofs
                       .commands diff )
                    = 1 ) ;
                  let f, s = diff.diff in
                  [%log info] "Diff %s"
                    ( Staged_ledger_diff.With_valid_signatures_and_proofs
                      .to_yojson diff
                    |> Yojson.Safe.to_string ) ;
                  let failed_command =
                    With_status.
                      { data = invalid_command
                      ; status =
                          Transaction_status.Failed
                            Transaction_status.Failure.(
                              Collection.of_single_failure
                                Amount_insufficient_to_create_account)
                      }
                  in
                  (*Replace the valid command with an invalid command)*)
                  let diff =
                    { Staged_ledger_diff.With_valid_signatures_and_proofs.diff =
                        ({ f with commands = [ failed_command ] }, s)
                    }
                  in
                  let%map res =
                    Sl.apply ~constraint_constants ~global_slot !sl
                      (Staged_ledger_diff.forget diff)
                      ~logger ~verifier ~current_state_view ~state_and_body_hash
                      ~coinbase_receiver ~supercharge_coinbase:false
                  in
                  match res with
                  | Ok _x ->
                      assert false
                  (*TODO: check transaction logic errors here. Verified that the error is here is [The source account has an insufficient balance]*)
                  | Error (Staged_ledger_error.Unexpected _ as e) ->
                      [%log info] "Error %s" (Staged_ledger_error.to_string e) ;
                      assert true
                  | Error _ ->
                      assert false ) ) )

    let%test_unit "Mismatched verification keys in zkApp accounts and \
                   transactions" =
      let open Transaction_snark.For_tests in
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let%bind test_spec = Mina_transaction_logic.For_tests.Test_spec.gen in
        let pks =
          Public_key.Compressed.Set.of_list
            (List.map (Array.to_list test_spec.init_ledger) ~f:(fun s ->
                 Public_key.compress (fst s).public_key ) )
        in
        let%map kp =
          Quickcheck.Generator.filter Keypair.gen ~f:(fun kp ->
              not
                (Public_key.Compressed.Set.mem pks
                   (Public_key.compress kp.public_key) ) )
        and global_slot = Quickcheck.Generator.small_positive_int in
        (test_spec, kp, global_slot)
      in
      Quickcheck.test ~trials:1 gen
        ~f:(fun ({ init_ledger; specs = _ }, new_kp, global_slot) ->
          let fee = Fee.of_nanomina_int_exn 1_000_000 in
          let amount = Amount.of_mina_int_exn 10 in
          let snapp_pk = Signature_lib.Public_key.compress new_kp.public_key in
          let snapp_update =
            { Account_update.Update.dummy with
              delegate = Zkapp_basic.Set_or_keep.Set snapp_pk
            }
          in
          let memo = Signed_command_memo.dummy in
          let test_spec : Update_states_spec.t =
            { sender = (new_kp, Mina_base.Account.Nonce.zero)
            ; fee
            ; fee_payer = None
            ; receivers = []
            ; amount
            ; zkapp_account_keypairs = [ new_kp ]
            ; memo
            ; new_zkapp_account = false
            ; snapp_update
            ; current_auth = Permissions.Auth_required.Proof
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
            ; preconditions = None
            }
          in
          Ledger.with_ledger ~depth:constraint_constants.ledger_depth
            ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Mina_transaction_logic.For_tests.Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  (* create a zkApp account *)
                  let snapp_permissions =
                    let default = Permissions.user_default in
                    { default with
                      set_delegate = Permissions.Auth_required.Proof
                    }
                  in
                  let snapp_account_id =
                    Account_id.create snapp_pk Token_id.default
                  in
                  let dummy_vk =
                    let data = Pickles.Side_loaded.Verification_key.dummy in
                    let hash = Zkapp_account.digest_vk data in
                    ({ data; hash } : _ With_hash.t)
                  in
                  let valid_against_ledger =
                    let new_mask =
                      Ledger.Mask.create ~depth:(Ledger.depth ledger) ()
                    in
                    let l = Ledger.register_mask ledger new_mask in
                    Transaction_snark.For_tests.create_trivial_zkapp_account
                      ~permissions:snapp_permissions ~vk ~ledger:l snapp_pk ;
                    l
                  in
                  let%bind zkapp_command =
                    let zkapp_prover_and_vk = (zkapp_prover, vk) in
                    Transaction_snark.For_tests.update_states
                      ~zkapp_prover_and_vk ~constraint_constants test_spec
                  in
                  let valid_zkapp_command =
                    Or_error.ok_exn
                      (Zkapp_command.Valid.to_valid ~status:Applied
                         ~find_vk:
                           (Zkapp_command.Verifiable.find_vk_via_ledger
                              ~ledger:valid_against_ledger ~get:Ledger.get
                              ~location_of_account:Ledger.location_of_account )
                         zkapp_command )
                  in
                  ignore
                    (Ledger.unregister_mask_exn valid_against_ledger
                       ~loc:__LOC__ ) ;
                  (*Different key in the staged ledger*)
                  Transaction_snark.For_tests.create_trivial_zkapp_account
                    ~permissions:snapp_permissions ~vk:dummy_vk ~ledger snapp_pk ;
                  let open Async.Deferred.Let_syntax in
                  let sl = ref @@ Sl.create_exn ~constraint_constants ~ledger in
                  let global_slot =
                    Mina_numbers.Global_slot_since_genesis.of_int global_slot
                  in
                  let failed_zkapp_command =
                    Or_error.ok_exn
                      (Zkapp_command.Valid.to_valid
                         ~status:
                           Transaction_status.(
                             Failed
                               [ []
                               ; [ Failure.Unexpected_verification_key_hash ]
                               ])
                         ~find_vk:
                           (Zkapp_command.Verifiable.find_vk_via_ledger ~ledger
                              ~get:Ledger.get
                              ~location_of_account:Ledger.location_of_account )
                         zkapp_command )
                  in
                  let current_state, current_state_view =
                    dummy_state_and_view ~global_slot ()
                  in
                  let state_and_body_hash =
                    let state_hashes =
                      Mina_state.Protocol_state.hashes current_state
                    in
                    ( state_hashes.state_hash
                    , state_hashes.state_body_hash |> Option.value_exn )
                  in
                  let%bind _proof, diff =
                    create_and_apply ~global_slot ~state_and_body_hash
                      ~protocol_state_view:current_state_view sl
                      (Sequence.singleton
                         (User_command.Zkapp_command failed_zkapp_command) )
                      stmt_to_work_one_prover
                  in
                  let command =
                    Staged_ledger_diff.commands diff |> List.hd_exn
                  in
                  (*Zkapp_command with incompatible vk is added with failed status*)
                  ( match command.status with
                  | Failed failure_tbl ->
                      let failures = List.concat failure_tbl in
                      assert (not (List.is_empty failures)) ;
                      let failed_as_expected =
                        List.fold failures ~init:false ~f:(fun acc f ->
                            acc
                            || Mina_base.Transaction_status.Failure.(
                                 equal Unexpected_verification_key_hash f) )
                      in
                      assert failed_as_expected
                  | Applied ->
                      failwith
                        "expected zkapp command to fail due to vk mismatch" ) ;
                  (*Update the account to have correct vk*)
                  let loc =
                    Option.value_exn
                      (Ledger.location_of_account ledger snapp_account_id)
                  in
                  let account = Option.value_exn (Ledger.get ledger loc) in
                  Ledger.set ledger loc
                    { account with
                      zkapp =
                        Some
                          { (Option.value_exn account.zkapp) with
                            verification_key = Some vk
                          }
                    } ;
                  let sl = ref @@ Sl.create_exn ~constraint_constants ~ledger in
                  let%bind _proof, diff =
                    create_and_apply sl ~global_slot ~state_and_body_hash
                      ~protocol_state_view:current_state_view
                      (Sequence.singleton
                         (User_command.Zkapp_command valid_zkapp_command) )
                      stmt_to_work_one_prover
                  in
                  let commands = Staged_ledger_diff.commands diff in
                  assert (List.length commands = 1) ;
                  match List.hd_exn commands with
                  | { With_status.data = Zkapp_command _ps; status = Applied }
                    ->
                      return ()
                  | { With_status.data = Zkapp_command _ps
                    ; status = Failed tbl
                    } ->
                      failwith
                        (sprintf "Zkapp_command application failed %s"
                           ( Transaction_status.Failure.Collection.to_yojson tbl
                           |> Yojson.Safe.to_string ) )
                  | _ ->
                      failwith "expecting zkapp_command transaction" ) ) )
  end )
