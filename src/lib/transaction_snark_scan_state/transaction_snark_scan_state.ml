open Core_kernel
open Async
open Mina_base
open Mina_transaction
open Currency
module Ledger = Mina_ledger.Ledger
module Sparse_ledger = Mina_ledger.Sparse_ledger

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
    [@@@no_toplevel_latest_type]

    module V3 = struct
      (* TODO: The statement is redundant here - it can be computed from the
         witness and the transaction
      *)
      type t =
        { transaction_with_status :
            Mina_transaction.Transaction.Stable.V3.t With_status.Stable.V2.t
        ; state_hash : State_hash.Stable.V1.t * State_body_hash.Stable.V1.t
        ; statement : Transaction_snark.Statement.Stable.V2.t
        ; init_stack : Pending_coinbase.Stack_versioned.Stable.V1.t
        ; first_pass_ledger_witness :
            (Mina_ledger.Sparse_ledger.Stable.V3.t[@sexp.opaque])
        ; second_pass_ledger_witness :
            (Mina_ledger.Sparse_ledger.Stable.V3.t[@sexp.opaque])
        ; block_global_slot : Mina_numbers.Global_slot_since_genesis.Stable.V1.t
        }
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  type t =
    { transaction_with_status : Mina_transaction.Transaction.t With_status.t
    ; state_hash : State_hash.t * State_body_hash.t
    ; statement : Transaction_snark.Statement.t
    ; init_stack : Pending_coinbase.Stack_versioned.t
    ; first_pass_ledger_witness : Mina_ledger.Sparse_ledger.t
    ; second_pass_ledger_witness : Mina_ledger.Sparse_ledger.t
    ; block_global_slot : Mina_numbers.Global_slot_since_genesis.t
    ; hash : Aux_hash.t
    }

  let hash (v : Stable.Latest.t) : Aux_hash.t =
    let h = Digestif.SHA256.init () in
    let h =
      Binable.to_string (module Stable.Latest) v
      |> Digestif.SHA256.feed_string h
    in
    Digestif.SHA256.get h |> Aux_hash.of_sha256

  let create
      ~(transaction_with_status : Mina_transaction.Transaction.t With_status.t)
      ~(state_hash : State_hash.t * State_body_hash.t)
      ~(statement : Transaction_snark.Statement.t)
      ~(init_stack : Pending_coinbase.Stack_versioned.t)
      ~(first_pass_ledger_witness : Mina_ledger.Sparse_ledger.t)
      ~(second_pass_ledger_witness : Mina_ledger.Sparse_ledger.t)
      ~(block_global_slot : Mina_numbers.Global_slot_since_genesis.t) : t =
    let (v : Stable.Latest.t) =
      { Stable.Latest.transaction_with_status =
          With_status.map transaction_with_status
            ~f:Mina_transaction.Transaction.read_all_proofs_from_disk
      ; Stable.Latest.state_hash
      ; statement
      ; init_stack
      ; first_pass_ledger_witness
      ; second_pass_ledger_witness
      ; block_global_slot
      }
    in
    { transaction_with_status
    ; state_hash
    ; statement
    ; init_stack
    ; first_pass_ledger_witness
    ; second_pass_ledger_witness
    ; block_global_slot
    ; hash = hash v
    }

  let write_all_proofs_to_disk ~signature_kind ~proof_cache_db
      ( { Stable.Latest.transaction_with_status
        ; state_hash
        ; statement
        ; init_stack
        ; first_pass_ledger_witness
        ; second_pass_ledger_witness
        ; block_global_slot
        } as v ) =
    { transaction_with_status =
        With_status.map transaction_with_status
          ~f:
            (Mina_transaction.Transaction.write_all_proofs_to_disk
               ~signature_kind ~proof_cache_db )
    ; state_hash
    ; statement
    ; init_stack
    ; first_pass_ledger_witness
    ; second_pass_ledger_witness
    ; block_global_slot
    ; hash = hash v
    }

  let read_all_proofs_from_disk
      { transaction_with_status
      ; state_hash
      ; statement
      ; init_stack
      ; first_pass_ledger_witness
      ; second_pass_ledger_witness
      ; block_global_slot
      ; _
      } =
    { Stable.Latest.transaction_with_status =
        With_status.map transaction_with_status
          ~f:Mina_transaction.Transaction.read_all_proofs_from_disk
    ; state_hash
    ; statement
    ; init_stack
    ; first_pass_ledger_witness
    ; second_pass_ledger_witness
    ; block_global_slot
    }
end

module Ledger_proof_with_hash = struct
  let hash (v : Ledger_proof.Stable.Latest.t) =
    let h = Digestif.SHA256.init () in
    let h =
      Binable.to_string (module Ledger_proof.Stable.Latest) v
      |> Digestif.SHA256.feed_string h
    in
    Digestif.SHA256.get h |> Aux_hash.of_sha256

  type t = (Ledger_proof.Cached.t, Aux_hash.t) With_hash.t

  let create : Ledger_proof.Cached.t -> t =
    let hash_data p = hash (Ledger_proof.Cached.read_proof_from_disk p) in
    fun p -> With_hash.of_data ~hash_data p
end

module Available_job = struct
  type t =
    ( Ledger_proof_with_hash.t
    , Transaction_with_witness.t )
    Parallel_scan.Available_job.t
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
      (* [seq_no] is gone from the scan state, and a merge node's status is
         always [Todo] now that a completed merge is cleared rather than
         marked; only a base still has one worth reporting. *)
      match value with
      | Base_empty ->
          `Assoc [ ("B", `List []) ]
      | Merge_empty ->
          `Assoc [ ("M", `List []) ]
      | Merge_part x ->
          `Assoc [ ("M", `List [ statement_to_yojson x ]) ]
      | Merge_full { left; right } ->
          `Assoc
            [ ( "M"
              , `List [ statement_to_yojson left; statement_to_yojson right ] )
            ]
      | Base_full { job; status } ->
          `Assoc
            [ ( "B"
              , `List
                  [ statement_to_yojson job
                  ; `Assoc
                      [ ( "Status"
                        , `String (Parallel_scan.Job_status.to_string status) )
                      ]
                  ] )
            ]
    in
    `List [ `Int position; job_to_yojson ]
end

type job = Available_job.t

(* Both payload types carry their own hash — a SHA256 of their [bin_prot]
   encoding — which is exactly what the scan state's Merkle tree needs, and
   why maintaining that tree costs no proof hashing. *)
let payload_digest :
    ( Ledger_proof_with_hash.t
    , Transaction_with_witness.t )
    Parallel_scan.Payload_digest.t =
  { merge = (fun (x : Ledger_proof_with_hash.t) -> x.hash)
  ; base = (fun (x : Transaction_with_witness.t) -> x.hash)
  }

let stable_payload_digest :
    ( Ledger_proof.Stable.V3.t
    , Transaction_with_witness.Stable.V3.t )
    Parallel_scan.Payload_digest.t =
  { merge = Ledger_proof_with_hash.hash; base = Transaction_with_witness.hash }

(* The scan state's own commitment needs no callbacks: it is a Merkle tree
   whose digests the structure already maintains. [tx_witness_hash] is still
   needed for [previous_incomplete_zkapp_updates], which sits alongside the
   scan state rather than in it. *)
