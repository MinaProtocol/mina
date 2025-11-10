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
      | ZkApps_exceed_limit of int * int
      | Unexpected of Error.t
    [@@deriving sexp_of]

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
      | ZkApps_exceed_limit (count, limit) ->
          Format.asprintf
            !"There are %{sexp: int} ZkApps in the block when there is a \
              configured limit of %{sexp: int}"
            count limit
      | Unexpected e ->
          Error.to_string_hum e

    let to_error = Fn.compose Error.of_string to_string
  end

  let to_staged_ledger_or_error = function
    | Ok a ->
        Ok a
    | Error e ->
        Error (Staged_ledger_error.Unexpected e)

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
          ( Or_error.error_string "Error creating statement from job"
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
        (List.map ts ~f:(fun (p, m) ->
             ( Ledger_proof.Cached.read_proof_from_disk p
             , Ledger_proof.Cached.statement p
             , m ) ) )
  end

  module Statement_scanner_with_proofs =
    Scan_state.Make_statement_scanner (Statement_scanner_proof_verifier)

  type t =
    { scan_state : Scan_state.t
    ; ledger :
        (* Invariant: this is the ledger after having applied all the
            transactions in the above state. *)
        Ledger.attached_mask
    ; constraint_constants : Genesis_constants.Constraint_constants.t
    ; pending_coinbase_collection : Pending_coinbase.t
    }

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
        ~f:(fun ((p, _), _) -> Ledger_proof.Cached.statement p)
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
        ~logger scan_state ~statement_check:(`Full get_state)
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
      ~(constraint_constants : Genesis_constants.Constraint_constants.t) ~logger
      ~last_proof_statement ~ledger ~scan_state ~pending_coinbase_collection
      ~first_pass_ledger_target =
    let open Deferred.Or_error.Let_syntax in
    let%bind pending_coinbase_stack =
      Pending_coinbase.latest_stack ~is_new_stack:false
        pending_coinbase_collection
      |> Deferred.return
    in
    let%bind () =
      Statement_scanner.check_invariants ~constraint_constants ~logger
        scan_state ~statement_check:`Partial ~verifier:()
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
    return
      { ledger; scan_state; constraint_constants; pending_coinbase_collection }

  let of_scan_state_pending_coinbases_and_snarked_ledger' ~constraint_constants
      ~pending_coinbases ~scan_state ~snarked_ledger ~snarked_local_state:_
      ~expected_merkle_root ~get_state ~signature_kind f =
    let open Deferred.Or_error.Let_syntax in
    let apply_first_pass =
      Ledger.apply_transaction_first_pass ~signature_kind ~constraint_constants
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
        ~apply_second_pass ~apply_first_pass_sparse_ledger ~signature_kind
        scan_state
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
      |> Option.map ~f:(fun ((p, _), _) -> Ledger_proof.Cached.statement p)
    in
    f ~constraint_constants ~last_proof_statement ~ledger:snarked_ledger
      ~scan_state ~pending_coinbase_collection:pending_coinbases
      ~first_pass_ledger_target

  let of_scan_state_pending_coinbases_and_snarked_ledger ~logger
      ~constraint_constants ~verifier ~scan_state ~snarked_ledger
      ~snarked_local_state ~expected_merkle_root ~pending_coinbases ~get_state
      ~signature_kind =
    of_scan_state_pending_coinbases_and_snarked_ledger' ~constraint_constants
      ~pending_coinbases ~scan_state ~snarked_ledger ~snarked_local_state
      ~expected_merkle_root ~get_state ~signature_kind
      (of_scan_state_and_ledger ~logger ~get_state ~verifier)

  let of_scan_state_pending_coinbases_and_snarked_ledger_unchecked
      ~constraint_constants ~logger ~scan_state ~snarked_ledger
      ~snarked_local_state ~expected_merkle_root ~pending_coinbases ~get_state
      ~signature_kind =
    of_scan_state_pending_coinbases_and_snarked_ledger' ~constraint_constants
      ~pending_coinbases ~scan_state ~snarked_ledger ~snarked_local_state
      ~expected_merkle_root ~get_state ~signature_kind
      (of_scan_state_and_ledger_unchecked ~logger)

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
      Scan_state.(Stable.Latest.hash @@ read_all_proofs_from_disk scan_state)
      (Ledger.merkle_root ledger)
      pending_coinbase_collection

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

  let apply_single_transaction_first_pass ~constraint_constants ~global_slot
      ~signature_kind ledger
      (pending_coinbase_stack_state : Stack_state_with_init_stack.t)
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
        (Ledger.apply_transaction_first_pass ~signature_kind
           ~constraint_constants ~global_slot ~txn_state_view ledger txn )
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

  let apply_single_transaction_second_pass ~constraint_constants
      ~connecting_ledger ledger state_and_body_hash ~global_slot
      (pre_stmt : Pre_statement.t) =
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
        (Mina_transaction_logic.Transaction_applied.supply_increase
           ~constraint_constants applied_txn )
    in
    let%map () =
      let actual_status = Ledger.status_of_applied applied_txn in
      if Transaction_status.equal pre_stmt.expected_status actual_status then
        return ()
      else
        let txn_with_expected_status =
          { With_status.data =
              With_status.data (Ledger.transaction_of_applied applied_txn)
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
      ~signature_kind ledger init_pending_coinbase_stack_state ts
      current_state_view =
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
            ~signature_kind ledger pending_coinbase_stack_state txn
            current_state_view
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

  let apply_transactions_second_pass ~constraint_constants ~yield ~global_slot
      ledger state_and_body_hash pre_stmts =
    let open Deferred.Result.Let_syntax in
    let connecting_ledger = Ledger.merkle_root ledger in
    Mina_stdlib.Deferred.Result.List.map pre_stmts ~f:(fun pre_stmt ->
        let%bind result =
          apply_single_transaction_second_pass ~constraint_constants
            ~connecting_ledger ~global_slot ledger state_and_body_hash pre_stmt
          |> Deferred.return
        in
        let%map () = yield () in
        result )

  let update_ledger_and_get_statements ~constraint_constants ~global_slot
      ~signature_kind ledger current_stack tss current_state_view
      state_and_body_hash =
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
      apply_first_pass ~yield ~signature_kind current_stack ts
    in
    let%bind pre_stmts2, updated_stack2 =
      match ts_opt with
      | None ->
          return ([], updated_stack1)
      | Some ts ->
          let current_stack2 =
            Pending_coinbase.Stack.create_with current_stack
          in
          apply_first_pass ~yield ~signature_kind current_stack2 ts
    in
    let first_pass_ledger_end = Ledger.merkle_root ledger in
    let%map txns_with_witnesses =
      apply_transactions_second_pass ~constraint_constants ~yield ~global_slot
        ledger state_and_body_hash (pre_stmts1 @ pre_stmts2)
    in
    (txns_with_witnesses, updated_stack1, updated_stack2, first_pass_ledger_end)

  (** Checks if the work has already been verified before by the snark pool logic *)
  let work_already_verified_check ~get_completed_work jobs work =
    let exception Statement_of_job_failure in
    let statement_of_job_exn job =
      Option.value_exn ~error:(Error.of_exn Statement_of_job_failure)
      @@ Scan_state.statement_of_job job
    in
    try
      let job_statements = One_or_two.map ~f:statement_of_job_exn jobs in
      let work_statement = Transaction_snark_work.statement work in
      let statements_match =
        Transaction_snark_work.Statement.equal job_statements work_statement
      in
      let matching_completed_work_in_pool = get_completed_work work_statement in
      match (statements_match, matching_completed_work_in_pool) with
      | true, Some (completed_work : Transaction_snark_work.Checked.t) ->
          let verified_proofs =
            Transaction_snark_work.Checked.proofs completed_work
            |> One_or_two.map ~f:Ledger_proof.Cached.read_proof_from_disk
          in
          let block_work_proofs =
            Transaction_snark_work.proofs work
            |> One_or_two.map ~f:Ledger_proof.Cached.read_proof_from_disk
          in
          if
            not
            @@ Fee.equal
                 (Transaction_snark_work.Checked.fee completed_work)
                 (Transaction_snark_work.fee work)
          then Second "fee_not_equal"
          else if
            not
            @@ Account.Key.equal
                 (Transaction_snark_work.Checked.prover completed_work)
                 (Transaction_snark_work.prover work)
          then Second "prover_account_not_equal"
          else if
            not
            @@ One_or_two.equal Ledger_proof.equal verified_proofs
                 block_work_proofs
          then Second "proof_not_equal"
          else First ()
      | _ ->
          Second "not_found_in_pool"
    with Statement_of_job_failure -> Second "statement_of_job_failure"

  let check_completed_works ~logger ~verifier ~get_completed_work scan_state
      (completed_works : Transaction_snark_work.t list) =
    let work_count = List.length completed_works in
    let job_pairs =
      Scan_state.k_work_pairs_for_new_diff scan_state ~k:work_count
    in
    let found_in_snarkpool_count = ref 0 in
    let mismatch_reasons = String.Table.create ~size:10 () in
    let jmps =
      List.concat_map (List.zip_exn job_pairs completed_works)
        ~f:(fun (jobs, work) ->
          match work_already_verified_check ~get_completed_work jobs work with
          | First () ->
              incr found_in_snarkpool_count ;
              []
          | Second reason ->
              String.Table.incr mismatch_reasons reason ;
              let message =
                Sok_message.create ~fee:work.fee ~prover:work.prover
              in
              One_or_two.(
                to_list
                  (map (zip_exn jobs work.proofs) ~f:(fun (job, proof) ->
                       ( job
                       , message
                       , Ledger_proof.Cached.read_proof_from_disk proof ) ) )) )
    in
    [%log debug]
      ~metadata:
        [ ("completed_work_found_in_pool", `Int !found_in_snarkpool_count)
        ; ( "non_skipped_reasons"
          , `Assoc
              (List.map (String.Table.to_alist mismatch_reasons)
                 ~f:(fun (reason, count) -> (reason, `Int count)) ) )
        ]
      "check_completed_works: completed works found in SNARK pool: \
       $completed_work_found_in_pool\n\
      \      Non skipped work reasons: $non_skipped_reasons" ;
    if List.is_empty jmps then Deferred.return (Ok ())
    else verify jmps ~logger ~verifier

  (**The total fee excess caused by any diff should be zero. In the case where
     the slots are split into two partitions, total fee excess of the transactions
     to be enqueued on each of the partitions should be zero respectively *)
  let check_zero_fee_excess scan_state data =
    let partitions = Scan_state.partition_if_overflowing scan_state in
    let txns_from_data data =
      List.fold_right ~init:(Ok []) data
        ~f:(fun (d : Scan_state.Transaction_with_witness.t) acc ->
          let%map.Or_error acc = acc in
          let t = d.transaction_with_info |> Ledger.transaction_of_applied in
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

  let update_coinbase_stack_and_get_data_impl ~logger ~constraint_constants
      ~global_slot ~first_partition_slots:slots ~no_second_partition
      ~is_new_stack ~signature_kind ledger pending_coinbase_collection
      transactions current_state_view state_and_body_hash =
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
    if no_second_partition then (
      (*Single partition:
        1.Check if a new stack is required and get a working stack [working_stack]
        2.create data for enqueuing onto the scan state *)
      let%bind working_stack =
        working_stack pending_coinbase_collection ~is_new_stack
        |> Deferred.return
      in
      [%log internal] "Update_ledger_and_get_statements"
        ~metadata:[ ("partition", `String "single") ] ;
      let%map data, updated_stack, _, first_pass_ledger_end =
        update_ledger_and_get_statements ~constraint_constants ~global_slot
          ~signature_kind ledger working_stack (transactions, None)
          current_state_view state_and_body_hash
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
      , `First_pass_ledger_end first_pass_ledger_end ) )
    else
      (*Two partition:
        Assumption: Only one of the partition will have coinbase transaction(s)in it.
        1. Get the latest stack for coinbase in the first set of transactions
        2. get the first set of scan_state data[data1]
        3. get a new stack for the second partition because the second set of
           transactions would start from the begining of the next tree in the
           scan_state
        4. Initialize the new stack with the state from the first stack
        5. get the second set of scan_state data[data2]*)
      let txns_for_partition1 = List.take transactions slots in
      let coinbase_in_first_partition = coinbase_exists txns_for_partition1 in
      let%bind working_stack1 =
        working_stack pending_coinbase_collection ~is_new_stack:false
        |> Deferred.return
      in
      let txns_for_partition2 = List.drop transactions slots in
      [%log internal] "Update_ledger_and_get_statements"
        ~metadata:[ ("partition", `String "both") ] ;
      let%map data, updated_stack1, updated_stack2, first_pass_ledger_end =
        update_ledger_and_get_statements ~constraint_constants ~global_slot
          ~signature_kind ledger working_stack1
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
        (* updated_stack2 does not have coinbase and but has the state from the
           previous stack *)
        | true, false ->
            (* updated_stack1 has some new coinbase but parition 2 has no
               data and so we have only one stack to update *)
            (Update_one, `Update_one updated_stack1)
        | false, true ->
            (* updated_stack1 just has the new state. [updated stack2] might
               have coinbase, definitely has some data and therefore will have a
               non-dummy state. *)
            ( Update_two_coinbase_in_second
            , `Update_two (updated_stack1, updated_stack2) )
        | false, false ->
            (* a diff consists of only non-coinbase transactions. This is
               currently not possible because a diff will have a coinbase at the
               very least, so don't update anything? *)
            (Update_none, `Update_none)
      in
      [%log internal] "Update_coinbase_stack_done"
        ~metadata:
          [ ("is_new_stack", `Bool false)
          ; ("coinbase_in_first_partition", `Bool coinbase_in_first_partition)
          ; ("second_has_data", `Bool second_has_data)
          ; ("txns_for_partition1_len", `Int (List.length txns_for_partition1))
          ; ("txns_for_partition2_len", `Int (List.length txns_for_partition2))
          ] ;
      ( false
      , data
      , pending_coinbase_action
      , stack_update
      , `First_pass_ledger_end first_pass_ledger_end )

  let update_coinbase_stack_and_get_data ~logger ~constraint_constants
      ~global_slot ~signature_kind scan_state ledger pending_coinbase_collection
      transactions current_state_view state_and_body_hash =
    let { Scan_state.Space_partition.first = slots, _; second } =
      Scan_state.partition_if_overflowing scan_state
    in
    let is_new_stack = Scan_state.next_on_new_tree scan_state in
    if not @@ List.is_empty transactions then
      update_coinbase_stack_and_get_data_impl ~logger ~constraint_constants
        ~global_slot ~first_partition_slots:slots
        ~no_second_partition:(Option.is_none second) ~is_new_stack
        ~signature_kind ledger pending_coinbase_collection transactions
        current_state_view state_and_body_hash
    else (
      [%log internal] "Update_coinbase_stack_done" ;
      Deferred.return
        (Ok
           ( false
           , []
           , Pending_coinbase.Update.Action.Update_none
           , `Update_none
           , `First_pass_ledger_end (Ledger.merkle_root ledger) ) ) )

  (* Update the pending_coinbase tree with the updated/new stack and delete the
     oldest stack if a proof was emitted *)
  let update_pending_coinbase_collection ~depth pending_coinbase_collection
      stack_update ~is_new_stack ~ledger_proof =
    let open Result.Let_syntax in
    (* Deleting oldest stack if proof emitted *)
    let%bind pending_coinbase_collection_updated1 =
      match ledger_proof with
      | Some (proof, _) ->
          let%bind oldest_stack, pending_coinbase_collection_updated1 =
            Pending_coinbase.remove_coinbase_stack ~depth
              pending_coinbase_collection
            |> to_staged_ledger_or_error
          in
          let ledger_proof_stack =
            (Ledger_proof.Cached.statement proof).target.pending_coinbase_stack
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
    (* Updating the latest stack and/or adding a new one *)
    match stack_update with
    | `Update_none ->
        Ok pending_coinbase_collection_updated1
    | `Update_one stack1 ->
        Pending_coinbase.update_coinbase_stack ~depth
          pending_coinbase_collection_updated1 stack1 ~is_new_stack
        |> to_staged_ledger_or_error
    | `Update_two (stack1, stack2) ->
        (* The case when some of the transactions go into the old tree and
           remaining on to the new tree *)
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
      ~global_slot ~current_state_view ~state_and_body_hash ~log_prefix
      ~zkapp_cmd_limit_hardcap ~signature_kind t pre_diff_info =
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
    let accounts_accessed =
      List.fold_left ~init:Account_id.Set.empty transactions ~f:(fun set txn ->
          Account_id.Set.(
            union set
              (of_list (Transaction.accounts_referenced txn.With_status.data))) )
      |> Set.to_list
    in
    Ledger.unsafe_preload_accounts_from_parent new_ledger accounts_accessed ;
    let%bind () =
      (* Check number of zkApps in a block does not exceed hardcap *)
      O1trace.thread "zkapp_hardcap_check" (fun () ->
          let is_zkapp : Transaction.t With_status.t -> bool = function
            | { With_status.data =
                  Transaction.Command (Mina_base.User_command.Zkapp_command _)
              ; status = _
              } ->
                true
            | _ ->
                false
          in
          let zk_app_count = List.count ~f:is_zkapp transactions in
          if zk_app_count > zkapp_cmd_limit_hardcap then
            Deferred.Result.fail
              (Staged_ledger_error.ZkApps_exceed_limit
                 (zk_app_count, zkapp_cmd_limit_hardcap) )
          else Deferred.Result.return () )
    in
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
            ~global_slot ~signature_kind t.scan_state new_ledger
            t.pending_coinbase_collection transactions current_state_view
            state_and_body_hash )
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
              verify_scan_state_after_apply ~constraint_constants ~logger
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

  type transaction_pool_proxy = Check_commands.transaction_pool_proxy

  let apply ?skip_verification ~constraint_constants ~global_slot
      ~get_completed_work ~logger ~verifier ~current_state_view
      ~state_and_body_hash ~coinbase_receiver ~supercharge_coinbase
      ~zkapp_cmd_limit_hardcap ~signature_kind
      ?(transaction_pool_proxy = Check_commands.dummy_transaction_pool_proxy) t
      (witness : Staged_ledger_diff.t) =
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
              check_completed_works ~get_completed_work ~logger ~verifier
                t.scan_state work )
    in
    [%log internal] "Prediff" ;
    let%bind prediff =
      Pre_diff_info.get witness ~constraint_constants ~coinbase_receiver
        ~supercharge_coinbase
        ~check:
          (Check_commands.check_commands t.ledger ~verifier
             ~transaction_pool_proxy )
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
        ~log_prefix:"apply_diff" ~zkapp_cmd_limit_hardcap ~signature_kind
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

  let apply_diff_unchecked ~constraint_constants ~global_slot ~logger
      ~current_state_view ~state_and_body_hash ~coinbase_receiver
      ~supercharge_coinbase ~zkapp_cmd_limit_hardcap ~signature_kind t
      (sl_diff : Staged_ledger_diff.With_valid_signatures_and_proofs.t) =
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
      ~zkapp_cmd_limit_hardcap ~signature_kind

  module Resources = struct
    module Discarded = struct
      type t =
        { commands_rev : User_command.Valid.t Sequence.t
        ; completed_work : Transaction_snark_work.Checked.t Sequence.t
        }

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

    let coinbase_ft (cw : Transaction_snark_work.Checked.t) =
      let fee = Transaction_snark_work.Checked.fee cw in
      let receiver_pk = Transaction_snark_work.Checked.prover cw in
      (* Here we could not add the fee transfer if the prover=receiver_pk but
         retaining it to preserve that information in the
         staged_ledger_diff. It will be checked in apply_diff before adding*)
      Option.some_if
        Fee.(fee > Fee.zero)
        (Coinbase.Fee_transfer.create ~receiver_pk ~fee)

    let cheapest_two_work (works : Transaction_snark_work.Checked.t Sequence.t)
        =
      let open Transaction_snark_work.Checked in
      Sequence.fold works ~init:(None, None) ~f:(fun (w1, w2) w ->
          match (w1, w2) with
          | None, _ ->
              (Some w, None)
          | Some x, None ->
              if Fee.compare (fee w) (fee x) < 0 then (Some w, w1)
              else (w1, Some w)
          | Some x, Some y ->
              if Fee.compare (fee w) (fee x) < 0 then (Some w, w1)
              else if Fee.compare (fee w) (fee y) < 0 then (w1, Some w)
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
              (Transaction_snark_work.Checked.statement w)
              ~equal:Transaction_snark_work.Statement.equal
            |> not )
      in
      let%bind coinbase_amount =
        coinbase_amount ~supercharge_coinbase ~constraint_constants
      in
      let%bind budget =
        (* if the coinbase receiver is new then the account creation fee will be
           deducted from the reward *)
        if is_coinbase_receiver_new then
          Currency.Amount.(
            sub coinbase_amount
              (of_fee constraint_constants.account_creation_fee))
        else Some coinbase_amount
      in
      let stmt = Transaction_snark_work.Checked.statement in
      if is_two then
        match (min1, min2) with
        | None, _ ->
            None
        | Some w, None ->
            if Amount.(of_fee (Transaction_snark_work.Checked.fee w) <= budget)
            then
              let cb =
                Staged_ledger_diff.At_most_two.Two
                  (Option.map (coinbase_ft w) ~f:(fun ft -> (ft, None)))
              in
              Some (cb, diff works (Sequence.of_list [ stmt w ]))
            else
              let cb = Staged_ledger_diff.At_most_two.Two None in
              Some (cb, works)
        | Some w1, Some w2 ->
            let%map sum =
              Fee.add
                (Transaction_snark_work.Checked.fee w1)
                (Transaction_snark_work.Checked.fee w2)
            in
            if Amount.(of_fee sum <= budget) then
              let cb =
                Staged_ledger_diff.At_most_two.Two
                  (Option.map (coinbase_ft w1) ~f:(fun ft ->
                       (ft, coinbase_ft w2) ) )
                (* Why add work without checking if work constraints are
                   satisfied? If we reach here then it means that we are trying to
                   fill the last two slots of the tree with coinbase trnasactions
                   and if there's any work in [works] then that has to be included,
                   either in the coinbase or as fee transfers that gets paid by
                   the transaction fees. So having it as coinbase ft will at least
                   reduce the slots occupied by fee transfers *)
              in
              (cb, diff works (Sequence.of_list [ stmt w1; stmt w2 ]))
            else if
              Amount.(of_fee (Transaction_snark_work.Checked.fee w1) <= budget)
            then
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
            if Amount.(of_fee (Transaction_snark_work.Checked.fee w) <= budget)
            then
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
            (* Coinbase could not be added because work-fees > coinbase-amount *)
            if job_count = 0 || slots - job_count >= 1 then
              (* Either no jobs are required or there is a free slot that can be
                 filled without having to include any work *)
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
          (* Completed work in reverse order for faster removal of proofs if
             budget doesn't suffice *)
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
                (* Check for work constraint will be done in
                   [check_constraints_and_update] *)
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
      (* get the correct coinbase and calculate the fee transfers *)
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
      (* If more jobs were added in the previous diff then (
         t.max_space-t.max_jobs) slots can go for free in this diff *)
      no_of_proof_bundles = t.max_jobs || slots <= t.max_space - t.max_jobs

    let space_constraint_satisfied t =
      let occupied = slots_occupied t in
      occupied <= t.max_space

    let work_constraint_satisfied (t : t) =
      (* Are we doing all the work available? *)
      let all_proofs = work_done t in
      (* enough work *)
      let slots = slots_occupied t in
      let cw_count = Sequence.length t.completed_work_rev in
      let enough_work = cw_count >= slots in
      (* if there are no transactions then don't need any proofs *)
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
        (* When discarding coinbase's fee transfer, add the fee transfer to the
           fee_transfers map so that budget checks can be done *)
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
          (* If we have reached here then it means we couldn't afford a slot for
             coinbase as well *)
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
      (* Is the work constraint satisfied even after discarding a work bundle?
         We reach here after having more than enough work
      *)
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
          (* Add one from the discarded list to [completed_work_rev] and then
             select a work from [completed_work_rev] except the one already used *)
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
        (* There's enough work. Check if they satisfy other constraints *)
        Resources.budget_sufficient resources
      then
        if Resources.space_constraint_satisfied resources then (resources, log)
        else if Resources.worked_more ~constraint_constants resources then
          (* There are too many fee_transfers(from the proofs) occupying the slots. discard one and check *)
          let resources', work_opt =
            Resources.discard_last_work ~constraint_constants resources
          in
          check_constraints_and_update ~constraint_constants resources'
            (Option.value_map work_opt ~default:log ~f:(fun work ->
                 Diff_creation_log.discard_completed_work `Extra_work work log )
            )
        else
          (* Well, there's no space; discard a user command *)
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
      (* There isn't enough work for the transactions. Discard a transaction and
         check again *)
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
    (* Partitioning explained in PR #687 *)
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
            (* All slots could not be filled either because of budget
               constraints or not enough work done. Don't create the second
               prediff instead recompute first diff with just once coinbase *)
            ( one_prediff ~constraint_constants cw_seq_1 ts_seq ~receiver
                partitions.first ~add_coinbase:true logger
                ~is_coinbase_receiver_new ~supercharge_coinbase `First
            , None )
          else
            let res2, log2 =
              second_pre_diff new_res y ~add_coinbase:false cw_seq_2
            in
            if isEmpty res2 then
              (* Don't create the second prediff instead recompute first diff
                 with just once coinbase *)
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
                (* generate the next prediff with a coinbase at least *)
                let res2 = second_pre_diff res y ~add_coinbase:true cw_seq_2 in
                ((res, log1), Some res2)
            | 1 ->
                (* There's a slot available in the first partition, fill it with
                   coinbase and create another pre_diff for the slots in the second
                   partiton with the remaining user commands and work *)
                incr_coinbase_and_compute res `One
            | 2 ->
                (* There are two slots which cannot be filled using user
                   commands, so we split the coinbase into two parts and fill those
                   two spots *)
                incr_coinbase_and_compute res `Two
            | _ ->
                (* Too many slots left in the first partition. Either there
                   wasn't enough work to add transactions or there weren't enough
                   transactions. Create a new pre_diff for just the first
                   partition *)
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
          (* Coinbase takes priority over user-commands. Create a diff in
             partitions.first with coinbase first and user commands if
             possible *)
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

  module Application_state = struct
    type txn =
      ( Signed_command.With_valid_signature.t
      , Zkapp_command.Valid.t )
      User_command.t_

    type t =
      { valid_seq : txn Sequence.t
      ; invalid : (txn * Error.t) list
      ; skipped_by_fee_payer : txn list Account_id.Map.t
      ; zkapp_space_remaining : int option
      ; total_space_remaining : int
      }

    let init ?zkapp_limit ~total_limit =
      { valid_seq = Sequence.empty
      ; invalid = []
      ; skipped_by_fee_payer = Account_id.Map.empty
      ; zkapp_space_remaining = zkapp_limit
      ; total_space_remaining = total_limit
      }

    let txn_key = function
      | User_command.Zkapp_command cmd ->
          Zkapp_command.(Valid.forget cmd |> fee_payer)
      | User_command.Signed_command cmd ->
          Signed_command.(forget_check cmd |> fee_payer)

    let add_skipped_txn t (txn : txn) =
      Account_id.Map.update t.skipped_by_fee_payer (txn_key txn)
        ~f:(Option.value_map ~default:[ txn ] ~f:(List.cons txn))

    let dependency_skipped txn t =
      Account_id.Map.mem t.skipped_by_fee_payer (txn_key txn)

    let try_applying_txn ?logger ~apply (state : t) (txn : txn) =
      let open Continue_or_stop in
      match (state.zkapp_space_remaining, txn) with
      | _ when state.total_space_remaining < 1 ->
          Stop (state.valid_seq, state.invalid)
      | Some zkapp_limit, User_command.Zkapp_command _ when zkapp_limit < 1 ->
          Continue
            { state with skipped_by_fee_payer = add_skipped_txn state txn }
      | Some _, _ when dependency_skipped txn state ->
          Continue
            { state with skipped_by_fee_payer = add_skipped_txn state txn }
      | _ -> (
          match
            O1trace.sync_thread "validate_transaction_against_staged_ledger"
              (fun () ->
                apply (Transaction.Command (User_command.forget_check txn)) )
          with
          | Error e ->
              Option.iter logger ~f:(fun logger ->
                  [%log error]
                    ~metadata:
                      [ ("user_command", User_command.Valid.to_yojson txn)
                      ; ("error", Error_json.error_to_yojson e)
                      ]
                    "Staged_ledger_diff creation: Skipping user command: \
                     $user_command due to error: $error" ) ;
              Continue { state with invalid = (txn, e) :: state.invalid }
          | Ok _txn_partially_applied ->
              let valid_seq =
                Sequence.append (Sequence.singleton txn) state.valid_seq
              in
              let zkapp_space_remaining =
                Option.map state.zkapp_space_remaining ~f:(fun limit ->
                    match txn with
                    | Zkapp_command _ ->
                        limit - 1
                    | Signed_command _ ->
                        limit )
              in
              Continue
                { state with
                  valid_seq
                ; zkapp_space_remaining
                ; total_space_remaining = state.total_space_remaining - 1
                } )
  end

  let create_diff
      ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ~(global_slot : Mina_numbers.Global_slot_since_genesis.t)
      ?(log_block_creation = false) t ~coinbase_receiver ~logger
      ~current_state_view ~zkapp_cmd_limit
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
                      let fee = Transaction_snark_work.Checked.fee cw_checked in
                      let prover =
                        Transaction_snark_work.Checked.prover cw_checked
                      in
                      (*If new provers can't pay the account-creation-fee then discard
                        their work unless their fee is zero in which case their account
                        won't be created. This is to encourage using an existing accounts
                        for snarking.
                        This also imposes new snarkers to have a min fee until one of
                        their snarks are purchased and their accounts get created*)
                      if
                        Currency.Fee.(fee = zero)
                        || Currency.Fee.(
                             fee >= constraint_constants.account_creation_fee)
                        || not (is_new_account prover)
                      then
                        Continue
                          ( Sequence.append seq (Sequence.singleton cw_checked)
                          , One_or_two.length
                              (Transaction_snark_work.Checked.proofs cw_checked)
                            + count )
                      else (
                        [%log debug]
                          ~metadata:
                            [ ("prover", Public_key.Compressed.to_yojson prover)
                            ; ( "work_ids"
                              , Transaction_snark_work.Statement.compact_json w
                              )
                            ; ("snark_fee", Currency.Fee.to_yojson fee)
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
                            ; ( "interrupt_get_completed_work_ids"
                              , Transaction_snark_work.Statement.compact_json w
                              )
                            ] ;
                        Stop (seq, count) )
                  | None ->
                      [%log debug]
                        ~metadata:
                          [ ( "work_ids"
                            , Transaction_snark_work.Statement.compact_json w )
                          ]
                        !"Staged_ledger_diff creation: No snark work found for \
                          $work_ids" ;
                      [%log internal] "@block_metadata"
                        ~metadata:
                          [ ("interrupt_get_completed_work_at", `Int count)
                          ; ( "interrupt_get_completed_work_reason"
                            , `String "Snark work for statement not found" )
                          ; ( "interrupt_get_completed_work_ids"
                            , Transaction_snark_work.Statement.compact_json w )
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
            let apply =
              Transaction_validator.apply_transaction_first_pass
                ~constraint_constants ~global_slot validating_ledger
                ~txn_state_view:current_state_view
                ~signature_kind:Mina_signature_kind.t_DEPRECATED
            in
            (* Transactions in reverse order for faster removal if there is no
               space when creating the diff *)
            let valid_on_this_ledger, invalid_on_this_ledger =
              Sequence.fold_until transactions_by_fee
                ~init:
                  (Application_state.init ?zkapp_limit:zkapp_cmd_limit
                     ~total_limit:(Scan_state.free_space t.scan_state) )
                ~f:(Application_state.try_applying_txn ~apply ~logger)
                ~finish:(fun state -> (state.valid_seq, state.invalid))
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

  let convert_and_apply_all_masks_to_ledger ~hardfork_db ({ ledger; _ } : t) =
    let accounts =
      Ledger.all_accounts_on_masks ledger
      |> Map.to_alist
      |> List.map ~f:(fun (loc, account) ->
             (loc, Account.Hardfork.of_stable account) )
    in
    Ledger.Hardfork_db.set_batch hardfork_db accounts
end

include T

module Test_helpers = struct
  let constraint_constants =
    Genesis_constants.For_unit_tests.Constraint_constants.t

  let dummy_state_and_view ?global_slot () =
    let state =
      let consensus_constants =
        let genesis_constants = Genesis_constants.For_unit_tests.t in
        Consensus.Constants.create ~constraint_constants
          ~protocol_constants:genesis_constants.protocol
      in
      let compile_time_genesis =
        let open Staged_ledger_diff in
        (*not using Precomputed_values.for_unit_test because of dependency cycle*)
        Mina_state.Genesis_protocol_state.t
          ~genesis_ledger:Genesis_ledger.for_unit_tests
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

  let update_coinbase_stack_and_get_data_impl =
    update_coinbase_stack_and_get_data_impl

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
end

