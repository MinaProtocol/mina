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
  module T = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      (* TODO In Mesa use Transaction_snark.Statement.t * Transaction_witness.t *)
      module V3 = struct
        type t =
          { transaction_with_status :
              Transaction.Stable.V2.t With_status.Stable.V2.t
          ; state_hash : State_hash.Stable.V1.t * State_body_hash.Stable.V1.t
          ; statement : Transaction_snark.Statement.Stable.V2.t
          ; init_stack : Mina_base.Pending_coinbase.Stack_versioned.Stable.V1.t
          ; first_pass_ledger_witness :
              (Mina_ledger.Sparse_ledger.Stable.V2.t[@sexp.opaque])
          ; second_pass_ledger_witness :
              (Mina_ledger.Sparse_ledger.Stable.V2.t[@sexp.opaque])
          ; block_global_slot :
              Mina_numbers.Global_slot_since_genesis.Stable.V1.t
                (* TODO: in Mesa remove the option, just have the value *)
          ; previous_protocol_state_body_opt :
              Mina_state.Protocol_state.Body.Value.Stable.V2.t option
          }
        [@@deriving sexp, to_yojson]

        let transaction_type t =
          Transaction_type.of_transaction
            (With_status.data t.transaction_with_status)

        let to_latest = Fn.id
      end

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
              Transaction_snark.Pending_coinbase_stack_state.Init_stack.Stable
              .V1
              .t
          ; first_pass_ledger_witness :
              (Mina_ledger.Sparse_ledger.Stable.V2.t[@sexp.opaque])
          ; second_pass_ledger_witness :
              (Mina_ledger.Sparse_ledger.Stable.V2.t[@sexp.opaque])
          ; block_global_slot :
              Mina_numbers.Global_slot_since_genesis.Stable.V1.t
          }
        [@@deriving sexp, to_yojson]

        let to_latest : t -> V3.t =
         fun { transaction_with_info
             ; state_hash
             ; statement
             ; init_stack
             ; first_pass_ledger_witness
             ; second_pass_ledger_witness
             ; block_global_slot
             } ->
          { transaction_with_status =
              Mina_transaction_logic.Transaction_applied
              .transaction_with_status_stable transaction_with_info
          ; statement
          ; state_hash
          ; init_stack =
              ( match init_stack with
              | Base stack ->
                  stack
              | Merge ->
                  failwith "Unexpected stack for witness" )
          ; first_pass_ledger_witness
          ; second_pass_ledger_witness
          ; block_global_slot
          ; previous_protocol_state_body_opt = None
          }
      end
    end]

    type t =
      { transaction_with_status : Transaction.t With_status.t
      ; state_hash : State_hash.t * State_body_hash.t
      ; statement : Transaction_snark.Statement.t
      ; init_stack : Mina_base.Pending_coinbase.Stack_versioned.t
      ; first_pass_ledger_witness : Mina_ledger.Sparse_ledger.t
      ; second_pass_ledger_witness : Mina_ledger.Sparse_ledger.t
      ; block_global_slot : Mina_numbers.Global_slot_since_genesis.t
      ; previous_protocol_state_body_opt :
          Mina_state.Protocol_state.Body.Value.t option
      }

    let source_second_pass_ledger t = t.statement.source.second_pass_ledger

    let target_first_pass_ledger t = t.statement.target.first_pass_ledger

    let transaction_type t =
      Transaction_type.of_transaction
        (With_status.data t.transaction_with_status)

    let of_same_block t1 t2 =
      State_hash.equal (fst t1.state_hash) (fst t2.state_hash)
  end

  include T

  module Tag = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = T.Stable.V3.t State_hash.Tag.Stable.V1.t

        [%%define_locally State_hash.Tag.Stable.V1.(sexp_of_t, t_of_sexp)]

        let to_latest = Fn.id
      end
    end]
  end

  module Tagged = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V1 = struct
        type t =
          { tag : Tag.Stable.V1.t
                (* Consider removing it as well, it is used only in a handful of places *)
          ; statement : Transaction_snark.Statement.Stable.V2.t
          ; transaction_type : Mina_transaction.Transaction_type.Stable.V1.t
          ; parent_state_hash : State_hash.Stable.V1.t
          }
        [@@deriving sexp]

        let to_latest = Fn.id
      end
    end]

    let source_second_pass_ledger t =
      t.Stable.Latest.statement.source.second_pass_ledger

    let target_first_pass_ledger t =
      t.Stable.Latest.statement.target.first_pass_ledger

    let transaction_type t = t.Stable.Latest.transaction_type

    let of_same_block t1 t2 =
      State_hash.equal t1.Stable.Latest.parent_state_hash
        t2.Stable.Latest.parent_state_hash

    let create ~tag (t : T.Stable.Latest.t) =
      { Stable.Latest.tag
      ; statement = t.statement
      ; transaction_type = T.Stable.Latest.transaction_type t
      ; parent_state_hash = fst @@ t.state_hash
      }

    let statement t = t.Stable.Latest.statement

    type t = Stable.Latest.t
  end

  let read_tag (tagged : Tagged.t) : Stable.Latest.t Or_error.t =
    State_hash.File_storage.read (module Stable.Latest) tagged.tag

  let read_tag_exn ~error_tag tagged =
    read_tag tagged |> Or_error.tag ~tag:error_tag |> Or_error.ok_exn

  let read_tags (tagged : Tagged.t list) : Stable.Latest.t list Or_error.t =
    State_hash.File_storage.read_many
      (module Stable.Latest)
      (List.map ~f:(fun { tag; _ } -> tag) tagged)

  let write_all_proofs_to_disk ~signature_kind ~proof_cache_db
      { Stable.Latest.transaction_with_status
      ; state_hash
      ; statement
      ; init_stack
      ; first_pass_ledger_witness
      ; second_pass_ledger_witness
      ; block_global_slot
      ; previous_protocol_state_body_opt
      } =
    { transaction_with_status =
        With_status.map
          ~f:
            (Transaction.write_all_proofs_to_disk ~signature_kind
               ~proof_cache_db )
          transaction_with_status
    ; state_hash
    ; statement
    ; init_stack
    ; first_pass_ledger_witness
    ; second_pass_ledger_witness
    ; block_global_slot
    ; previous_protocol_state_body_opt
    }

  let read_all_proofs_from_disk
      { transaction_with_status
      ; state_hash
      ; statement
      ; init_stack
      ; first_pass_ledger_witness
      ; second_pass_ledger_witness
      ; block_global_slot
      ; previous_protocol_state_body_opt
      } =
    { Stable.Latest.transaction_with_status =
        With_status.map ~f:Transaction.read_all_proofs_from_disk
          transaction_with_status
    ; state_hash
    ; statement
    ; init_stack
    ; first_pass_ledger_witness
    ; second_pass_ledger_witness
    ; block_global_slot
    ; previous_protocol_state_body_opt
    }

  let persist_many witnesses writer =
    let module FS = State_hash.File_storage in
    let write_witness = FS.write_value writer (module Stable.Latest) in
    let write_witness' witness =
      (* TODO remove read_all_proofs_from_disk *)
      let stable = read_all_proofs_from_disk witness in
      Tagged.create ~tag:(write_witness stable) stable
    in
    List.map ~f:write_witness' witnesses
