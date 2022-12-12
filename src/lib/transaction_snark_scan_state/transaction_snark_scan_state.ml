open Core_kernel
open Async
open Mina_base
open Mina_transaction
open Currency
module Ledger = Mina_ledger.Ledger
module Sparse_ledger = Mina_ledger.Sparse_ledger

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
  [%%versioned
  module Stable = struct
    module V2 = struct
      (* TODO: The statement is redundant here - it can be computed from the
         witness and the transaction
      *)
      type t =
        { transaction_with_info :
            Mina_transaction_logic.Transaction_applied.Stable.V2.t
        ; state_hash : State_hash.Stable.V1.t * State_body_hash.Stable.V1.t
        ; statement : Transaction_snark.Statement.Stable.V2.t
        ; init_stack :
            Transaction_snark.Pending_coinbase_stack_state.Init_stack.Stable.V1
            .t
        ; first_pass_ledger_witness : Mina_ledger.Sparse_ledger.Stable.V2.t
              [@sexp.opaque]
        ; second_pass_ledger_witness : Mina_ledger.Sparse_ledger.Stable.V2.t
              [@sexp.opaque]
        }
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]
end

module Ledger_proof_with_sok_message = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t = Ledger_proof.Stable.V2.t * Sok_message.Stable.V1.t
      [@@deriving sexp]

      let to_latest = Fn.id
    end
  end]
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

  let to_yojson ({ value; position } : t) : Yojson.Safe.t =
    let module R = struct
      type t =
        ( Frozen_ledger_hash.t
        , Pending_coinbase.Stack_versioned.t
        , Mina_state.Local_state.t )
        Mina_state.Registers.t
      [@@deriving to_yojson]
    end in
    let statement_to_yojson (s : Transaction_snark.Statement.t) =
      `Assoc
        [ ("Work_id", `Int (Transaction_snark.Statement.hash s))
        ; ("Source", R.to_yojson s.source)
        ; ("Target", R.to_yojson s.target)
        ; ( "Fee Excess"
          , `List
              [ `Assoc
                  [ ("token", Token_id.to_yojson s.fee_excess.fee_token_l)
                  ; ("amount", Fee.Signed.to_yojson s.fee_excess.fee_excess_l)
                  ]
              ; `Assoc
                  [ ("token", Token_id.to_yojson s.fee_excess.fee_token_r)
                  ; ("amount", Fee.Signed.to_yojson s.fee_excess.fee_excess_r)
                  ]
              ] )
        ; ("Supply Increase", Currency.Amount.Signed.to_yojson s.supply_increase)
        ]
    in
    let job_to_yojson =
      match value with
      | BEmpty ->
          `Assoc [ ("B", `List []) ]
      | MEmpty ->
          `Assoc [ ("M", `List []) ]
      | MPart x ->
          `Assoc [ ("M", `List [ statement_to_yojson x ]) ]
      | MFull (x, y, { seq_no; status }) ->
          `Assoc
            [ ( "M"
              , `List
                  [ statement_to_yojson x
                  ; statement_to_yojson y
                  ; `Int seq_no
                  ; `Assoc
                      [ ( "Status"
                        , `String (Parallel_scan.Job_status.to_string status) )
                      ]
                  ] )
            ]
      | BFull (x, { seq_no; status }) ->
          `Assoc
            [ ( "B"
              , `List
                  [ statement_to_yojson x
                  ; `Int seq_no
                  ; `Assoc
                      [ ( "Status"
                        , `String (Parallel_scan.Job_status.to_string status) )
                      ]
                  ] )
            ]
    in
    `List [ `Int position; job_to_yojson ]
end

type job = Available_job.t [@@deriving sexp]

(*Scan state and any zkapp updates that were applied to the to the most recent
   snarked ledger but are from the tree just before the tree corresponding to
   the snarked ledger*)
[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      { scan_state :
          ( Ledger_proof_with_sok_message.Stable.V2.t
          , Transaction_with_witness.Stable.V2.t )
          Parallel_scan.State.Stable.V1.t
      ; previous_incomplete_zkapp_updates :
          Transaction_with_witness.Stable.V2.t list
      }
    [@@deriving sexp]

    let to_latest = Fn.id

    let hash (t : t) =
      let state_hash =
        Parallel_scan.State.hash t.scan_state
          (Binable.to_string (module Ledger_proof_with_sok_message.Stable.V2))
          (Binable.to_string (module Transaction_with_witness.Stable.V2))
      in
      let incomplete_updates =
        List.fold ~init:"" t.previous_incomplete_zkapp_updates ~f:(fun acc t ->
            acc
            ^ Binable.to_string (module Transaction_with_witness.Stable.V2) t )
        |> Digestif.SHA256.digest_string
      in
      Staged_ledger_hash.Aux_hash.of_sha256
        Digestif.SHA256.(
          digest_string
            (to_raw_string state_hash ^ to_raw_string incomplete_updates))
  end
end]

[%%define_locally Stable.Latest.(hash)]

(**********Helpers*************)

(* TODO *)
let create_expected_statement ~constraint_constants
    ~(get_state : State_hash.t -> Mina_state.Protocol_state.value Or_error.t)
    { Transaction_with_witness.transaction_with_info
    ; state_hash
    ; first_pass_ledger_witness
    ; second_pass_ledger_witness
    ; init_stack
    ; statement
    } =
  let open Or_error.Let_syntax in
  let source_fee_payment_merkle_root =
    Frozen_ledger_hash.of_ledger_hash
    @@ Sparse_ledger.merkle_root first_pass_ledger_witness
  in
  let source_parties_merkle_root =
    Frozen_ledger_hash.of_ledger_hash
    @@ Sparse_ledger.merkle_root second_pass_ledger_witness
  in
  let { With_status.data = transaction; status = _ } =
    Ledger.Transaction_applied.transaction transaction_with_info
  in
  let%bind protocol_state = get_state (fst state_hash) in
  let state_view = Mina_state.Protocol_state.Body.view protocol_state.body in
  let empty_local_state = Mina_state.Local_state.empty () in
  let%bind after, applied_transaction =
    Or_error.try_with (fun () ->
        Sparse_ledger.apply_transaction ~constraint_constants
          ~txn_state_view:state_view first_pass_ledger_witness transaction )
    |> Or_error.join
  in
  let target_fee_payment_merkle_root =
    Sparse_ledger.merkle_root after |> Frozen_ledger_hash.of_ledger_hash
  in
  let target_parties_merkle_root = failwith "TODO" in
  let connecting_ledger_left = failwith "TODO" in
  let connecting_ledger_right = failwith "TODO" in
  let%bind pending_coinbase_before =
    match init_stack with
    | Base source ->
        Ok source
    | Merge ->
        Or_error.errorf
          !"Invalid init stack in Pending coinbase stack state . Expected Base \
            found Merge"
  in
  let pending_coinbase_after =
    let state_body_hash = snd state_hash in
    let pending_coinbase_with_state =
      Pending_coinbase.Stack.push_state state_body_hash pending_coinbase_before
    in
    match transaction with
    | Coinbase c ->
        Pending_coinbase.Stack.push_coinbase c pending_coinbase_with_state
    | _ ->
        pending_coinbase_with_state
  in
  let%bind fee_excess = Transaction.fee_excess transaction in
  let%map supply_increase =
    Ledger.Transaction_applied.supply_increase applied_transaction
  in
  { Transaction_snark.Statement.Poly.source =
      { first_pass_ledger = source_fee_payment_merkle_root
      ; second_pass_ledger = source_parties_merkle_root
      ; pending_coinbase_stack = statement.source.pending_coinbase_stack
      ; local_state = empty_local_state
      }
  ; target =
      { first_pass_ledger = target_fee_payment_merkle_root
      ; second_pass_ledger = target_parties_merkle_root
      ; pending_coinbase_stack = pending_coinbase_after
      ; local_state = empty_local_state
      }
  ; connecting_ledger_left
  ; connecting_ledger_right
  ; fee_excess
  ; supply_increase
  ; sok_digest = ()
  }

let completed_work_to_scanable_work (job : job) (fee, current_proof, prover) :
    Ledger_proof_with_sok_message.t Or_error.t =
  let sok_digest = Ledger_proof.sok_digest current_proof
  and proof = Ledger_proof.underlying_proof current_proof in
  match job with
  | Base { statement; _ } ->
      let ledger_proof = Ledger_proof.create ~statement ~sok_digest ~proof in
      Ok (ledger_proof, Sok_message.create ~fee ~prover)
  | Merge ((p, _), (p', _)) ->
      let open Or_error.Let_syntax in
      (*
      let%map statement =
        Transaction_snark.Statement.merge (Ledger_proof.statement p)
          (Ledger_proof.statement p')
      in *)
      let s = Ledger_proof.statement p and s' = Ledger_proof.statement p' in
      let option lab =
        Option.value_map ~default:(Or_error.error_string lab) ~f:(fun x -> Ok x)
      in
      let%map fee_excess = Fee_excess.combine s.fee_excess s'.fee_excess
      and supply_increase =
        Amount.Signed.add s.supply_increase s'.supply_increase
        |> option "Error adding supply_increases"
      and _valid_pending_coinbase_stack =
        if
          Pending_coinbase.Stack.equal s.target.pending_coinbase_stack
            s'.source.pending_coinbase_stack
        then Ok ()
        else Or_error.error_string "Invalid pending coinbase stack state"
      in
      let connecting_ledger_left = failwith "TODO merge rules" in
      let connecting_ledger_right = failwith "TODO merge rules" in
      let statement : Transaction_snark.Statement.t =
        { source = s.source
        ; target = s'.target
        ; connecting_ledger_left
        ; connecting_ledger_right
        ; supply_increase
        ; fee_excess
        ; sok_digest = ()
        }
      in
      ( Ledger_proof.create ~statement ~sok_digest ~proof
      , Sok_message.create ~fee ~prover )

let total_proofs (works : Transaction_snark_work.t list) =
  List.sum (module Int) works ~f:(fun w -> One_or_two.length w.proofs)

(*************exposed functions*****************)

module P = struct
  type t = Ledger_proof_with_sok_message.t
end

module Make_statement_scanner (Verifier : sig
  type t

  val verify : verifier:t -> P.t list -> bool Deferred.Or_error.t
end) =
struct
  module Fold = Parallel_scan.State.Make_foldable (Deferred)

  let logger = lazy (Logger.create ())

  module Timer = struct
    module Info = struct
      module Time_span = struct
        type t = Time.Span.t

        let to_yojson t = `Float (Time.Span.to_ms t)
      end

      type t =
        { total : Time_span.t
        ; count : int
        ; min : Time_span.t
        ; max : Time_span.t
        }
      [@@deriving to_yojson]

      let singleton time = { total = time; count = 1; max = time; min = time }

      let update (t : t) time =
        { total = Time.Span.( + ) t.total time
        ; count = t.count + 1
        ; min = Time.Span.min t.min time
        ; max = Time.Span.max t.max time
        }
    end

    type t = Info.t String.Table.t

    let create () : t = String.Table.create ()

    let time (t : t) label f =
      let start = Time.now () in
      let x = f () in
      let elapsed = Time.(diff (now ()) start) in
      Hashtbl.update t label ~f:(function
        | None ->
            Info.singleton elapsed
        | Some acc ->
            Info.update acc elapsed ) ;
      x

    let log label (t : t) =
      let logger = Lazy.force logger in
      [%log debug]
        ~metadata:
          (List.map (Hashtbl.to_alist t) ~f:(fun (k, info) ->
               (k, Info.to_yojson info) ) )
        "%s timing" label
  end

  (*TODO: fold over the pending_coinbase tree and validate the statements?*)
  let scan_statement ~constraint_constants
      ({ scan_state = tree; previous_incomplete_zkapp_updates } : t)
      ~statement_check ~verifier :
      ( Transaction_snark.Statement.t
      , [ `Error of Error.t | `Empty ] )
      Deferred.Result.t =
    let open Deferred.Or_error.Let_syntax in
    let timer = Timer.create () in
    let yield_occasionally =
      let f = Staged.unstage (Async.Scheduler.yield_every ~n:50) in
      fun () -> f () |> Deferred.map ~f:Or_error.return
    in
    let yield_always () =
      Async.Scheduler.yield () |> Deferred.map ~f:Or_error.return
    in
    let module Acc = struct
      type t = (Transaction_snark.Statement.t * P.t list) option
    end in
    let write_error description =
      sprintf !"Staged_ledger.scan_statement: %s\n" description
    in
    let with_error ~f message =
      let result = f () in
      Deferred.Result.map_error result ~f:(fun e ->
          Error.createf !"%s: %{sexp:Error.t}" (write_error message) e )
    in
    let merge_acc ~proofs (acc : Acc.t) s2 : Acc.t Deferred.Or_error.t =
      Timer.time timer (sprintf "merge_acc:%s" __LOC__) (fun () ->
          with_error "Bad merge proof" ~f:(fun () ->
              match acc with
              | None ->
                  return (Some (s2, proofs))
              | Some (s1, ps) ->
                  let%bind merged_statement =
                    Deferred.return (Transaction_snark.Statement.merge s1 s2)
                  in
                  let%map () = yield_occasionally () in
                  Some (merged_statement, proofs @ ps) ) )
    in
    let merge_pc (acc : Transaction_snark.Statement.t option) s2 :
        Transaction_snark.Statement.t option Or_error.t =
      let open Or_error.Let_syntax in
      match acc with
      | None ->
          Ok (Some s2)
      | Some s1 ->
          let%map () =
            if
              Pending_coinbase.Stack.connected
                ~prev:(Some s1.source.pending_coinbase_stack)
                ~first:s1.target.pending_coinbase_stack
                ~second:s2.source.pending_coinbase_stack ()
            then return ()
            else
              Or_error.errorf
                !"Base merge proof: invalid pending coinbase transition s1: \
                  %{sexp: Transaction_snark.Statement.t} s2: %{sexp: \
                  Transaction_snark.Statement.t}"
                s1 s2
          in
          Some s2
    in
    let fold_step_a (acc_statement, acc_pc) job =
      match job with
      | Parallel_scan.Merge.Job.Part (proof, message) ->
          let statement = Ledger_proof.statement proof in
          let%map acc_stmt =
            merge_acc ~proofs:[ (proof, message) ] acc_statement statement
          in
          (acc_stmt, acc_pc)
      | Empty | Full { status = Parallel_scan.Job_status.Done; _ } ->
          return (acc_statement, acc_pc)
      | Full { left = proof_1, message_1; right = proof_2, message_2; _ } ->
          let stmt1 = Ledger_proof.statement proof_1 in
          let stmt2 = Ledger_proof.statement proof_2 in
          let%bind merged_statement =
            Timer.time timer (sprintf "merge:%s" __LOC__) (fun () ->
                Deferred.return (Transaction_snark.Statement.merge stmt1 stmt2) )
          in
          let%map acc_stmt =
            merge_acc acc_statement merged_statement
              ~proofs:[ (proof_1, message_1); (proof_2, message_2) ]
          in
          (acc_stmt, acc_pc)
    in
    let check_base (acc_statement, acc_pc) transaction =
      with_error "Bad base statement" ~f:(fun () ->
          let%bind expected_statement =
            match statement_check with
            | `Full get_state ->
                let%bind result =
                  Timer.time timer
                    (sprintf "create_expected_statement:%s" __LOC__) (fun () ->
                      Deferred.return
                        (create_expected_statement ~constraint_constants
                           ~get_state transaction ) )
                in
                let%map () = yield_always () in
                result
            | `Partial ->
                return transaction.statement
          in
          let%bind () = yield_always () in
          if
            Transaction_snark.Statement.equal transaction.statement
              expected_statement
          then
            let%bind acc_stmt =
              merge_acc ~proofs:[] acc_statement transaction.statement
            in
            let%map acc_pc =
              merge_pc acc_pc transaction.statement |> Deferred.return
            in
            (acc_stmt, acc_pc)
          else
            Deferred.Or_error.error_string
              (sprintf
                 !"Bad base statement expected: \
                   %{sexp:Transaction_snark.Statement.t} got: \
                   %{sexp:Transaction_snark.Statement.t}"
                 transaction.statement expected_statement ) )
    in
    let fold_step_d (acc_statement, acc_pc) job =
      match job with
      | Parallel_scan.Base.Job.Empty ->
          return (acc_statement, acc_pc)
      | Full
          { status = Parallel_scan.Job_status.Done
          ; job = (transaction : Transaction_with_witness.t)
          ; _
          } ->
          let%map acc_pc =
            Deferred.return (merge_pc acc_pc transaction.statement)
          in
          (acc_statement, acc_pc)
      | Full { job = transaction; _ } ->
          check_base (acc_statement, acc_pc) transaction
    in
    let%bind.Deferred res =
      let%bind previous_zkapp_updates =
        Deferred.Or_error.List.fold ~init:(None, None)
          previous_incomplete_zkapp_updates ~f:check_base
      in
      Fold.fold_chronological_until tree ~init:previous_zkapp_updates
        ~f_merge:(fun acc (_weight, job) ->
          let open Container.Continue_or_stop in
          match%map.Deferred fold_step_a acc job with
          | Ok next ->
              Continue next
          | e ->
              Stop e )
        ~f_base:(fun acc (_weight, job) ->
          let open Container.Continue_or_stop in
          match%map.Deferred fold_step_d acc job with
          | Ok next ->
              Continue next
          | e ->
              Stop e )
        ~finish:return
    in
    Timer.log "scan_statement" timer ;
    match res with
    | Ok (None, _) ->
        Deferred.return (Error `Empty)
    | Ok (Some (res, proofs), _) -> (
        match%map.Deferred Verifier.verify ~verifier proofs with
        | Ok true ->
            Ok res
        | Ok false ->
            Error (`Error (Error.of_string "Bad proofs"))
        | Error e ->
            Error (`Error e) )
    | Error e ->
        Deferred.return (Error (`Error e))

  let check_invariants t ~constraint_constants ~statement_check ~verifier
      ~error_prefix
      ~(registers_begin :
         ( Frozen_ledger_hash.t
         , Pending_coinbase.Stack.t
         , Mina_state.Local_state.t )
         Mina_state.Registers.t
         option )
      ~(registers_end :
         ( Frozen_ledger_hash.t
         , Pending_coinbase.Stack.t
         , Mina_state.Local_state.t )
         Mina_state.Registers.t ) =
    let clarify_error cond err =
      if not cond then Or_error.errorf "%s : %s" error_prefix err else Ok ()
    in
    let check_registers (reg1 : _ Mina_state.Registers.t)
        (reg2 : _ Mina_state.Registers.t) =
      let open Or_error.Let_syntax in
      let%map () =
        clarify_error
          (Frozen_ledger_hash.equal reg1.first_pass_ledger
             reg2.first_pass_ledger )
          "did not connect with snarked fee payment ledger hash"
      and () =
        clarify_error
          (Frozen_ledger_hash.equal reg1.second_pass_ledger
             reg2.second_pass_ledger )
          "did not connect with snarked parties ledger hash"
      and () =
        clarify_error
          (Pending_coinbase.Stack.connected ~first:reg1.pending_coinbase_stack
             ~second:reg2.pending_coinbase_stack () )
          "did not connect with pending-coinbase stack"
      and () =
        clarify_error
          (Mina_transaction_logic.Zkapp_command_logic.Local_state.Value.equal
             reg1.local_state reg2.local_state )
          "did not connect with local state"
      in
      ()
    in
    match%map
      O1trace.sync_thread "validate_transaction_snark_scan_state" (fun () ->
          scan_statement t ~constraint_constants ~statement_check ~verifier )
    with
    | Error (`Error e) ->
        Error e
    | Error `Empty ->
        Option.value_map ~default:(Ok ()) registers_begin
          ~f:(fun registers_begin ->
            check_registers registers_begin registers_end )
    | Ok
        { fee_excess = { fee_token_l; fee_excess_l; fee_token_r; fee_excess_r }
        ; source
        ; target
        ; connecting_ledger_left = _
        ; connecting_ledger_right = _
        ; supply_increase = _
        ; sok_digest = ()
        } ->
        let open Or_error.Let_syntax in
        let _connecting_ledger_left = failwith "TODO check connecting ledger" in
        let _connecting_ledger_right =
          failwith "TODO check connecting ledger"
        in
        let%map () =
          Option.value_map ~default:(Ok ()) registers_begin
            ~f:(fun registers_begin -> check_registers registers_begin source)
        and () = check_registers registers_end target
        and () =
          clarify_error
            (Fee.Signed.equal Fee.Signed.zero fee_excess_l)
            "nonzero fee excess"
        and () =
          clarify_error
            (Fee.Signed.equal Fee.Signed.zero fee_excess_r)
            "nonzero fee excess"
        and () =
          clarify_error
            (Token_id.equal Token_id.default fee_token_l)
            "nondefault fee token"
        and () =
          clarify_error
            (Token_id.equal Token_id.default fee_token_r)
            "nondefault fee token"
        in
        ()
end

let statement_of_job : job -> Transaction_snark.Statement.t option = function
  | Base { statement; _ } ->
      Some statement
  | Merge ((p1, _), (p2, _)) ->
      Transaction_snark.Statement.merge
        (Ledger_proof.statement p1)
        (Ledger_proof.statement p2)
      |> Result.ok

let create ~work_delay ~transaction_capacity_log_2 : t =
  let k = Int.pow 2 transaction_capacity_log_2 in
  { scan_state = Parallel_scan.empty ~delay:work_delay ~max_base_jobs:k
  ; previous_incomplete_zkapp_updates = []
  }

let empty ~(constraint_constants : Genesis_constants.Constraint_constants.t) ()
    =
  create ~work_delay:constraint_constants.work_delay
    ~transaction_capacity_log_2:constraint_constants.transaction_capacity_log_2

module Transactions_ordered = struct
  module Poly = struct
    type 'a t =
      { first_pass : 'a list
      ; second_pass : 'a list
      ; previous_incomplete : 'a list
      ; current_incomplete : 'a list
      }
    [@@deriving sexp, to_yojson]
  end

  type t = Transaction_with_witness.t Poly.t [@@deriving sexp, to_yojson]

  let map (t : 'a Poly.t) ~f : 'b Poly.t =
    let f = List.map ~f in
    { Poly.first_pass = f t.first_pass
    ; second_pass = f t.second_pass
    ; previous_incomplete = f t.previous_incomplete
    ; current_incomplete = f t.current_incomplete
    }

  let fold (t : 'a Poly.t) ~f ~init =
    let init = List.fold ~init t.first_pass ~f in
    let init = List.fold ~init t.previous_incomplete ~f in
    let init = List.fold ~init t.second_pass ~f in
    List.fold ~init t.current_incomplete ~f

  let first_and_second_pass_transactions_per_tree ~previous_incomplete
      (txns_per_tree : Transaction_with_witness.t list) =
    let complete_and_incomplete_transactions = function
      | [] ->
          None
      | (h : Transaction_with_witness.t) :: _ as txns_with_witnesses ->
          let target_first_pass_ledger = h.statement.source.first_pass_ledger in
          let first_pass_txns, second_pass_txns, target_first_pass_ledger =
            let first_pass_txns, second_pass_txns, target_first_pass_ledger =
              List.fold ~init:([], [], target_first_pass_ledger)
                txns_with_witnesses
                ~f:(fun
                     (first_pass_txns, second_pass_txns, second_pass_ledger_hash)
                     (txn_with_witness : Transaction_with_witness.t)
                   ->
                  let txn =
                    Ledger.Transaction_applied.transaction
                      txn_with_witness.transaction_with_info
                  in
                  match txn.data with
                  | Transaction.Coinbase _
                  | Fee_transfer _
                  | Command (User_command.Signed_command _) ->
                      ( txn_with_witness :: first_pass_txns
                      , second_pass_txns
                      , second_pass_ledger_hash )
                  | Command (Zkapp_command _) ->
                      let target_first_pass_ledger =
                        txn_with_witness.statement.target.first_pass_ledger
                      in
                      ( txn_with_witness :: first_pass_txns
                      , txn_with_witness :: second_pass_txns
                      , target_first_pass_ledger ) )
            in
            ( List.rev first_pass_txns
            , List.rev second_pass_txns
            , target_first_pass_ledger )
          in
          let second_pass_txns, incomplete_txns =
            match List.hd second_pass_txns with
            | None ->
                ([], [])
            | Some txn_with_witness ->
                if
                  Frozen_ledger_hash.equal
                    txn_with_witness.statement.source.second_pass_ledger
                    target_first_pass_ledger
                then
                  (*second pass completed in the same tree*)
                  (second_pass_txns, [])
                else ([], second_pass_txns)
          in
          let previous_incomplete =
            match previous_incomplete with
            | [] ->
                []
            | (t : Transaction_with_witness.t) :: _ ->
                if State_hash.equal (fst t.state_hash) (fst h.state_hash) then
                  (*same block*)
                  previous_incomplete
                else []
          in
          Some
            { Poly.first_pass = first_pass_txns
            ; second_pass = second_pass_txns
            ; current_incomplete = incomplete_txns
            ; previous_incomplete
            }
    in
    let txns_by_block (txns_per_tree : Transaction_with_witness.t list) =
      List.group txns_per_tree ~break:(fun t1 t2 ->
          State_hash.equal (fst t1.state_hash) (fst t2.state_hash) |> not )
    in
    List.filter_map ~f:complete_and_incomplete_transactions
      (txns_by_block txns_per_tree)

  let first_and_second_pass_transactions_per_forest scan_state_txns
      ~previous_incomplete =
    List.map scan_state_txns
      ~f:(first_and_second_pass_transactions_per_tree ~previous_incomplete)
end

let extract_txn (txn_with_witness : Transaction_with_witness.t) =
  let txn =
    Ledger.Transaction_applied.transaction
      txn_with_witness.transaction_with_info
  in
  let state_hash = fst txn_with_witness.state_hash in
  (txn, state_hash)

let latest_ledger_proof t =
  let open Option.Let_syntax in
  let%map proof, txns_with_witnesses =
    Parallel_scan.last_emitted_value t.scan_state
  in
  let txns =
    Transactions_ordered.first_and_second_pass_transactions_per_tree
      txns_with_witnesses
      ~previous_incomplete:t.previous_incomplete_zkapp_updates
  in
  (proof, List.map txns ~f:(Transactions_ordered.map ~f:extract_txn))

let incomplete_txns_from_recent_proof_tree t =
  let open Option.Let_syntax in
  let%map proof, txns_with_witnesses =
    Parallel_scan.last_emitted_value t.scan_state
  in
  let txns_per_block =
    Transactions_ordered.first_and_second_pass_transactions_per_tree
      txns_with_witnesses
      ~previous_incomplete:t.previous_incomplete_zkapp_updates
  in
  let txns =
    match List.last txns_per_block with
    | None ->
        []
    | Some txns_in_last_block ->
        txns_in_last_block.current_incomplete
  in
  (proof, txns)

let staged_transactions t =
  let previous_incomplete =
    Option.value_map ~default:[]
      (incomplete_txns_from_recent_proof_tree t)
      ~f:snd
  in
  Transactions_ordered.first_and_second_pass_transactions_per_forest
    (Parallel_scan.pending_data t.scan_state)
    ~previous_incomplete
  |> List.concat

(*All the transactions in the order in which they were applied along with the parent protocol state of the blocks that contained them*)
let staged_transactions_with_state_hash t =
  let pending_transactions_per_block = staged_transactions t in
  List.map pending_transactions_per_block
    ~f:(Transactions_ordered.map ~f:extract_txn)

let apply_ordered_txns ordered_txns ~ledger ~get_protocol_state
    ~apply_first_pass ~apply_second_pass =
  let open Or_error.Let_syntax in
  let go ~apply txns =
    let apply t state_hash =
      match get_protocol_state state_hash with
      | Ok state ->
          let txn_state_view =
            Mina_state.Protocol_state.body state
            |> Mina_state.Protocol_state.Body.view
          in
          apply ~txn_state_view ledger t
      | Error e ->
          Or_error.errorf
            !"Coudln't find protocol state with hash %s: %s"
            (State_hash.to_base58_check state_hash)
            (Error.to_string_hum e)
    in
    List.fold_until txns ~init:(Ok ())
      ~f:(fun _acc ((t : Transaction.t With_status.t), state_hash) ->
        match apply t.data state_hash with
        | Ok _ ->
            Continue (Ok ())
        | Error e ->
            Stop (Error e) )
      ~finish:Fn.id
  in
  List.fold_until ordered_txns ~init:(Ok [])
    ~f:(fun acc (txns_per_block : _ Transactions_ordered.Poly.t) ->
      match
        let%bind previous_incomplete = acc in
        let%bind () = go txns_per_block.first_pass ~apply:apply_first_pass in
        let%bind () = go previous_incomplete ~apply:apply_second_pass in
        let%map () = go txns_per_block.second_pass ~apply:apply_second_pass in
        txns_per_block.current_incomplete
      with
      | Ok current_incomplete ->
          Continue (Ok current_incomplete)
      | Error e ->
          Stop (Error e) )
    ~finish:Fn.id
  |> Or_error.ignore_m

let apply_last_proof_transactions ~ledger ~get_protocol_state ~apply_first_pass
    ~apply_second_pass t =
  match latest_ledger_proof t with
  | None ->
      Or_error.errorf "No transactions found"
  | Some (_, txns_per_block) ->
      apply_ordered_txns txns_per_block ~ledger ~get_protocol_state
        ~apply_first_pass ~apply_second_pass

let apply_staged_transactions ~ledger ~get_protocol_state ~apply_first_pass
    ~apply_second_pass t =
  let staged_transactions_with_state_hash =
    staged_transactions_with_state_hash t
  in
  apply_ordered_txns staged_transactions_with_state_hash ~ledger
    ~get_protocol_state ~apply_first_pass ~apply_second_pass

let free_space t = Parallel_scan.free_space t.scan_state

(*This needs to be grouped like in work_to_do function. Group of two jobs per list and not group of two jobs after concatenating the lists*)
let all_jobs t = Parallel_scan.all_jobs t.scan_state

let next_on_new_tree t = Parallel_scan.next_on_new_tree t.scan_state

let base_jobs_on_latest_tree t =
  Parallel_scan.base_jobs_on_latest_tree t.scan_state

let base_jobs_on_earlier_tree t =
  Parallel_scan.base_jobs_on_earlier_tree t.scan_state

let partition_if_overflowing t =
  let bundle_count work_count = (work_count + 1) / 2 in
  let { Space_partition.first = slots, job_count; second } =
    Parallel_scan.partition_if_overflowing t.scan_state
  in
  { Space_partition.first = (slots, bundle_count job_count)
  ; second =
      Option.map second ~f:(fun (slots, job_count) ->
          (slots, bundle_count job_count) )
  }

let extract_from_job (job : job) =
  match job with
  | Parallel_scan.Available_job.Base d ->
      First
        ( d.transaction_with_info
        , d.statement
        , d.state_hash
        , d.first_pass_ledger_witness
        , d.second_pass_ledger_witness
        , d.init_stack )
  | Merge ((p1, _), (p2, _)) ->
      Second (p1, p2)

let snark_job_list_json t =
  let all_jobs : Job_view.t list list =
    let fa (a : Ledger_proof_with_sok_message.t) =
      Ledger_proof.statement (fst a)
    in
    let fd (d : Transaction_with_witness.t) = d.statement in
    Parallel_scan.view_jobs_with_position t.scan_state fa fd
  in
  Yojson.Safe.to_string
    (`List
      (List.map all_jobs ~f:(fun tree ->
           `List (List.map tree ~f:Job_view.to_yojson) ) ) )

(*Always the same pairing of jobs*)
let all_work_statements_exn t : Transaction_snark_work.Statement.t list =
  let work_seqs = all_jobs t in
  List.concat_map work_seqs ~f:(fun work_seq ->
      One_or_two.group_list
        (List.map work_seq ~f:(fun job ->
             match statement_of_job job with
             | None ->
                 assert false
             | Some stmt ->
                 stmt ) ) )

let required_work_pairs t ~slots =
  let work_list = Parallel_scan.jobs_for_slots t.scan_state ~slots in
  List.concat_map work_list ~f:(fun works -> One_or_two.group_list works)

let k_work_pairs_for_new_diff t ~k =
  let work_list = Parallel_scan.jobs_for_next_update t.scan_state in
  List.(
    take (concat_map work_list ~f:(fun works -> One_or_two.group_list works)) k)

(*Always the same pairing of jobs*)
let work_statements_for_new_diff t : Transaction_snark_work.Statement.t list =
  let work_list = Parallel_scan.jobs_for_next_update t.scan_state in
  List.concat_map work_list ~f:(fun work_seq ->
      One_or_two.group_list
        (List.map work_seq ~f:(fun job ->
             match statement_of_job job with
             | None ->
                 assert false
             | Some stmt ->
                 stmt ) ) )

(* TODO *)
let all_work_pairs t
    ~(get_state : State_hash.t -> Mina_state.Protocol_state.value Or_error.t) :
    (Transaction_witness.t, Ledger_proof.t) Snark_work_lib.Work.Single.Spec.t
    One_or_two.t
    list
    Or_error.t =
  let all_jobs = all_jobs t in
  let module A = Available_job in
  let open Or_error.Let_syntax in
  let single_spec (job : job) =
    match extract_from_job job with
    | First
        ( transaction_with_info
        , statement
        , state_hash
        , first_pass_ledger_witness
        , second_pass_ledger_witness
        , init_stack ) ->
        let%map witness =
          let { With_status.data = transaction; status } =
            Mina_transaction_logic.Transaction_applied.transaction_with_status
              transaction_with_info
          in
          let%bind protocol_state_body =
            let%map state = get_state (fst state_hash) in
            Mina_state.Protocol_state.body state
          in
          let%map init_stack =
            match init_stack with
            | Base x ->
                Ok x
            | Merge ->
                Or_error.error_string "init_stack was Merge"
          in
          let () =
            let _ = second_pass_ledger_witness in
            failwith "TODO (second_pass_ledger_witness unused)"
          in
          { Transaction_witness.ledger = first_pass_ledger_witness
          ; transaction
          ; protocol_state_body
          ; init_stack
          ; status
          }
        in
        Snark_work_lib.Work.Single.Spec.Transition (statement, witness)
    | Second (p1, p2) ->
        let%map merged =
          Transaction_snark.Statement.merge
            (Ledger_proof.statement p1)
            (Ledger_proof.statement p2)
        in
        Snark_work_lib.Work.Single.Spec.Merge (merged, p1, p2)
  in
  List.fold_until all_jobs ~init:[]
    ~finish:(fun lst -> Ok lst)
    ~f:(fun acc jobs ->
      let specs_list : 'a One_or_two.t list Or_error.t =
        List.fold ~init:(Ok []) (One_or_two.group_list jobs)
          ~f:(fun acc' pair ->
            let%bind acc' = acc' in
            let%map spec = One_or_two.Or_error.map ~f:single_spec pair in
            spec :: acc' )
      in
      match specs_list with
      | Ok list ->
          Continue (acc @ List.rev list)
      | Error e ->
          Stop (Error e) )

let update_metrics t = Parallel_scan.update_metrics t.scan_state

let fill_work_and_enqueue_transactions t transactions work =
  let open Or_error.Let_syntax in
  let fill_in_transaction_snark_work tree (works : Transaction_snark_work.t list)
      : (Ledger_proof.t * Sok_message.t) list Or_error.t =
    let next_jobs =
      List.(
        take
          (concat @@ Parallel_scan.jobs_for_next_update tree)
          (total_proofs works))
    in
    map2_or_error next_jobs
      (List.concat_map works
         ~f:(fun { Transaction_snark_work.fee; proofs; prover } ->
           One_or_two.map proofs ~f:(fun proof -> (fee, proof, prover))
           |> One_or_two.to_list ) )
      ~f:completed_work_to_scanable_work
  in
  (*get incomplete transactions from previous proof which will be completed in
     the new proof, if there's one*)
  let old_proof_and_incomplete_zkapp_updates =
    incomplete_txns_from_recent_proof_tree t
  in
  let%bind work_list = fill_in_transaction_snark_work t.scan_state work in
  let%bind proof_opt, updated_scan_state =
    Parallel_scan.update t.scan_state ~completed_jobs:work_list
      ~data:transactions
  in
  let%map result_opt, previous_incomplete_zkapp_updates =
    Option.value_map
      ~default:(Ok (None, t.previous_incomplete_zkapp_updates))
      proof_opt
      ~f:(fun ((proof, _), txns_with_witnesses) ->
        let curr_source = (Ledger_proof.statement proof).source in
        (*TODO: get genesis ledger hash if the old_proof is none*)
        let prev_target, incomplete_zkapp_updates_from_old_proof =
          Option.value_map ~default:(curr_source, [])
            old_proof_and_incomplete_zkapp_updates
            ~f:(fun ((p', _), incomplete_zkapp_updates_from_old_proof) ->
              ( (Ledger_proof.statement p').target
              , incomplete_zkapp_updates_from_old_proof ) )
        in
        (*prev_target is connected to curr_source- Order of the arguments is
          important here*)
        if Mina_state.Registers.Value.connected prev_target curr_source then
          let txns =
            Transactions_ordered.first_and_second_pass_transactions_per_tree
              txns_with_witnesses
              ~previous_incomplete:incomplete_zkapp_updates_from_old_proof
          in
          Ok
            ( Some
                ( proof
                , List.map txns ~f:(Transactions_ordered.map ~f:extract_txn) )
            , incomplete_zkapp_updates_from_old_proof )
        else Or_error.error_string "Unexpected ledger proof emitted" )
  in
  ( result_opt
  , { scan_state = updated_scan_state; previous_incomplete_zkapp_updates } )

let required_state_hashes t =
  List.fold ~init:State_hash.Set.empty
    ~f:(fun acc (txns : Transactions_ordered.t) ->
      Transactions_ordered.fold ~init:acc txns
        ~f:(fun acc (t : Transaction_with_witness.t) ->
          Set.add acc (fst t.state_hash) ) )
    (staged_transactions t)

let check_required_protocol_states t ~protocol_states =
  let open Or_error.Let_syntax in
  let required_state_hashes = required_state_hashes t in
  let check_length states =
    let required = State_hash.Set.length required_state_hashes in
    let received = List.length states in
    if required = received then Or_error.return ()
    else
      Or_error.errorf
        !"Required %d protocol states but received %d"
        required received
  in
  (*Don't check further if the lengths dont match*)
  let%bind () = check_length protocol_states in
  let received_state_map =
    List.fold protocol_states ~init:Mina_base.State_hash.Map.empty
      ~f:(fun m ps ->
        State_hash.Map.set m
          ~key:(State_hash.With_state_hashes.state_hash ps)
          ~data:ps )
  in
  let protocol_states_assoc =
    List.filter_map
      (State_hash.Set.to_list required_state_hashes)
      ~f:(State_hash.Map.find received_state_map)
  in
  let%map () = check_length protocol_states_assoc in
  protocol_states_assoc