let hash_generic :
    type a b.
       tx_witness_hash:(b -> string)
    -> (a, b) Parallel_scan.t
       * (b list * [ `Border_block_continued_in_the_next_tree of bool ])
    -> Staged_ledger_hash.Aux_hash.t =
 fun ~tx_witness_hash (parallel_scan_state, previous_incomplete_zkapp_updates) ->
  let state_hash = Parallel_scan.hash parallel_scan_state in
  let ( previous_incomplete_zkapp_updates
      , `Border_block_continued_in_the_next_tree continue_in_next_tree ) =
    previous_incomplete_zkapp_updates
  in
  let incomplete_updates =
    List.fold ~init:(Digestif.SHA256.init ()) previous_incomplete_zkapp_updates
      ~f:(fun h t -> Digestif.SHA256.feed_string h (tx_witness_hash t))
    |> Digestif.SHA256.get
  in
  let continue_in_next_tree =
    Digestif.SHA256.digest_string (Bool.to_string continue_in_next_tree)
  in
  [ state_hash; incomplete_updates; continue_in_next_tree ]
  |> List.fold ~init:(Digestif.SHA256.init ()) ~f:(fun h t ->
         Digestif.SHA256.feed_string h (Digestif.SHA256.to_raw_string t) )
  |> Digestif.SHA256.get |> Staged_ledger_hash.Aux_hash.of_sha256

(*Scan state and any zkapp updates that were applied to the to the most recent
   snarked ledger but are from the tree just before the tree corresponding to
   the snarked ledger*)

(** The stored shape: proofs read back off disk, digests carried rather than
    derived.

    Unversioned, because nothing untrusted parses it. A scan state reaches
    another node through the sync protocol, in verified fragments; what remains
    here is the frontier's own persistence, and its database carries a version
    of its own for that. *)
module Stored = struct
  type t =
    { scan_state :
        ( Ledger_proof.Stable.V3.t
        , Transaction_with_witness.Stable.V3.t )
        Parallel_scan.Wire.t
    ; previous_incomplete_zkapp_updates :
        Transaction_with_witness.Stable.V3.t list
        * [ `Border_block_continued_in_the_next_tree of bool ]
    }
  [@@deriving bin_io_unversioned]

  let hash (t : t) =
    hash_generic
      ~tx_witness_hash:(fun (x : Transaction_with_witness.Stable.V3.t) ->
        Transaction_with_witness.hash x )
      ( Parallel_scan.of_wire t.scan_state ~payload_digest:stable_payload_digest
      , t.previous_incomplete_zkapp_updates )
end

type t =
  { scan_state :
      (Ledger_proof_with_hash.t, Transaction_with_witness.t) Parallel_scan.t
  ; previous_incomplete_zkapp_updates :
      Transaction_with_witness.t list
      * [ `Border_block_continued_in_the_next_tree of bool ]
  }

let hash (t : t) =
  hash_generic
    ~tx_witness_hash:(fun (x : Transaction_with_witness.t) -> x.hash)
    (t.scan_state, t.previous_incomplete_zkapp_updates)

(**********Helpers*************)

let create_expected_statement ~constraint_constants
    ~(get_state : State_hash.t -> Mina_state.Protocol_state.value Or_error.t)
    ~connecting_merkle_root
    { Transaction_with_witness.transaction_with_status
    ; state_hash
    ; first_pass_ledger_witness
    ; second_pass_ledger_witness
    ; init_stack = pending_coinbase_before
    ; statement
    ; block_global_slot
    ; _
    } =
  let open Or_error.Let_syntax in
  let source_first_pass_merkle_root =
    Frozen_ledger_hash.of_ledger_hash
    @@ Sparse_ledger.merkle_root first_pass_ledger_witness
  in
  let source_second_pass_merkle_root =
    Frozen_ledger_hash.of_ledger_hash
    @@ Sparse_ledger.merkle_root second_pass_ledger_witness
  in
  let transaction = transaction_with_status.data in
  let%bind protocol_state = get_state (fst state_hash) in
  let state_view = Mina_state.Protocol_state.Body.view protocol_state.body in
  let empty_local_state = Mina_state.Local_state.empty () in
  let%bind ( target_first_pass_merkle_root
           , target_second_pass_merkle_root
           , supply_increase ) =
    let%bind first_pass_ledger_after_apply, partially_applied_transaction =
      Sparse_ledger.apply_transaction_first_pass ~constraint_constants
        ~global_slot:block_global_slot ~txn_state_view:state_view
        first_pass_ledger_witness transaction
    in
    let%bind second_pass_ledger_after_apply, applied_transaction =
      Sparse_ledger.apply_transaction_second_pass second_pass_ledger_witness
        partially_applied_transaction
    in
    let target_first_pass_merkle_root =
      Sparse_ledger.merkle_root first_pass_ledger_after_apply
      |> Frozen_ledger_hash.of_ledger_hash
    in
    let target_second_pass_merkle_root =
      Sparse_ledger.merkle_root second_pass_ledger_after_apply
      |> Frozen_ledger_hash.of_ledger_hash
    in
    let%map supply_increase =
      Mina_transaction_logic.Transaction_applied.supply_increase
        ~constraint_constants applied_transaction
    in
    ( target_first_pass_merkle_root
    , target_second_pass_merkle_root
    , supply_increase )
  in
  let pending_coinbase_after =
    let state_body_hash = snd state_hash in
    let pending_coinbase_with_state =
      Pending_coinbase.Stack.push_state state_body_hash block_global_slot
        pending_coinbase_before
    in
    match transaction with
    | Coinbase c ->
        Pending_coinbase.Stack.push_coinbase c pending_coinbase_with_state
    | _ ->
        pending_coinbase_with_state
  in
  let%map fee_excess = Transaction.fee_excess transaction in
  { Transaction_snark.Statement.Poly.source =
      { first_pass_ledger = source_first_pass_merkle_root
      ; second_pass_ledger = source_second_pass_merkle_root
      ; pending_coinbase_stack = statement.source.pending_coinbase_stack
      ; local_state = empty_local_state
      }
  ; target =
      { first_pass_ledger = target_first_pass_merkle_root
      ; second_pass_ledger = target_second_pass_merkle_root
      ; pending_coinbase_stack = pending_coinbase_after
      ; local_state = empty_local_state
      }
  ; connecting_ledger_left = connecting_merkle_root
  ; connecting_ledger_right = connecting_merkle_root
  ; fee_excess
  ; supply_increase
  ; sok_digest = ()
  }

let total_proofs (works : Transaction_snark_work.t list) =
  List.sum (module Int) works ~f:(fun w -> One_or_two.length w.proofs)

(*************exposed functions*****************)

module Make_statement_scanner (Verifier : sig
  type t

  val verify :
       verifier:t
    -> Ledger_proof_with_hash.t list
    -> unit Or_error.t Deferred.Or_error.t
end) =
struct
  module Fold = Parallel_scan.Make_foldable (Deferred)

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

    type t = { table : Info.t String.Table.t; logger : Logger.t }

    let create ~logger () : t = { table = String.Table.create (); logger }

    let time (t : t) label f =
      let start = Time.now () in
      let x = f () in
      let elapsed = Time.(diff (now ()) start) in
      Hashtbl.update t.table label ~f:(function
        | None ->
            Info.singleton elapsed
        | Some acc ->
            Info.update acc elapsed ) ;
      x

    let log label (t : t) =
      [%log' debug t.logger]
        ~metadata:
          (List.map (Hashtbl.to_alist t.table) ~f:(fun (k, info) ->
               (k, Info.to_yojson info) ) )
        "%s timing" label
  end

  (*TODO: fold over the pending_coinbase tree and validate the statements?*)
  let scan_statement (type merge) ~constraint_constants ~logger
      ~merge_to_statement tree ~statement_check ~verify =
    let open Deferred.Or_error.Let_syntax in
    let timer = Timer.create ~logger () in
    let yield_occasionally =
      let f = Staged.unstage (Async.Scheduler.yield_every ~n:50) in
      fun () -> f () |> Deferred.map ~f:Or_error.return
    in
    let yield_always () =
      Async.Scheduler.yield () |> Deferred.map ~f:Or_error.return
    in
    let module Acc = struct
      type t = (Transaction_snark.Statement.t * merge list) option
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
      | Parallel_scan.Merge_node.Part merge ->
          let statement = merge_to_statement merge in
          let%map acc_stmt =
            merge_acc ~proofs:[ merge ] acc_statement statement
          in
          (acc_stmt, acc_pc)
      | Empty ->
          return (acc_statement, acc_pc)
      | Full { left; right; _ } ->
          let stmt1 = merge_to_statement left in
          let stmt2 = merge_to_statement right in
          let%bind merged_statement =
            Timer.time timer (sprintf "merge:%s" __LOC__) (fun () ->
                Deferred.return (Transaction_snark.Statement.merge stmt1 stmt2) )
          in
          let%map acc_stmt =
            merge_acc acc_statement merged_statement ~proofs:[ left; right ]
          in
          (acc_stmt, acc_pc)
    in
    let check_base (acc_statement, acc_pc)
        (transaction : Transaction_with_witness.t) =
      with_error "Bad base statement" ~f:(fun () ->
          let%bind expected_statement =
            match statement_check with
            | `Full get_state ->
                let%bind result =
                  Timer.time timer
                    (sprintf "create_expected_statement:%s" __LOC__) (fun () ->
                      Deferred.return
                        (create_expected_statement ~constraint_constants
                           ~get_state
                           ~connecting_merkle_root:
                             transaction.statement.connecting_ledger_left
                           transaction ) )
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
      | Parallel_scan.Base_node.Empty ->
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
      Fold.fold_chronological_until tree ~init:(None, None)
        ~f_merge:(fun acc job ->
          let open Container.Continue_or_stop in
          match%map.Deferred fold_step_a acc job with
          | Ok next ->
              Continue next
          | e ->
              Stop e )
        ~f_base:(fun acc job ->
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
        match%map.Deferred verify proofs with
        | Ok (Ok ()) ->
            Ok res
        | Ok (Error err) ->
            Error (`Error (Error.tag ~tag:"Verifier issue" err))
        | Error e ->
            Error (`Error e) )
    | Error e ->
        Deferred.return (Error (`Error e))

  let check_invariants_impl parallel_scan_state ~merge_to_statement
      ~constraint_constants ~logger ~statement_check ~verify ~error_prefix
      ~(last_proof_statement : Transaction_snark.Statement.t option)
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
          scan_statement parallel_scan_state ~constraint_constants ~logger
            ~statement_check ~verify ~merge_to_statement )
    with
    | Error (`Error e) ->
        Error e
    | Error `Empty ->
        Option.value_map ~default:(Ok ()) last_proof_statement
          ~f:(fun statement -> check_registers statement.target registers_end)
    | Ok
        ( { fee_excess = { fee_token_l; fee_excess_l; fee_token_r; fee_excess_r }
          ; source = _
          ; target
          ; connecting_ledger_left = _
          ; connecting_ledger_right = _
          ; supply_increase = _
          ; sok_digest = ()
          } as t ) ->
        let open Or_error.Let_syntax in
        let%map () =
          Option.value_map ~default:(Ok ()) last_proof_statement
            ~f:(fun statement ->
              Transaction_snark.Statement.merge statement t |> Or_error.ignore_m )
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

  let check_invariants (t : t) ~verifier =
    check_invariants_impl t.scan_state
      ~merge_to_statement:(fun (x : Ledger_proof_with_hash.t) ->
        Ledger_proof.Cached.statement x.data )
      ~verify:(Verifier.verify ~verifier)
end

let statement_of_job : job -> Transaction_snark.Statement.t option = function
  | Base { statement; _ } ->
      Some statement
  | Merge ({ data = p1; _ }, { data = p2; _ }) ->
      Transaction_snark.Statement.merge
        (Ledger_proof.Cached.statement p1)
        (Ledger_proof.Cached.statement p2)
      |> Result.ok

let create ~work_delay ~transaction_capacity_log_2 : t =
  let k = Int.pow 2 transaction_capacity_log_2 in
  { scan_state = Parallel_scan.empty ~delay:work_delay ~max_base_jobs:k
  ; previous_incomplete_zkapp_updates =
      ([], `Border_block_continued_in_the_next_tree false)
  }

let empty ~(constraint_constants : Genesis_constants.Constraint_constants.t) ()
    =
  create ~work_delay:constraint_constants.work_delay
    ~transaction_capacity_log_2:constraint_constants.transaction_capacity_log_2

module Transactions_ordered = struct
  module Poly = struct
    (** Represents sequence of transactions extracted from scan state
           when it emitted a proof, split into:

           * [first_pass] - transactions that went through first pass
           * [second_pass] - transactions that went through second pass and correspond
             to the current ledger proof (subset of first pass group)
           * [current_incomplete] - transactions that went through second pass and correspond
             to the the next ledger proof (subset of first pass group)
           * [previous_incomplete] - leftover from previous ledger proof emitted with
             the current ledger proof (not intersecting with other groups)
        *)
    type 'a t =
      { first_pass : 'a list
      ; second_pass : 'a list
      ; previous_incomplete : 'a list
      ; current_incomplete : 'a list
      }
    [@@deriving sexp, to_yojson]
  end

  type t = Transaction_with_witness.t Poly.t

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
                     (first_pass_txns, second_pass_txns, _old_root)
                     (txn_with_witness : Transaction_with_witness.t)
                   ->
                  let txn = txn_with_witness.transaction_with_status.data in
                  let target_first_pass_ledger =
                    txn_with_witness.statement.target.first_pass_ledger
                  in
                  match txn with
                  | Transaction.Coinbase _
                  | Fee_transfer _
                  | Command (User_command.Signed_command _) ->
                      ( txn_with_witness :: first_pass_txns
                      , second_pass_txns
                      , target_first_pass_ledger )
                  | Command (Zkapp_command _) ->
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

let extract_txn_and_global_slot (txn_with_witness : Transaction_with_witness.t)
    =
  let txn = txn_with_witness.transaction_with_status in
  let state_hash = fst txn_with_witness.state_hash in
  let global_slot = txn_with_witness.block_global_slot in
  (txn, state_hash, global_slot)

let latest_ledger_proof t =
  let%map.Option { data = proof; _ }, _ =
    Parallel_scan.last_emitted_value t.scan_state
  in
  proof

let latest_ledger_proof_and_txs' t =
  let open Option.Let_syntax in
  let%map proof, txns_with_witnesses =
    Parallel_scan.last_emitted_value t.scan_state
  in
  let ( previous_incomplete
      , `Border_block_continued_in_the_next_tree continued_in_next_tree ) =
    t.previous_incomplete_zkapp_updates
  in
  let txns =
    if continued_in_next_tree then
      Transactions_ordered.first_and_second_pass_transactions_per_tree
        txns_with_witnesses ~previous_incomplete
    else
      let txns =
        Transactions_ordered.first_and_second_pass_transactions_per_tree
          txns_with_witnesses ~previous_incomplete:[]
      in
      if List.is_empty previous_incomplete then txns
      else
        { Transactions_ordered.Poly.first_pass = []
        ; second_pass = []
        ; previous_incomplete
        ; current_incomplete = []
        }
        :: txns
  in
  (proof, txns)

let incomplete_txns_from_recent_proof_tree t =
  let open Option.Let_syntax in
  let%map proof, txns_per_block = latest_ledger_proof_and_txs' t in
  let txns =
    match List.last txns_per_block with
    | None ->
        ([], `Border_block_continued_in_the_next_tree false)
    | Some txns_in_last_block ->
        (*First pass ledger is considered as the snarked ledger, so any account update whether completed in the same tree or not should be included in the next tree *)
        if not (List.is_empty txns_in_last_block.second_pass) then
          ( txns_in_last_block.second_pass
          , `Border_block_continued_in_the_next_tree false )
        else
          ( txns_in_last_block.current_incomplete
          , `Border_block_continued_in_the_next_tree true )
  in
  (proof, txns)

let staged_transactions t =
  let ( previous_incomplete
      , `Border_block_continued_in_the_next_tree continued_in_next_tree ) =
    Option.value_map
      ~default:([], `Border_block_continued_in_the_next_tree false)
      (incomplete_txns_from_recent_proof_tree t)
      ~f:snd
  in
  let txns =
    if continued_in_next_tree then
      Transactions_ordered.first_and_second_pass_transactions_per_forest
        (Parallel_scan.pending_data t.scan_state)
        ~previous_incomplete
    else
      let txns =
        Transactions_ordered.first_and_second_pass_transactions_per_forest
          (Parallel_scan.pending_data t.scan_state)
          ~previous_incomplete:[]
      in
      if List.is_empty previous_incomplete then txns
      else
        [ { Transactions_ordered.Poly.first_pass = []
          ; second_pass = []
          ; previous_incomplete
          ; current_incomplete = []
          }
        ]
        :: txns
  in
  List.concat txns

(* written in continuation passing style so that implementation can be used both sync and async *)
let apply_ordered_txns_stepwise ?(stop_at_first_pass = false) ordered_txns
    ~ledger ~get_protocol_state ~apply_first_pass ~apply_second_pass
    ~apply_first_pass_sparse_ledger =
  let open Or_error.Let_syntax in
  let module Previous_incomplete_txns = struct
    type t =
      | Unapplied of Transaction_with_witness.t list
      | Partially_applied of
          (Transaction_status.t * Ledger.Transaction_partially_applied.t) list
  end in
  let apply ~apply ~ledger t state_hash block_global_slot =
    match get_protocol_state state_hash with
    | Ok state ->
        let txn_state_view =
          Mina_state.Protocol_state.body state
          |> Mina_state.Protocol_state.Body.view
        in
        apply ~global_slot:block_global_slot ~txn_state_view ledger t
    | Error e ->
        Or_error.errorf
          !"Coudln't find protocol state with hash %s: %s"
          (State_hash.to_base58_check state_hash)
          (Error.to_string_hum e)
  in
  let rec apply_txns_first_pass ?(acc = []) ~k txns =
    match txns with
    | [] ->
        k (`First_pass_ledger_hash (Ledger.merkle_root ledger)) (List.rev acc)
    | txn :: txns' ->
        let transaction, state_hash, block_global_slot =
          extract_txn_and_global_slot txn
        in
        let expected_status = transaction.status in
        let%map partially_applied_txn =
          apply ~apply:apply_first_pass ~ledger transaction.data state_hash
            block_global_slot
        in
        `Continue
          (fun () ->
            apply_txns_first_pass
              ~acc:((expected_status, partially_applied_txn) :: acc)
              ~k txns' )
  in
  let rec apply_txns_second_pass ~k partially_applied_txns =
    match partially_applied_txns with
    | [] ->
        k ()
    | (expected_status, partially_applied_txn) :: partially_applied_txns' ->
        let%bind res = apply_second_pass ledger partially_applied_txn in
        let status = Ledger.status_of_applied res in
        if Transaction_status.equal expected_status status then
          Ok
            (`Continue
              (fun () -> apply_txns_second_pass ~k partially_applied_txns') )
        else
          Or_error.errorf
            !"Transaction produced unxpected application status. Expected \
              status:%{sexp:Transaction_status.t} \
              Got:%{sexp:Transaction_status.t} Transaction:%{sexp: \
              Transaction.t}"
            expected_status status
            (Ledger.Transaction_partially_applied.command partially_applied_txn)
  in
  let apply_previous_incomplete_txns ~signature_kind ~k
      (txns : Previous_incomplete_txns.t) =
    (*Note: Previous incomplete transactions refer to the block's transactions from previous scan state tree that were split between the two trees.
      The set in the previous tree have gone through the first pass. For the second pass that is to happen after the rest of the set goes through the first pass, we need partially applied state - result of previous tree's transactions' first pass. To generate the partial state, we do a first pass application of previous tree's transaction on a sparse ledger created from witnesses stored in the scan state and then use it to apply to the ledger here*)
    let inject_ledger_info partially_applied_txn =
      let open Sparse_ledger.T.Transaction_partially_applied in
      match partially_applied_txn with
      | Zkapp_command t ->
          let%map original_first_pass_account_states =
            Mina_stdlib.Result.List.map t.original_first_pass_account_states
              ~f:(fun (id, loc_opt) ->
                match loc_opt with
                | None ->
                    return (id, None)
                | Some (_sparse_ledger_loc, account) -> (
                    match Ledger.location_of_account ledger id with
                    | Some loc ->
                        return (id, Some (loc, account))
                    | None ->
                        Or_error.errorf
                          "Original accounts states from partially applied \
                           transactions don't exist in the ledger" ) )
          in
          let global_state : Ledger.Global_state.t =
            { first_pass_ledger = ledger
            ; second_pass_ledger = ledger
            ; fee_excess = t.global_state.fee_excess
            ; supply_increase = t.global_state.supply_increase
            ; protocol_state = t.global_state.protocol_state
            ; block_global_slot = t.global_state.block_global_slot
            }
          in
          let local_state =
            { Mina_transaction_logic.Zkapp_command_logic.Local_state.stack_frame =
                t.local_state.stack_frame
            ; call_stack = t.local_state.call_stack
            ; transaction_commitment = t.local_state.transaction_commitment
            ; full_transaction_commitment =
                t.local_state.full_transaction_commitment
            ; excess = t.local_state.excess
            ; supply_increase = t.local_state.supply_increase
            ; ledger
            ; success = t.local_state.success
            ; account_update_index = t.local_state.account_update_index
            ; failure_status_tbl = t.local_state.failure_status_tbl
            ; will_succeed = t.local_state.will_succeed
            }
          in
          Ledger.Transaction_partially_applied.Zkapp_command
            { command = t.command
            ; previous_hash = t.previous_hash
            ; original_first_pass_account_states
            ; signature_kind
            ; constraint_constants = t.constraint_constants
            ; state_view = t.state_view
            ; global_state
            ; local_state
            }
      | Signed_command c ->
          return
            (Ledger.Transaction_partially_applied.Signed_command
               { previous_hash = c.previous_hash; applied = c.applied } )
      | Fee_transfer f ->
          return
            (Ledger.Transaction_partially_applied.Fee_transfer
               { previous_hash = f.previous_hash; applied = f.applied } )
      | Coinbase c ->
          return
            (Ledger.Transaction_partially_applied.Coinbase
               { previous_hash = c.previous_hash; applied = c.applied } )
    in
    let rec apply_txns_to_witnesses_first_pass ?(acc = []) ~k txns =
      match txns with
      | [] ->
          k (List.rev acc)
      | txn :: txns' ->
          let transaction, state_hash, block_global_slot =
            extract_txn_and_global_slot txn
          in
          let expected_status = transaction.status in
          let%bind partially_applied_txn =
            apply ~apply:apply_first_pass_sparse_ledger
              ~ledger:txn.first_pass_ledger_witness transaction.data state_hash
              block_global_slot
          in
          let%map partially_applied_txn' =
            inject_ledger_info partially_applied_txn
          in
          `Continue
            (fun () ->
              apply_txns_to_witnesses_first_pass
                ~acc:((expected_status, partially_applied_txn') :: acc)
                ~k txns' )
    in
    match txns with
    | Unapplied txns ->
        apply_txns_to_witnesses_first_pass txns
          ~k:(fun partially_applied_txns ->
            apply_txns_second_pass partially_applied_txns ~k )
    | Partially_applied partially_applied_txns ->
        apply_txns_second_pass partially_applied_txns ~k
  in
  let rec apply_txns (previous_incomplete : Previous_incomplete_txns.t)
      (ordered_txns : _ Transactions_ordered.Poly.t list)
      ~first_pass_ledger_hash ~signature_kind =
    let previous_incomplete =
      (*filter out any non-zkapp transactions for second pass application*)
      match previous_incomplete with
      | Previous_incomplete_txns.Unapplied txns ->
          Previous_incomplete_txns.Unapplied
            (List.filter txns ~f:(fun txn ->
                 match txn.transaction_with_status.data with
                 | Command (Zkapp_command _) ->
                     true
                 | _ ->
                     false ) )
      | Partially_applied txns ->
          Partially_applied
            (List.filter txns ~f:(fun (_, t) ->
                 match t with Zkapp_command _ -> true | _ -> false ) )
    in
    match ordered_txns with
    | [] ->
        apply_previous_incomplete_txns ~signature_kind
          ~k:(fun () -> Ok (`Complete first_pass_ledger_hash))
          previous_incomplete
    | [ txns_per_block ] when stop_at_first_pass ->
        (*Last block; don't apply second pass. This is for snarked ledgers which are first pass ledgers*)
        apply_txns_first_pass txns_per_block.first_pass
          ~k:(fun first_pass_ledger_hash _partially_applied_txns ->
            (*Skip previous_incomplete: If there are previous_incomplete txns
              then there’d be at least two sets of txns_per_block and the
              previous_incomplete txns will be applied when processing the first
              set. The subsequent sets shouldn’t have any previous-incomplete.*)
            apply_txns (Unapplied []) [] ~first_pass_ledger_hash ~signature_kind )
    | txns_per_block :: ordered_txns' ->
        (*Apply first pass of a blocks transactions either new or continued from previous tree*)
        apply_txns_first_pass txns_per_block.first_pass
          ~k:(fun first_pass_ledger_hash partially_applied_txns ->
            (*Apply second pass of previous tree's transactions, if any*)
            apply_previous_incomplete_txns previous_incomplete ~signature_kind
              ~k:(fun () ->
                let continue_previous_tree's_txns =
                  (* If this is a continuation from previous tree for the same block (incomplete txns in both sets) then do second pass now*)
                  let previous_not_empty =
                    match previous_incomplete with
                    | Unapplied txns ->
                        not (List.is_empty txns)
                    | Partially_applied txns ->
                        not (List.is_empty txns)
                  in
                  previous_not_empty
                  && not (List.is_empty txns_per_block.current_incomplete)
                in
                let do_second_pass =
                  (*if transactions completed in the same tree; do second pass now*)
                  (not (List.is_empty txns_per_block.second_pass))
                  || continue_previous_tree's_txns
                in
                if do_second_pass then
                  apply_txns_second_pass partially_applied_txns ~k:(fun () ->
                      apply_txns (Unapplied []) ordered_txns'
                        ~first_pass_ledger_hash ~signature_kind )
                else
                  (*Transactions not completed in this tree, so second pass after first pass of remaining transactions for the same block in the next tree*)
                  apply_txns (Partially_applied partially_applied_txns)
                    ordered_txns' ~first_pass_ledger_hash ~signature_kind ) )
  in
  let previous_incomplete =
    Option.value_map (List.hd ordered_txns)
      ~default:(Previous_incomplete_txns.Unapplied [])
      ~f:(fun (first_block : Transactions_ordered.t) ->
        Unapplied first_block.previous_incomplete )
  in
  (*Assuming this function is called on snarked ledger and snarked ledger is the
    first pass ledger*)
  let first_pass_ledger_hash =
    `First_pass_ledger_hash (Ledger.merkle_root ledger)
  in
  apply_txns previous_incomplete ordered_txns ~first_pass_ledger_hash

let apply_ordered_txns_sync ?stop_at_first_pass ordered_txns ~ledger
    ~get_protocol_state ~apply_first_pass ~apply_second_pass
    ~apply_first_pass_sparse_ledger ~signature_kind =
  let rec run = function
    | Ok (`Continue k) ->
        run (k ())
    | Ok (`Complete x) ->
        Ok x
    | Error err ->
        Error err
  in
  run
  @@ apply_ordered_txns_stepwise ?stop_at_first_pass ordered_txns ~ledger
       ~get_protocol_state ~apply_first_pass ~apply_second_pass
       ~apply_first_pass_sparse_ledger ~signature_kind

let apply_ordered_txns_async ?stop_at_first_pass ordered_txns
    ?(async_batch_size = 10) ~ledger ~get_protocol_state ~apply_first_pass
    ~apply_second_pass ~apply_first_pass_sparse_ledger ~signature_kind =
  let open Deferred.Result.Let_syntax in
  let yield =
    let f = Staged.unstage (Scheduler.yield_every ~n:async_batch_size) in
    fun () -> f () |> Deferred.map ~f:Result.return
  in
  let rec run result =
    let%bind () = yield () in
    match result with
    | Ok (`Continue k) ->
        run (k ())
    | Ok (`Complete x) ->
        return x
    | Error err ->
        Deferred.return (Error err)
  in
  run
  @@ apply_ordered_txns_stepwise ?stop_at_first_pass ordered_txns ~ledger
       ~get_protocol_state ~apply_first_pass ~apply_second_pass
       ~apply_first_pass_sparse_ledger ~signature_kind

let get_snarked_ledger_sync ~ledger ~get_protocol_state ~apply_first_pass
    ~apply_second_pass ~apply_first_pass_sparse_ledger ~signature_kind t =
  match latest_ledger_proof_and_txs' t with
  | None ->
      Or_error.errorf "No transactions found"
  | Some (_, txns_per_block) ->
      apply_ordered_txns_sync ~stop_at_first_pass:true txns_per_block ~ledger
        ~get_protocol_state ~apply_first_pass ~apply_second_pass
        ~apply_first_pass_sparse_ledger ~signature_kind
      |> Or_error.ignore_m

let get_snarked_ledger_async ?async_batch_size ~ledger ~get_protocol_state
    ~apply_first_pass ~apply_second_pass ~apply_first_pass_sparse_ledger
    ~signature_kind t =
  match latest_ledger_proof_and_txs' t with
  | None ->
      Deferred.Or_error.errorf "No transactions found"
  | Some (_, txns_per_block) ->
      apply_ordered_txns_async ~stop_at_first_pass:true txns_per_block
        ?async_batch_size ~ledger ~get_protocol_state ~apply_first_pass
        ~apply_second_pass ~apply_first_pass_sparse_ledger ~signature_kind
      |> Deferred.Or_error.ignore_m

let get_staged_ledger_async ?async_batch_size ~ledger ~get_protocol_state
    ~apply_first_pass ~apply_second_pass ~apply_first_pass_sparse_ledger
    ~signature_kind t =
  let staged_transactions_with_state_hash = staged_transactions t in
  apply_ordered_txns_async staged_transactions_with_state_hash ?async_batch_size
    ~ledger ~get_protocol_state ~apply_first_pass ~apply_second_pass
    ~apply_first_pass_sparse_ledger ~signature_kind

let free_space t = Parallel_scan.free_space t.scan_state

(*This needs to be grouped like in work_to_do function. Group of two jobs per list and not group of two jobs after concatenating the lists*)
let all_jobs t = Parallel_scan.all_jobs t.scan_state

let next_on_new_tree t = Parallel_scan.next_on_new_tree t.scan_state

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

let snark_job_list_json t =
  let all_jobs : Job_view.t list list =
    let fa (a : Ledger_proof_with_hash.t) =
      Ledger_proof.Cached.statement a.data
    in
    let fd (d : Transaction_with_witness.t) = d.statement in
    Parallel_scan.job_views t.scan_state ~f_merge:fa ~f_base:fd
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

let single_spec_of_job ~get_state :
    job -> Snark_work_lib.Spec.Single.t Or_error.t = function
  | Parallel_scan.Available_job.Base
      { transaction_with_status
      ; statement
      ; state_hash
      ; first_pass_ledger_witness
      ; second_pass_ledger_witness
      ; init_stack
      ; block_global_slot
      ; _
      } ->
      let%map.Or_error witness =
        let { With_status.data = transaction; status } =
          transaction_with_status
        in
        let%map.Or_error protocol_state_body =
          get_state (fst state_hash)
          |> Or_error.map ~f:Mina_state.Protocol_state.body
        in
        { Transaction_witness.first_pass_ledger = first_pass_ledger_witness
        ; second_pass_ledger = second_pass_ledger_witness
        ; transaction
        ; protocol_state_body
        ; init_stack
        ; status
        ; block_global_slot
        }
      in
      Snark_work_lib.Work.Single.Spec.Transition (statement, witness)
  | Merge ({ data = p1; _ }, { data = p2; _ }) ->
      let%map.Or_error merged =
        Transaction_snark.Statement.merge
          (Ledger_proof.Cached.statement p1)
          (Ledger_proof.Cached.statement p2)
      in
      Snark_work_lib.Work.Single.Spec.Merge (merged, p1, p2)

let single_spec_one_or_twos_rev_of_job_list ~get_state jobs =
  List.fold_result ~init:[] (One_or_two.group_list jobs) ~f:(fun acc' pair ->
      let%map.Or_error spec =
        One_or_two.Or_error.map ~f:(single_spec_of_job ~get_state) pair
      in
      spec :: acc' )

let all_work_pairs t
    ~(get_state : State_hash.t -> Mina_state.Protocol_state.value Or_error.t) :
    Snark_work_lib.Spec.Single.t One_or_two.t list Or_error.t =
  let all_jobs = all_jobs t in
  List.fold_until all_jobs ~init:[]
    ~finish:(fun lst -> Ok lst)
    ~f:(fun acc jobs ->
      let specs_list =
        single_spec_one_or_twos_rev_of_job_list ~get_state jobs
      in
      match specs_list with
      | Ok list ->
          Continue (acc @ List.rev list)
      | Error e ->
          Stop (Error e) )

(* The scan state reports numbers; turning them into gauges is this side's
   business, which is why it no longer needs to know that Prometheus exists. *)
let update_metrics t =
  Or_error.try_with (fun () ->
      List.iteri (Parallel_scan.metrics t.scan_state)
        ~f:(fun
             i
             { Parallel_scan.Tree_metrics.available_space
             ; base_jobs_todo
             ; merge_jobs_todo
             }
           ->
          let name = sprintf "tree%d" i in
          Mina_metrics.(
            Gauge.set (Scan_state_metrics.scan_state_available_space ~name))
            (Float.of_int available_space) ;
          Mina_metrics.(
            Gauge.set (Scan_state_metrics.scan_state_base_snarks ~name))
            (Float.of_int base_jobs_todo) ;
          Mina_metrics.(
            Gauge.set (Scan_state_metrics.scan_state_merge_snarks ~name))
            (Float.of_int merge_jobs_todo) ) )

let fill_work_and_enqueue_transactions t ~logger transactions work =
  let open Or_error.Let_syntax in
  let deconstruct_work (w : Transaction_snark_work.t) :
      Ledger_proof_with_hash.t list =
    One_or_two.map ~f:Ledger_proof_with_hash.create
      (Transaction_snark_work.proofs w)
    |> One_or_two.to_list
  in
  (*get incomplete transactions from previous proof which will be completed in
     the new proof, if there's one*)
  let old_proof_and_incomplete_zkapp_updates =
    incomplete_txns_from_recent_proof_tree t
  in
  let work_list = List.concat_map ~f:deconstruct_work work in
  let%bind proof_opt, updated_scan_state =
    Parallel_scan.update t.scan_state ~payload_digest ~completed_jobs:work_list
      ~data:transactions
  in
  [%log internal] "@metadata"
    ~metadata:
      [ ("scan_state_added_works", `Int (List.length work))
      ; ("total_proofs", `Int (total_proofs work))
      ; ("merge_jobs_created", `Int (List.length work_list))
      ; ("emitted_proof", `Bool (Option.is_some proof_opt))
      ] ;
  let%map result_opt, scan_state' =
    Option.value_map
      ~default:
        (Ok
           ( None
           , { scan_state = updated_scan_state
             ; previous_incomplete_zkapp_updates =
                 t.previous_incomplete_zkapp_updates
             } ) )
      proof_opt
      ~f:(fun ({ data = proof; _ }, _txns_with_witnesses) ->
        let curr_stmt = Ledger_proof.Cached.statement proof in
        let prev_stmt, incomplete_zkapp_updates_from_old_proof =
          Option.value_map
            ~default:
              (curr_stmt, ([], `Border_block_continued_in_the_next_tree false))
            old_proof_and_incomplete_zkapp_updates
            ~f:(fun ({ data = p'; _ }, incomplete_zkapp_updates_from_old_proof) ->
              ( Ledger_proof.Cached.statement p'
              , incomplete_zkapp_updates_from_old_proof ) )
        in
        (*prev_target is connected to curr_source- Order of the arguments is
          important here*)
        let stmts_connect =
          if Transaction_snark.Statement.equal prev_stmt curr_stmt then Ok ()
          else
            Transaction_snark.Statement.merge prev_stmt curr_stmt
            |> Or_error.ignore_m
        in
        match stmts_connect with
        | Ok () ->
            let scan_state' =
              { scan_state = updated_scan_state
              ; previous_incomplete_zkapp_updates =
                  incomplete_zkapp_updates_from_old_proof
              }
            in
            (*This block is for when there's a proof emitted so Option.
              value_exn is safe here
              [latest_ledger_proof] generates ordered transactions
              appropriately*)
            Ok (latest_ledger_proof scan_state', scan_state')
        | Error e ->
            Or_error.errorf
              "The new final statement does not connect to the previous \
               proof's statement: %s"
              (Error.to_string_hum e) )
  in
  (result_opt, scan_state')

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

(** Serving and receiving a scan state piece by piece.

    {!Parallel_scan_sync} holds the protocol; this is where it meets the real
    payload types. Two facts make the join simple, and neither is a
    coincidence:

    - A payload's digest is [SHA256] of its [bin_prot] encoding — that is what
      [Transaction_with_witness.hash] and [Ledger_proof_with_hash.hash] already
      compute, because the scan state wanted a cheap hash long before it wanted
      a Merkle tree. So a received payload is checked against the digest that
      names it {e without being parsed}: bad bytes are rejected before they
      reach a decoder.
    - The digests the tree holds are [Aux_hash.t], which is a raw string, so
      the protocol's digests and the scan state's are the same thing. *)
module Sync = struct
  (* [Responder.t] below shadows the scan state's own [t]; name it first. *)
  type nonrec scan_state = t

  module Address = Parallel_scan_sync.Address
  module Cursors = Parallel_scan_sync.Cursors
  module Band = Parallel_scan_sync.Band

  (* A payload digest, which is what the tree holds and what names a payload
     on the wire — a raw string, not the block's [Staged_ledger_hash.Aux_hash.t]
     even though both are SHA256. *)
  let digest_of_bytes bytes : string =
    Digestif.SHA256.(feed_string (init ()) bytes |> get) |> Aux_hash.of_sha256

  (** What a syncing node fetches first.

      It covers the scan state {e and} the incomplete zkApp updates beside it,
      because the block commits to both together: {!verify} reassembles
      [hash_generic] from the manifest alone and compares against the
      [Aux_hash.t] in the block. Nothing else is trusted until that passes. *)
  module Manifest = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { scan_state : Parallel_scan_sync.Manifest.Stable.V1.t
          ; previous_incomplete :
              Mina_stdlib.Bounded_types.String.Stable.V1.t
              Mina_stdlib.Bounded_types.ArrayN4000.Stable.V1.t
          ; border_block_continued_in_the_next_tree : bool
          ; ledger_hash : Ledger_hash.Stable.V1.t
          ; pending_coinbase : Pending_coinbase.Stable.V2.t
          }
        [@@deriving sexp]

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t =
      { scan_state : Parallel_scan_sync.Manifest.t
      ; previous_incomplete : string array
      ; border_block_continued_in_the_next_tree : bool
      ; ledger_hash : Ledger_hash.t
      ; pending_coinbase : Pending_coinbase.t
      }
    [@@deriving sexp]

    (* Mirrors [hash_generic]; if that changes, this has to change with it, and
       the round-trip test below is what says so. *)
    let aux_hash t =
      let scan_state_hash = Parallel_scan_sync.Manifest.root t.scan_state in
      let incomplete_updates =
        Array.fold ~init:(Digestif.SHA256.init ()) t.previous_incomplete
          ~f:(fun h digest -> Digestif.SHA256.feed_string h digest)
        |> Digestif.SHA256.get
      in
      let continued =
        Digestif.SHA256.digest_string
          (Bool.to_string t.border_block_continued_in_the_next_tree)
      in
      [ scan_state_hash; incomplete_updates; continued ]
      |> List.fold ~init:(Digestif.SHA256.init ()) ~f:(fun h d ->
             Digestif.SHA256.feed_string h (Digestif.SHA256.to_raw_string d) )
      |> Digestif.SHA256.get |> Staged_ledger_hash.Aux_hash.of_sha256

    let ledger_hash t = t.ledger_hash

    let pending_coinbase t = t.pending_coinbase

    (** The block commits to the aux hash, the ledger hash and the pending
        coinbase together, as one staged ledger hash — so that is what a
        manifest is checked against. Verifying only the aux hash would leave
        the other two for a peer to lie about. *)
    let staged_ledger_hash t =
      Staged_ledger_hash.of_aux_ledger_and_coinbase_hash (aux_hash t)
        t.ledger_hash t.pending_coinbase

    let verify t ~expected =
      if Staged_ledger_hash.equal (staged_ledger_hash t) expected then Ok ()
      else
        Or_error.error_string
          "scan state manifest does not match the staged ledger hash in the \
           block"
  end

  (** What one peer asks another for.

      A band is addressed by the digest of the tree it belongs to rather than
      by that tree's position, and payloads by their own digests, so a peer can
      answer from whatever it happens to hold — its forest need not be at the
      same height as the asker's. Only the manifest is tied to a particular
      block. *)
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          | Manifest of State_hash.Stable.V1.t
          | Band of
              { scan_state : State_hash.Stable.V1.t
              ; tree : Mina_stdlib.Bounded_types.String.Stable.V1.t
              ; root : Address.Stable.V1.t
              ; height : int
              }
          | Payloads of
              { scan_state : State_hash.Stable.V1.t
              ; digests :
                  Mina_stdlib.Bounded_types.String.Stable.V1.t
                  Mina_stdlib.Bounded_types.ArrayN64.Stable.V1.t
              }
          | Protocol_states of State_hash.Stable.V1.t
        [@@deriving sexp]

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t =
      | Manifest of State_hash.t
      | Band of
          { scan_state : State_hash.t
          ; tree : string
          ; root : Address.t
          ; height : int
          }
      | Payloads of { scan_state : State_hash.t; digests : string array }
      | Protocol_states of State_hash.t
          (** the states the scan state at this hash needs; the responder works
              out which those are, since it has the assembled scan state and the
              asker does not yet *)
    [@@deriving sexp]

    (** Every query names the scan state it is about, so any peer holding that
        root can answer it. Without this a band could only be served by a peer
        that had already described the forest it belongs to, which pins a whole
        sync to one peer. *)
    let scan_state : t -> State_hash.t = function
      | Manifest hash | Protocol_states hash ->
          hash
      | Band { scan_state; _ } | Payloads { scan_state; _ } ->
          scan_state

    (** How many payloads one query may ask for. A responder does the work of
        serialising each, so this is the lever on how much a single message can
        cost it. *)
    let max_payloads_per_query = 64
  end

  module Answer = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          | Manifest of Manifest.Stable.V1.t
          | Band of Band.Stable.V1.t
          | Payloads of
              ( Mina_stdlib.Bounded_types.String.Stable.V1.t
              * Mina_stdlib.Bounded_types.String.Stable.V1.t )
              Mina_stdlib.Bounded_types.ArrayN64.Stable.V1.t
              (** digest and its bytes; a payload the responder does not hold
                  is simply absent, and the asker tries elsewhere *)
          | Protocol_states of
              Mina_state.Protocol_state.Value.Stable.V3.t
              Mina_stdlib.Bounded_types.ArrayN4000.Stable.V1.t
        [@@deriving sexp]

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t =
      | Manifest of Manifest.t
      | Band of Band.t
      | Payloads of (string * string) array
      | Protocol_states of Mina_state.Protocol_state.value array
    [@@deriving sexp]
  end

  (** A peer's side. Built once per scan state and answers any number of
      requests against it: the skeleton so bands can be cut without rebuilding
      it each time, and an index so a payload can be found by digest rather
      than by position — which is what lets a peer serve a payload it holds
      even when its own forest has moved on. *)
  module Responder = struct
    type payload =
      | Merge of Ledger_proof_with_hash.t
      | Base of Transaction_with_witness.t

    type nonrec t =
      { skeleton : (string, string) Parallel_scan.t
      ; trees_by_digest :
          (string, (string, string) Parallel_scan.Tree.t) Hashtbl.t
      ; manifest : Manifest.t
      ; payloads : (string, payload) Hashtbl.t
      }

    let create (t : scan_state) ~ledger_hash ~pending_coinbase =
      let payloads = Hashtbl.create (module String) in
      let note key data = Hashtbl.set payloads ~key ~data in
      Parallel_scan.fold_chronological t.scan_state ~init:()
        ~f_merge:(fun () node ->
          match node with
          | Parallel_scan.Merge_node.Empty ->
              ()
          | Part x ->
              note x.hash (Merge x)
          | Full { left; right } ->
              note left.hash (Merge left) ;
              note right.hash (Merge right) )
        ~f_base:(fun () node ->
          match node with
          | Parallel_scan.Base_node.Empty ->
              ()
          | Full { job; _ } ->
              note job.hash (Base job) ) ;
      Option.iter (Parallel_scan.last_emitted_value t.scan_state)
        ~f:(fun (proof, data) ->
          note proof.hash (Merge proof) ;
          List.iter data ~f:(fun d -> note d.hash (Base d)) ) ;
      let previous_incomplete, `Border_block_continued_in_the_next_tree border =
        t.previous_incomplete_zkapp_updates
      in
      List.iter previous_incomplete ~f:(fun d -> note d.hash (Base d)) ;
      let skeleton = Parallel_scan.skeleton t.scan_state ~payload_digest in
      let trees_by_digest = Hashtbl.create (module String) in
      List.iter (Parallel_scan.trees skeleton) ~f:(fun tree ->
          Hashtbl.set trees_by_digest
            ~key:
              (Digestif.SHA256.to_raw_string (Parallel_scan.Tree.digest tree))
            ~data:tree ) ;
      { skeleton
      ; trees_by_digest
      ; manifest =
          { Manifest.scan_state =
              Parallel_scan_sync.Manifest.of_state t.scan_state ~payload_digest
          ; previous_incomplete =
              Array.of_list_map previous_incomplete ~f:(fun d -> d.hash)
          ; border_block_continued_in_the_next_tree = border
          ; ledger_hash
          ; pending_coinbase
          }
      ; payloads
      }

    let manifest t = t.manifest

    let band t ~tree ~root ~height =
      Option.map (Hashtbl.find t.trees_by_digest tree) ~f:(fun tree ->
          Band.of_tree tree ~root ~height )

    (** The bytes a peer sends for one payload: its [bin_prot] encoding, which
        is what its digest is taken over. Serialised per request rather than up
        front, so the index costs pointers rather than megabytes. *)
    let payload_bytes t ~digest =
      Option.map (Hashtbl.find t.payloads digest) ~f:(function
        | Merge { With_hash.data = proof; _ } ->
            Binable.to_string
              (module Ledger_proof.Stable.Latest)
              (Ledger_proof.Cached.read_proof_from_disk proof)
        | Base witness ->
            Binable.to_string
              (module Transaction_with_witness.Stable.Latest)
              (Transaction_with_witness.read_all_proofs_from_disk witness) )

    (** Answer one query. All the protocol knowledge lives here rather than in
        the RPC handler, which only moves bytes. *)
    let respond t (query : Query.t) =
      match query with
      | Query.Manifest _ ->
          Some (Answer.Manifest (manifest t))
      | Query.Band { tree; root; height; _ } ->
          Option.map (band t ~tree ~root ~height) ~f:(fun band ->
              Answer.Band band )
      | Query.Protocol_states _ ->
          (* answered by the sync handler, which can reach the frontier; a
             responder only knows its scan state *)
          None
      | Query.Payloads { digests; _ } ->
          Some
            (Answer.Payloads
               ( Array.sub digests ~pos:0
                   ~len:
                     (Int.min (Array.length digests)
                        Query.max_payloads_per_query )
               |> Array.filter_map ~f:(fun digest ->
                      Option.map (payload_bytes t ~digest) ~f:(fun bytes ->
                          (digest, bytes) ) ) ) )
  end

  module Request = Parallel_scan_sync.Request

  (** Where a scan state sync has got to, for [mina client status].

      A sync runs inside the bootstrap controller, which has no transition
      frontier to hang progress off the way catchup does, so the controller
      publishes here and the daemon's status reads it. [None] means no sync is
      running. *)
  module Progress = struct
    type t =
      { bands_outstanding : int; payloads_received : int; payloads_known : int }

    let current : t option ref = ref None

    let report t = current := t

    let get () = !current

    (** As [(label, count)] pairs, which is how the daemon status already
        renders the equivalent for catchup. *)
    let to_entries t =
      [ ("Bands outstanding", t.bands_outstanding)
      ; ("Payloads received", t.payloads_received)
      ; ("Payloads known", t.payloads_known)
      ]
  end

  (** A syncing node's side.

      Reception accumulates outside any scan state: the real type has
      invariants a half-received one violates, so nothing is built until
      everything has arrived and been checked.

      The [previous_incomplete_zkapp_updates] are tracked here rather than by
      {!Parallel_scan_sync.Builder}, because they sit beside the scan state
      rather than in it — no node names them, only the manifest does. *)
  module Builder = struct
    type t =
      { inner : Parallel_scan_sync.Builder.t
      ; manifest : Manifest.t
      ; incomplete : (string, string option) Hashtbl.t
            (** digest -> bytes for the incomplete updates, [None] until it
                arrives *)
      ; state_hash : State_hash.t
            (** carried into every query, so any peer holding this root can
                answer it *)
      }

    (** Check the manifest against the staged ledger hash in the block, then
        open a builder on it. [band_height] is how much of a tree to ask a peer
        for at a time. *)
    let create manifest ~state_hash ~expected ~band_height =
      let open Or_error.Let_syntax in
      (* This is the only place the chain is consulted; everything after it is
         checked against something this established. *)
      let%map () = Manifest.verify manifest ~expected in
      let incomplete = Hashtbl.create (module String) in
      Array.iter manifest.previous_incomplete ~f:(fun digest ->
          if not (Hashtbl.mem incomplete digest) then
            Hashtbl.set incomplete ~key:digest ~data:None ) ;
      let inner =
        Parallel_scan_sync.Builder.create manifest.scan_state
          ~expected:(Parallel_scan_sync.Manifest.root manifest.scan_state)
          ~band_height
        |> Or_error.ok_exn
        (* cannot fail: the digest is recomputed from this same manifest, and
           [Manifest.verify] above is what ties it to the block *)
      in
      { inner; manifest; incomplete; state_hash }

    let wanted t =
      Parallel_scan_sync.Builder.wanted t.inner
      @ ( Hashtbl.to_alist t.incomplete
        |> List.filter_map ~f:(fun (digest, bytes) ->
               Option.some_if (Option.is_none bytes) (Request.Payload digest) )
        )

    let add_band t ~tree band =
      Parallel_scan_sync.Builder.add_band t.inner ~tree band

    (** Take a payload. Its digest is recomputed from the bytes, so bad bytes
        are rejected here — before anything tries to decode them. *)
    let add_payload t ~bytes =
      let digest = digest_of_bytes bytes in
      if Hashtbl.mem t.incomplete digest then
        Ok (Hashtbl.set t.incomplete ~key:digest ~data:(Some bytes))
      else
        Parallel_scan_sync.Builder.add_payload t.inner ~digest_of_bytes ~bytes

    (** What to ask peers for next, in the form that goes on the wire.

        A band request names its tree by digest rather than by position, so the
        index the builder thinks in is resolved here; payload requests are
        batched up to what one query may carry. *)
    let queries t =
      let bands, payloads =
        List.partition_map (wanted t) ~f:(function
          | Request.Band { tree; root; height } ->
              First
                (Query.Band
                   { scan_state = t.state_hash
                   ; tree = fst (List.nth_exn t.manifest.scan_state.trees tree)
                   ; root
                   ; height
                   } )
          | Request.Payload digest ->
              Second digest )
      in
      bands
      @ List.map (List.chunks_of payloads ~length:Query.max_payloads_per_query)
          ~f:(fun batch ->
            Query.Payloads
              { scan_state = t.state_hash; digests = Array.of_list batch } )

    (** Take an answer, paired with the query that asked for it. The pairing is
        what tells us which tree a band belongs to — an answer does not say so
        itself, and the downloader hands both back together anyway. *)
    let add_answer t ~(query : Query.t) (answer : Answer.t) =
      let open Or_error.Let_syntax in
      match (query, answer) with
      | Query.Band { tree; _ }, Answer.Band band ->
          let%bind index =
            match
              List.findi t.manifest.scan_state.trees ~f:(fun _ (digest, _) ->
                  String.equal digest tree )
            with
            | Some (index, _) ->
                Ok index
            | None ->
                Or_error.error_string "band for a tree not in the manifest"
          in
          add_band t ~tree:index band
      | Query.Payloads _, Answer.Payloads payloads ->
          Array.map payloads ~f:(fun (_digest, bytes) -> add_payload t ~bytes)
          |> Array.to_list |> Or_error.all_unit
      | Query.Manifest _, Answer.Manifest _ ->
          (* the builder was created from a manifest; it never asks for one *)
          Ok ()
      | _ ->
          Or_error.error_string "answer does not match the query"

    let outstanding t =
      let `Bands bands, `Payloads payloads =
        Parallel_scan_sync.Builder.outstanding t.inner
      in
      ( `Bands bands
      , `Payloads (payloads + Hashtbl.count t.incomplete ~f:Option.is_none) )

    (** A snapshot for the daemon status. The known count grows as bands reveal
        what is underneath them, so early in a sync it understates the work
        left. *)
    let progress t =
      let `Bands bands, `Payloads _ = outstanding t in
      let `Received received, `Known known =
        Parallel_scan_sync.Builder.payload_progress t.inner
      in
      { Progress.bands_outstanding = bands
      ; payloads_received =
          received + Hashtbl.count t.incomplete ~f:Option.is_some
      ; payloads_known = known + Hashtbl.length t.incomplete
      }

    (** Assemble the serialised scan state, ready for
        {!write_all_proofs_to_disk}. Fails while anything is outstanding. *)
    let finish t =
      let open Or_error.Let_syntax in
      let merge_of_bytes =
        Binable.of_string (module Ledger_proof.Stable.Latest)
      in
      let base_of_bytes =
        Binable.of_string (module Transaction_with_witness.Stable.Latest)
      in
      let%bind incomplete =
        List.map (Array.to_list t.manifest.previous_incomplete)
          ~f:(fun digest ->
            match Hashtbl.find t.incomplete digest with
            | Some (Some bytes) ->
                Ok (base_of_bytes bytes)
            | _ ->
                Or_error.error_string "an incomplete zkApp update never arrived" )
        |> Or_error.all
      in
      let%map scan_state =
        Parallel_scan_sync.Builder.finish t.inner ~merge_of_bytes ~base_of_bytes
      in
      { Stored.scan_state = Parallel_scan.to_wire scan_state
      ; previous_incomplete_zkapp_updates =
          ( incomplete
          , `Border_block_continued_in_the_next_tree
              t.manifest.border_block_continued_in_the_next_tree )
      }
  end
end

let write_all_proofs_to_disk ~signature_kind ~proof_cache_db
    { Stored.scan_state = uncached
    ; previous_incomplete_zkapp_updates = tx_list, border_status
    } =
  let f1 proof =
    { With_hash.data =
        Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db proof
    ; hash = Ledger_proof_with_hash.hash proof
    }
  in
  (* This is where the serialised form becomes the live one, and so where the
     digest cache the wire format leaves out is rebuilt. Both maps preserve
     payload digests — the cached and uncached representations carry the same
     [hash] — so the digests survive the change of representation. *)
  { scan_state =
      Parallel_scan.of_wire uncached ~payload_digest:stable_payload_digest
      |> Parallel_scan.map ~f_merge:f1
           ~f_base:
             (Transaction_with_witness.write_all_proofs_to_disk ~signature_kind
                ~proof_cache_db )
  ; previous_incomplete_zkapp_updates =
      ( List.map
          ~f:
            (Transaction_with_witness.write_all_proofs_to_disk ~signature_kind
               ~proof_cache_db )
          tx_list
      , border_status )
  }

let read_all_proofs_from_disk
    { scan_state = cached
    ; previous_incomplete_zkapp_updates = tx_list, border_status
    } =
  let f1 { With_hash.data = proof; hash = _ } =
    Ledger_proof.Cached.read_proof_from_disk proof
  in
  let scan_state =
    Parallel_scan.map ~f_merge:f1
      ~f_base:Transaction_with_witness.read_all_proofs_from_disk cached
    |> Parallel_scan.to_wire
  in
  Stored.
    { scan_state
    ; previous_incomplete_zkapp_updates =
        ( List.map ~f:Transaction_with_witness.read_all_proofs_from_disk tx_list
        , border_status )
    }