end

module Ledger_proof_with_sok_message = struct
  (* TODO In Mesa use Ledger_proof.t, no need for sok message *)
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t = Ledger_proof.Stable.V2.t * Sok_message.Stable.V1.t
      [@@deriving sexp]

      let to_latest = Fn.id
    end
  end]

  module Tagged = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { tag :
              ( State_hash.Stable.V1.t
              , Proof.Stable.V2.t )
              Multi_key_file_storage.Tag.Stable.V1.t
          ; sok_message : Sok_message.Stable.V1.t
          ; statement : Mina_state.Snarked_ledger_state.With_sok.Stable.V2.t
          }

        let to_latest = Fn.id
      end
    end]

    let create ~tag ~sok_message ~statement = { tag; sok_message; statement }

    let statement (t : t) = { t.statement with sok_digest = () }

    let sok_digest (t : t) = t.statement.sok_digest
  end

  let persist_many works writer =
    let module FS = State_hash.File_storage in
    let write_proof = FS.write_value writer (module Proof.Stable.Latest) in
    let write_proof' ~fee ~prover proof =
      (* TODO remove read_proof_from_disk *)
      let stable = Ledger_proof.Cached.read_proof_from_disk proof in
      let statement = Ledger_proof.statement_with_sok stable in
      let proof = Ledger_proof.underlying_proof stable in
      let sok_message = Sok_message.create ~fee ~prover in
      Tagged.create ~tag:(write_proof proof) ~sok_message ~statement
    in
    List.concat_map works
      ~f:(fun { Transaction_snark_work.proofs; fee; prover } ->
        One_or_two.to_list proofs |> List.map ~f:(write_proof' ~fee ~prover) )

  let read_tag ({ tag; sok_message; statement } : Tagged.t) :
      Stable.Latest.t Or_error.t =
    let%map.Or_error proof =
      State_hash.File_storage.read (module Proof.Stable.Latest) tag
    in
    (Transaction_snark.create ~statement ~proof, sok_message)

  let read_tag_exn ~error_tag tagged =
    read_tag tagged |> Or_error.tag ~tag:error_tag |> Or_error.ok_exn

  type t = Ledger_proof.t * Sok_message.t
end

module Available_job = struct
  type t =
    ( Ledger_proof_with_sok_message.Tagged.t
    , Transaction_with_witness.Tagged.t )
    Parallel_scan.Available_job.t

  let is_transition (t : t) = match t with Base _ -> true | Merge _ -> false

  let target_second_pass_ledger (t : t) =
    match t with
    | Base { statement = { target = { second_pass_ledger; _ }; _ }; _ } ->
        Some second_pass_ledger
    | Merge _ ->
        None

  let single_spec ~get_state = function
    | Parallel_scan.Available_job.Merge (p1, p2) ->
        let%bind.Or_error merged =
          Transaction_snark.Statement.merge
            (Ledger_proof_with_sok_message.Tagged.statement p1)
            (Ledger_proof_with_sok_message.Tagged.statement p2)
        in
        let%bind.Or_error p1', _ = Ledger_proof_with_sok_message.read_tag p1 in
        let%map.Or_error p2', _ = Ledger_proof_with_sok_message.read_tag p2 in
        Snark_work_lib.Work.Single.Spec.Stable.Latest.Merge (merged, p1', p2')
    | Base tagged_witness ->
        let%bind.Or_error { transaction_with_status =
                              { data = transaction; status }
                          ; statement
                          ; state_hash
                          ; first_pass_ledger_witness = first_pass_ledger
                          ; second_pass_ledger_witness = second_pass_ledger
                          ; init_stack
                          ; block_global_slot
                          ; previous_protocol_state_body_opt
                          } =
          Transaction_with_witness.read_tag tagged_witness
        in
        let%map.Or_error protocol_state_body =
          match previous_protocol_state_body_opt with
          | Some protocol_state_body ->
              Ok protocol_state_body
          | None ->
              get_state (fst state_hash)
              |> Or_error.map ~f:Mina_state.Protocol_state.body
        in
        Snark_work_lib.Work.Single.Spec.Stable.Latest.Transition
          ( statement
          , { Transaction_witness.Stable.Latest.first_pass_ledger
            ; second_pass_ledger
            ; transaction
            ; protocol_state_body
            ; init_stack
            ; status
            ; block_global_slot
            } )

  let single_spec_one_or_two ~get_state = function
    | `One job ->
        Or_error.map ~f:(fun x -> `One x) (single_spec ~get_state job)
    | `Two (job1, job2) ->
        let%bind.Or_error spec1 = single_spec ~get_state job1 in
        let%map.Or_error spec2 = single_spec ~get_state job2 in
        `Two (spec1, spec2)

  let statement : t -> Transaction_snark.Statement.t option = function
    | Base { statement; _ } ->
        Some statement
    | Merge (p1, p2) ->
        Transaction_snark.Statement.merge
          (Ledger_proof_with_sok_message.Tagged.statement p1)
          (Ledger_proof_with_sok_message.Tagged.statement p2)
        |> Result.ok
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

let hash_generic ~serialize_ledger_proof_with_sok_message
    ~serialize_transaction_with_witness scan_state
    previous_incomplete_zkapp_updates =
  let state_hash =
    Parallel_scan.State.hash scan_state serialize_ledger_proof_with_sok_message
      serialize_transaction_with_witness
  in
  let ( previous_incomplete_zkapp_updates
      , `Border_block_continued_in_the_next_tree continue_in_next_tree ) =
    previous_incomplete_zkapp_updates
  in
  let incomplete_updates =
    List.fold ~init:(Digestif.SHA256.init ()) previous_incomplete_zkapp_updates
      ~f:(fun h t ->
        Digestif.SHA256.feed_string h @@ serialize_transaction_with_witness t )
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
[%%versioned
module Stable = struct
  (* Caution !!!: Don't merge to `compatible`, this is incompatible with the Berkeley network *)
  module V3 = struct
    type t =
      { scan_state :
          ( Ledger_proof_with_sok_message.Tagged.Stable.V1.t
          , Transaction_with_witness.Tagged.Stable.V1.t )
          Parallel_scan.State.Stable.V1.t
      ; previous_incomplete_zkapp_updates :
          Transaction_with_witness.Tagged.Stable.V1.t list
          * [ `Border_block_continued_in_the_next_tree of bool ]
      }

    (* Caution !!!: Don't merge to `compatible`, this is incompatible with the Berkeley network *)
    let hash (t : t) =
      hash_generic t.scan_state t.previous_incomplete_zkapp_updates
        ~serialize_ledger_proof_with_sok_message:
          ( Fn.compose
              (Binable.to_string
                 (module Ledger_proof_with_sok_message.Stable.V2) )
          @@ Ledger_proof_with_sok_message.read_tag_exn
               ~error_tag:"scan state hashing" )
        ~serialize_transaction_with_witness:
          ( Fn.compose
              (Binable.to_string (module Transaction_with_witness.Stable.V3))
          @@ Transaction_with_witness.read_tag_exn
               ~error_tag:"scan state hashing" )

    let to_latest = Fn.id
  end

  module V2 = struct
    type t =
      { scan_state :
          ( Ledger_proof_with_sok_message.Stable.V2.t
          , Transaction_with_witness.Stable.V2.t )
          Parallel_scan.State.Stable.V1.t
      ; previous_incomplete_zkapp_updates :
          Transaction_with_witness.Stable.V2.t list
          * [ `Border_block_continued_in_the_next_tree of bool ]
      }

    let to_latest : t -> V3.t =
     fun { scan_state
         ; previous_incomplete_zkapp_updates = updates, continue_in_next_tree
         } ->
      State_hash.File_storage.write_values_exn State_hash.dummy
        ~f:(fun writer ->
          let f1
              ((proof, sok_message) : Ledger_proof_with_sok_message.Stable.V2.t)
              =
            let statement = Ledger_proof.statement_with_sok proof in
            let proof' = Ledger_proof.underlying_proof proof in
            let tag =
              State_hash.File_storage.write_value writer
                (module Proof.Stable.V2)
                proof'
            in
            Ledger_proof_with_sok_message.Tagged.create ~tag ~sok_message
              ~statement
          in
          let f2 witness =
            let stable = Transaction_with_witness.Stable.V2.to_latest witness in
            let tag =
              State_hash.File_storage.write_value writer
                (module Transaction_with_witness.Stable.V3)
                stable
            in
            Transaction_with_witness.Tagged.create ~tag stable
          in
          { V3.scan_state = Parallel_scan.State.map scan_state ~f1 ~f2
          ; previous_incomplete_zkapp_updates =
              (List.map updates ~f:f2, continue_in_next_tree)
          } )
  end
end]

(* Caution !!!: Don't merge to `compatible`, this is incompatible with the Berkeley network *)
let hash : t -> _ = Stable.Latest.hash

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
    ; previous_protocol_state_body_opt
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
  let transaction = With_status.data transaction_with_status in
  let%bind previous_protocol_state_body =
    match previous_protocol_state_body_opt with
    | Some protocol_state ->
        Ok protocol_state
    | None ->
        get_state (fst state_hash)
        |> Or_error.map ~f:Mina_state.Protocol_state.body
  in
  let state_view =
    Mina_state.Protocol_state.Body.view previous_protocol_state_body
  in
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

(*
   TODO: move to a different module and use
   let total_proofs (works : Transaction_snark_work.t list) =
     List.sum (module Int) works ~f:(fun w -> One_or_two.length w.proofs) *)

(*************exposed functions*****************)

module Make_statement_scanner (Verifier : sig
  type t

  val verify :
       verifier:t
    -> Ledger_proof_with_sok_message.Stable.Latest.t list
    -> unit Or_error.t Deferred.Or_error.t
end) =
struct
  module Fold = Parallel_scan.State.Make_foldable (Deferred)

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

  let proof_cache_db = Proof_cache_tag.create_identity_db ()

  (*TODO: fold over the pending_coinbase tree and validate the statements?*)
  let scan_statement (type merge) ~constraint_constants ~logger
      ~merge_to_statement
      (tree : (merge, Transaction_with_witness.Tagged.t) Parallel_scan.State.t)
      ~statement_check ~verify =
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
      | Parallel_scan.Merge.Job.Part merge ->
          let statement = merge_to_statement merge in
          let%map acc_stmt =
            merge_acc ~proofs:[ merge ] acc_statement statement
          in
          (acc_stmt, acc_pc)
      | Empty | Full { status = Parallel_scan.Job_status.Done; _ } ->
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
        (tagged : Transaction_with_witness.Tagged.t) =
      with_error "Bad base statement" ~f:(fun () ->
          let%bind expected_statement =
            match statement_check with
            | `Full get_state ->
                let%bind transaction_stable =
                  Transaction_with_witness.read_tag tagged |> Deferred.return
                in
                let transaction =
                  (* TODO: hash computation insude, remove it *)
                  Transaction_with_witness.write_all_proofs_to_disk
                    ~signature_kind:Mina_signature_kind.t_DEPRECATED
                    ~proof_cache_db transaction_stable
                in
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
                return tagged.statement
          in
          let%bind () = yield_always () in
          if
            Transaction_snark.Statement.equal tagged.statement
              expected_statement
          then
            let%bind acc_stmt =
              merge_acc ~proofs:[] acc_statement tagged.statement
            in
            let%map acc_pc =
              merge_pc acc_pc tagged.statement |> Deferred.return
            in
            (acc_stmt, acc_pc)
          else
            Deferred.Or_error.error_string
              (sprintf
                 !"Bad base statement expected: \
                   %{sexp:Transaction_snark.Statement.t} got: \
                   %{sexp:Transaction_snark.Statement.t}"
                 tagged.statement expected_statement ) )
    in
    let fold_step_d (acc_statement, acc_pc) job =
      match job with
      | Parallel_scan.Base.Job.Empty ->
          return (acc_statement, acc_pc)
      | Full
          { status = Parallel_scan.Job_status.Done
          ; job = (transaction : Transaction_with_witness.Tagged.t)
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
        match%map.Deferred verify proofs with
        | Ok (Ok ()) ->
            Ok res
        | Ok (Error err) ->
            Error (`Error (Error.tag ~tag:"Verifier issue" err))
        | Error e ->
            Error (`Error e) )
    | Error e ->
        Deferred.return (Error (`Error e))

  let check_invariants_impl
      (parallel_scan_state :
        (_, Transaction_with_witness.Tagged.t) Parallel_scan.State.t )
      ~merge_to_statement ~constraint_constants ~logger ~statement_check ~verify
      ~error_prefix
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

  let check_invariants t ~verifier =
    let verify tagged_list =
      let%bind.Deferred.Or_error ps =
        Mina_stdlib.Result.List.map ~f:Ledger_proof_with_sok_message.read_tag
          tagged_list
        |> Deferred.return
      in
      Verifier.verify ~verifier ps
    in
    check_invariants_impl t.scan_state
      ~merge_to_statement:Ledger_proof_with_sok_message.Tagged.statement ~verify
end

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

module Transactions_categorized = struct
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
      ; continued_in_the_next_tree : bool
      }
    [@@deriving sexp, to_yojson]
  end

  type t = Transaction_with_witness.t Poly.t

  let fold (t : 'a Poly.t) ~f ~init =
    let init = List.fold ~init t.first_pass ~f in
    let init = List.fold ~init t.previous_incomplete ~f in
    List.fold ~init t.second_pass ~f
end

module Make_transaction_categorizer (Tx : sig
  type t

  val source_second_pass_ledger : t -> Ledger_hash.t

  val target_first_pass_ledger : t -> Ledger_hash.t

  val transaction_type : t -> Mina_transaction.Transaction_type.t

  val of_same_block : t -> t -> bool
end) =
struct
  let txns_by_block txns_per_tree =
    List.group txns_per_tree ~break:(fun t1 t2 -> not (Tx.of_same_block t1 t2))
    |> List.filter_map ~f:Mina_stdlib.Nonempty_list.of_list_opt

  (** Compoutes representation for the sequence of transactions extracted from scan state
      when it emitted a proof, split into:

      * [first_pass] - transactions that went through first pass
      * [second_pass] - transactions that went through second pass and correspond
        to the current ledger proof (subset of first pass group)
      * [current_incomplete] - transactions that went through second pass and correspond
        to the the next ledger proof (subset of first pass group)
      * [previous_incomplete] - leftover from previous ledger proof emitted with
        the current ledger proof (not intersecting with other groups)
        Received as a parameter and passed through if the first transaction in it
        belongs to the same block as the first transaction in [txns_with_witnesses_non_empty].
   *)
  let categorize_transactions ~previous_incomplete txns_non_empty =
    let first_txn = Mina_stdlib.Nonempty_list.head txns_non_empty in
    let txns = Mina_stdlib.Nonempty_list.to_list txns_non_empty in
    let target_first_pass_ledger =
      Tx.target_first_pass_ledger
        (Mina_stdlib.Nonempty_list.last txns_non_empty)
    in
    let second_pass_txns =
      List.filter txns ~f:(fun txn ->
          match Tx.transaction_type txn with
          | `Zkapp_command ->
              true
          | _ ->
              false )
    in
    (* determine whether second pass completed in the same tree *)
    let continued_in_the_next_tree =
      Option.value_map ~default:false ~f:(fun txn ->
          not
          @@ Frozen_ledger_hash.equal
               (Tx.source_second_pass_ledger txn)
               target_first_pass_ledger )
      @@ List.hd second_pass_txns
    in
    let previous_incomplete =
      match previous_incomplete with
      | t :: _ when Tx.of_same_block t first_txn ->
          previous_incomplete
      | _ ->
          []
    in
    { Transactions_categorized.Poly.first_pass = txns
    ; second_pass = second_pass_txns
    ; previous_incomplete
    ; continued_in_the_next_tree
    }

  let second_pass_last_block txns_per_tree =
    let%map.Option last_group = List.last (txns_by_block txns_per_tree) in
    let { Transactions_categorized.Poly.second_pass
        ; continued_in_the_next_tree
        ; _
        } =
      (* [previous_incomplete] is ok to be set empty because it affects
         only the [previous_incomplete] field of the result *)
      categorize_transactions ~previous_incomplete:[] last_group
    in
    ( second_pass
    , `Border_block_continued_in_the_next_tree continued_in_the_next_tree )

  let categorize_transactions_per_tree ~previous_incomplete txns_per_tree =
    List.map
      (txns_by_block txns_per_tree)
      ~f:(categorize_transactions ~previous_incomplete)

  let categorize_transactions_per_forest scan_state_txns ~previous_incomplete =
    List.map scan_state_txns
      ~f:(categorize_transactions_per_tree ~previous_incomplete)
end

module Witness_categorizer =
  Make_transaction_categorizer (Transaction_with_witness)
module Tagged_categorizer =
  Make_transaction_categorizer (Transaction_with_witness.Tagged)

let extract_txn_and_global_slot (txn_with_witness : Transaction_with_witness.t)
    =
  let txn = txn_with_witness.transaction_with_status in
  let state_hash = fst txn_with_witness.state_hash in
  let global_slot = txn_with_witness.block_global_slot in
  (txn, state_hash, global_slot)

let latest_ledger_proof_statement t =
  let%map.Option tagged, _ = Parallel_scan.last_emitted_value t.scan_state in
  Ledger_proof_with_sok_message.Tagged.statement tagged

let latest_recent_proof_txs_impl ~process ~continued_in_next_tree
    ~previous_incomplete txns_with_witnesses =
  let txns =
    process
      ~previous_incomplete:
        (if continued_in_next_tree then previous_incomplete else [])
      txns_with_witnesses
  in
  if List.is_empty previous_incomplete then txns
  else
    { Transactions_categorized.Poly.first_pass = []
    ; second_pass = []
    ; previous_incomplete
    ; continued_in_the_next_tree = false
    }
    :: txns

let read_tags_and_write_proofs ~signature_kind ~proof_cache_db txns_tagged =
  let%map.Or_error txns_stable =
    Transaction_with_witness.read_tags txns_tagged
  in
  (* TODO: hash computation insude, remove it *)
  List.map
    ~f:
      (Transaction_with_witness.write_all_proofs_to_disk ~signature_kind
         ~proof_cache_db )
    txns_stable

let latest_recent_proof_txs_untagged ~signature_kind ~proof_cache_db t =
  match Parallel_scan.last_emitted_value t.scan_state |> Option.map ~f:snd with
  | None ->
      Or_error.return None
  | Some txns_with_witnesses_tagged ->
      let ( previous_incomplete_tagged
          , `Border_block_continued_in_the_next_tree continued_in_next_tree ) =
        t.previous_incomplete_zkapp_updates
      in
      let%bind.Or_error txns_with_witnesses =
        read_tags_and_write_proofs ~signature_kind ~proof_cache_db
          txns_with_witnesses_tagged
      in
      let%map.Or_error previous_incomplete =
        read_tags_and_write_proofs ~signature_kind ~proof_cache_db
          previous_incomplete_tagged
      in
      latest_recent_proof_txs_impl
        ~process:Witness_categorizer.categorize_transactions_per_tree
        ~continued_in_next_tree ~previous_incomplete txns_with_witnesses
      |> Option.some

let incomplete_txns_from_recent_proof_tree t =
  let%map.Option tagged, txns_with_witnesses =
    Parallel_scan.last_emitted_value t.scan_state
  in
  (* First pass ledger is considered as the snarked ledger,
     so any account update whether completed in the same tree
     or not should be included in the next tree *)
  let res =
    Tagged_categorizer.second_pass_last_block txns_with_witnesses
    |> Option.value ~default:([], `Border_block_continued_in_the_next_tree false)
  in
  (Ledger_proof_with_sok_message.Tagged.statement tagged, res)

let staged_transactions t =
  let process ~previous_incomplete txns =
    Tagged_categorizer.categorize_transactions_per_forest ~previous_incomplete
      txns
    |> List.concat
  in
  let ( previous_incomplete
      , `Border_block_continued_in_the_next_tree continued_in_next_tree ) =
    Option.value_map
      ~default:([], `Border_block_continued_in_the_next_tree false)
      (incomplete_txns_from_recent_proof_tree t)
      ~f:snd
  in
  let txns_with_witnesses = Parallel_scan.pending_data t.scan_state in
  latest_recent_proof_txs_impl ~process ~continued_in_next_tree
    ~previous_incomplete txns_with_witnesses

let staged_transactions_untagged ~signature_kind ~proof_cache_db t =
  let process ~previous_incomplete txns =
    Witness_categorizer.categorize_transactions_per_forest ~previous_incomplete
      txns
    |> List.concat
  in
  let ( previous_incomplete_tagged
      , `Border_block_continued_in_the_next_tree continued_in_next_tree ) =
    Option.value_map
      ~default:([], `Border_block_continued_in_the_next_tree false)
      (incomplete_txns_from_recent_proof_tree t)
      ~f:snd
  in
  let txns_with_witnesses_tagged = Parallel_scan.pending_data t.scan_state in
  let%bind.Or_error txns_with_witnesses =
    Mina_stdlib.Result.List.map
      ~f:(read_tags_and_write_proofs ~signature_kind ~proof_cache_db)
      txns_with_witnesses_tagged
  in
  let%map.Or_error previous_incomplete =
    read_tags_and_write_proofs ~signature_kind ~proof_cache_db
      previous_incomplete_tagged
  in
  latest_recent_proof_txs_impl ~process ~continued_in_next_tree
    ~previous_incomplete txns_with_witnesses

(* written in continuation passing style so that implementation can be used both sync and async *)
let apply_categorized_txns_stepwise ?(stop_at_first_pass = false)
    categorized_txns ~ledger ~get_protocol_state ~apply_first_pass
    ~apply_second_pass ~apply_first_pass_sparse_ledger =
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
      (categorized_txns : _ Transactions_categorized.Poly.t list)
      ~first_pass_ledger_hash ~signature_kind =
    let previous_incomplete =
      (*filter out any non-zkapp transactions for second pass application*)
      match previous_incomplete with
      | Previous_incomplete_txns.Unapplied txns ->
          Previous_incomplete_txns.Unapplied
            (List.filter txns ~f:(fun txn ->
                 match With_status.data txn.transaction_with_status with
                 | Command (Zkapp_command _) ->
                     true
                 | _ ->
                     false ) )
      | Partially_applied txns ->
          Partially_applied
            (List.filter txns ~f:(fun (_, t) ->
                 match t with Zkapp_command _ -> true | _ -> false ) )
    in
    match categorized_txns with
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
    | txns_per_block :: categorized_txns' ->
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
                  && txns_per_block.continued_in_the_next_tree
                in
                let do_second_pass =
                  (*if transactions completed in the same tree; do second pass now*)
                  (not txns_per_block.continued_in_the_next_tree)
                  || continue_previous_tree's_txns
                in
                if do_second_pass then
                  apply_txns_second_pass partially_applied_txns ~k:(fun () ->
                      apply_txns (Unapplied []) categorized_txns'
                        ~first_pass_ledger_hash ~signature_kind )
                else
                  (*Transactions not completed in this tree, so second pass after first pass of remaining transactions for the same block in the next tree*)
                  apply_txns (Partially_applied partially_applied_txns)
                    categorized_txns' ~first_pass_ledger_hash ~signature_kind ) )
  in
  let previous_incomplete =
    Option.value_map (List.hd categorized_txns)
      ~default:(Previous_incomplete_txns.Unapplied [])
      ~f:(fun (first_block : Transactions_categorized.t) ->
        Unapplied first_block.previous_incomplete )
  in
  (*Assuming this function is called on snarked ledger and snarked ledger is the
    first pass ledger*)
  let first_pass_ledger_hash =
    `First_pass_ledger_hash (Ledger.merkle_root ledger)
  in
  apply_txns previous_incomplete categorized_txns ~first_pass_ledger_hash

let apply_categorized_txns_sync ?stop_at_first_pass categorized_txns ~ledger
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
  @@ apply_categorized_txns_stepwise ?stop_at_first_pass categorized_txns
       ~ledger ~get_protocol_state ~apply_first_pass ~apply_second_pass
       ~apply_first_pass_sparse_ledger ~signature_kind

let apply_categorized_txns_async ?stop_at_first_pass categorized_txns
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
  @@ apply_categorized_txns_stepwise ?stop_at_first_pass categorized_txns
       ~ledger ~get_protocol_state ~apply_first_pass ~apply_second_pass
       ~apply_first_pass_sparse_ledger ~signature_kind

(* Used in move_root if the block emitted a proof *)
let get_snarked_ledger_sync ~ledger ~get_protocol_state ~apply_first_pass
    ~apply_second_pass ~apply_first_pass_sparse_ledger ~signature_kind t =
  (* NOTE: data is short-lived, so it's ok to use identity cache *)
  match%bind.Or_error
    latest_recent_proof_txs_untagged ~signature_kind
      ~proof_cache_db:(Proof_cache_tag.create_identity_db ())
      t
  with
  | None ->
      Or_error.errorf "No transactions found"
  | Some txns_per_block ->
      apply_categorized_txns_sync ~stop_at_first_pass:true txns_per_block
        ~ledger ~get_protocol_state ~apply_first_pass ~apply_second_pass
        ~apply_first_pass_sparse_ledger ~signature_kind
      |> Or_error.ignore_m

(* Used in get_snarked_ledger_full, which is used for:
   - Checking membership of an account vs ledger (GraphQL)
   - Client's endpoint to export ledger
   - Hardfork migration *)
let get_snarked_ledger_async ?async_batch_size ~ledger ~get_protocol_state
    ~apply_first_pass ~apply_second_pass ~apply_first_pass_sparse_ledger
    ~signature_kind t =
  (* NOTE: data is short-lived, so it's ok to use identity cache *)
  match%bind.Deferred.Or_error
    latest_recent_proof_txs_untagged ~signature_kind
      ~proof_cache_db:(Proof_cache_tag.create_identity_db ())
      t
    |> Deferred.return
  with
  | None ->
      Deferred.Or_error.errorf "No transactions found"
  | Some txns_per_block ->
      apply_categorized_txns_async ~stop_at_first_pass:true txns_per_block
        ?async_batch_size ~ledger ~get_protocol_state ~apply_first_pass
        ~apply_second_pass ~apply_first_pass_sparse_ledger ~signature_kind
      |> Deferred.Or_error.ignore_m

(* Used in loading the root from disk or receiving it during bootstrap *)
let get_staged_ledger_async ?async_batch_size ~ledger ~get_protocol_state
    ~apply_first_pass ~apply_second_pass ~apply_first_pass_sparse_ledger
    ~signature_kind t =
  (* NOTE: data is short-lived, so it's ok to use identity cache *)
  let%bind.Deferred.Or_error staged_txns =
    staged_transactions_untagged ~signature_kind
      ~proof_cache_db:(Proof_cache_tag.create_identity_db ())
      t
    |> Deferred.return
  in
  apply_categorized_txns_async staged_txns ?async_batch_size ~ledger
    ~get_protocol_state ~apply_first_pass ~apply_second_pass
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
    let fa a = Ledger_proof_with_sok_message.Tagged.statement a in
    let fd (d : Transaction_with_witness.Tagged.t) = d.statement in
    Parallel_scan.view_jobs_with_position t.scan_state fa fd
  in
  Yojson.Safe.to_string
    (`List
      (List.map all_jobs ~f:(fun tree ->
           `List (List.map tree ~f:Job_view.to_yojson) ) ) )

(* TODO create a function work_statements_length and use it
   where only the length of the list is needed *)
(* Length is used in ledger application. Whole list is
   needed only in a test and in Snark_pool_refcount extension (i.e.
   processing will happen once on each block) *)
(*Always the same pairing of jobs*)
let all_work_statements_exn t : Transaction_snark_work.Statement.t list =
  let work_seqs = all_jobs t in
  List.concat_map work_seqs ~f:(fun work_seq ->
      One_or_two.group_list
        (List.map work_seq ~f:(fun job ->
             match Available_job.statement job with
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

(* TODO create a function work_statements_length and use it
   where only the length of the list is needed *)
(* Length is used in ledger application. Whole list is
   needed only in tests and in [Staged_ledger.create_diff] *)
(*Always the same pairing of jobs*)
let work_statements_for_new_diff t : Transaction_snark_work.Statement.t list =
  let work_list = Parallel_scan.jobs_for_next_update t.scan_state in
  List.concat_map work_list ~f:(fun work_seq ->
      One_or_two.group_list
        (List.map work_seq ~f:(fun job ->
             match Available_job.statement job with
             | None ->
                 assert false
             | Some stmt ->
                 stmt ) ) )

let all_work_pairs t : Available_job.t One_or_two.t list =
  all_jobs t |> List.concat_map ~f:One_or_two.group_list

let update_metrics t = Parallel_scan.update_metrics t.scan_state

let fill_work_and_enqueue_transactions t ~logger transactions works =
  let open Or_error.Let_syntax in
  (*get incomplete transactions from previous proof which will be completed in
     the new proof, if there's one*)
  let old_proof_and_incomplete_zkapp_updates =
    incomplete_txns_from_recent_proof_tree t
  in
  let%bind proof_opt, updated_scan_state =
    Parallel_scan.update t.scan_state ~completed_jobs:works ~data:transactions
  in
  [%log internal] "@metadata"
    ~metadata:
      [ ("scan_state_added_works", `Int (List.length works))
        (* TODO uncomment *)
        (* ; ("total_proofs", `Int (total_proofs works)) *)
      ; ("merge_jobs_created", `Int (List.length works))
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
      ~f:(fun (curr_tagged, _txns_with_witnesses) ->
        let curr_stmt =
          Ledger_proof_with_sok_message.Tagged.statement curr_tagged
        in
        let prev_stmt, incomplete_zkapp_updates_from_old_proof =
          Option.value_map
            ~default:
              (curr_stmt, ([], `Border_block_continued_in_the_next_tree false))
            old_proof_and_incomplete_zkapp_updates
            ~f:(fun (p', incomplete_zkapp_updates_from_old_proof) ->
              (p', incomplete_zkapp_updates_from_old_proof) )
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
            let proof' =
              let%map.Option ({ tag; _ } as tagged), _ =
                Parallel_scan.last_emitted_value scan_state'.scan_state
              in
              let statement =
                Ledger_proof_with_sok_message.Tagged.statement tagged
              in
              Ledger_proof.Tagged.create ~statement ~proof:tag
                ~sok_digest:
                  (Ledger_proof_with_sok_message.Tagged.sok_digest tagged)
            in
            Ok (proof', scan_state')
        | Error e ->
            Or_error.errorf
              "The new final statement does not connect to the previous \
               proof's statement: %s"
              (Error.to_string_hum e) )
  in
  (result_opt, scan_state')

let required_state_hashes t =
  List.fold ~init:State_hash.Set.empty
    ~f:(fun acc txns ->
      Transactions_categorized.fold ~init:acc txns ~f:(fun acc t ->
          Set.add acc
            t.Transaction_with_witness.Tagged.Stable.Latest.parent_state_hash )
      )
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
