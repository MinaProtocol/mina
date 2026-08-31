open Core
open Mina_base
open Mina_transaction
open Signature_lib

module type S = sig
  module Error : sig
    type t =
      | Verification_failed of Verifier.Failure.t
      | Coinbase_error of string
      | Insufficient_fee of Currency.Fee.t * Currency.Fee.t
      | Internal_command_status_mismatch
      | Unexpected of Error.t
    [@@deriving sexp]

    val to_string : t -> string

    val to_error : t -> Error.t
  end

  val get_unchecked :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> coinbase_receiver:Public_key.Compressed.t
    -> supercharge_coinbase:bool
    -> Staged_ledger_diff.With_valid_signatures_and_proofs.t
    -> ( Transaction.Valid.t With_status.t list
         * Transaction_snark_work.t list
         * int
         * Currency.Amount.t option
       , Error.t )
       result

  val get_transactions_stable :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> coinbase_receiver:Public_key.Compressed.t
    -> supercharge_coinbase:bool
    -> Staged_ledger_diff.Stable.Latest.t
    -> (Transaction.Stable.Latest.t With_status.t list, Error.t) result

  val get_transactions :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> coinbase_receiver:Public_key.Compressed.t
    -> supercharge_coinbase:bool
    -> Staged_ledger_diff.t
    -> (Transaction.t With_status.t list, Error.t) result
end

module Error = struct
  type t =
    | Verification_failed of Verifier.Failure.t
    | Coinbase_error of string
    | Insufficient_fee of Currency.Fee.t * Currency.Fee.t
    | Internal_command_status_mismatch
    | Unexpected of Error.t
  [@@deriving sexp]

  let to_string = function
    | Verification_failed t ->
        Format.asprintf !"Failed to verify: %{sexp: Verifier.Failure.t} \n" t
    | Coinbase_error err ->
        Format.asprintf !"Coinbase error: %s \n" err
    | Insufficient_fee (f1, f2) ->
        Format.asprintf
          !"Transaction fees %{sexp: Currency.Fee.t} does not suffice proof \
            fees %{sexp: Currency.Fee.t} \n"
          f1 f2
    | Internal_command_status_mismatch ->
        "Internal command statuses did not match"
    | Unexpected e ->
        Error.to_string_hum e

  let to_error = Fn.compose Error.of_string to_string
end

type ('t, 'w) t =
  { transactions : 't list
  ; work : 'w list
  ; commands_count : int
  ; coinbase : Currency.Amount.t option
  }

(*A Coinbase is a single transaction that accommodates the coinbase amount
    and a fee transfer for the work required to add the coinbase. It also
    contains the state body hash corresponding to a particular protocol state.
    Unlike a transaction, a coinbase (including the fee transfer) just requires one slot
    in the jobs queue.

    Fee transfers pay up to two provers each, so the slots a transaction
    occupies are one for itself plus, at worst, one shared fee transfer slot.

    When the diff is split into two prediffs (why? refer to #687), exactly one
    of them carries the coinbase. It is possible for the first prediff to have
    no slots left after adding transactions (for example, when there are three
    slots and maximum number of provers), in which case we add the coinbase as
    part of the second prediff.
*)
let create_coinbase coinbase_parts ~(receiver : Public_key.Compressed.t)
    ~coinbase_amount ~fee_remainder =
  let open Result.Let_syntax in
  let coinbase_or_error = function
    | Ok x ->
        Ok x
    | Error e ->
        Error (Error.Coinbase_error (Core.Error.to_string_hum e))
  in
  match coinbase_parts with
  | `Zero ->
      if Currency.Fee.equal fee_remainder Currency.Fee.zero then return None
      else
        Error
          (Error.Coinbase_error
             "A block with no coinbase has no way to pay out its fee excess" )
  | `One x ->
      let%map cb =
        Coinbase.create ~amount:coinbase_amount ~receiver ~fee_transfer:x
          ~fee_remainder
        |> coinbase_or_error
      in
      Some cb

let sum_fees xs ~f =
  with_return (fun { return } ->
      Ok
        (List.fold ~init:Currency.Fee.zero xs ~f:(fun acc x ->
             match Currency.Fee.add acc (f x) with
             | None ->
                 return (Or_error.error_string "Fee overflow")
             | Some res ->
                 res ) ) )

let to_staged_ledger_or_error =
  Result.map_error ~f:(fun error -> Error.Unexpected error)

module Transaction_data = struct
  type 'a t =
    { commands : 'a list
    ; coinbase : Coinbase.t option
    ; fee_transfers : Fee_transfer.t list
    }
end

module Transaction_data_getter (T : Transaction_snark_work.S) = struct
  let create_fee_transfers completed_works coinbase_fts =
    let open Result.Let_syntax in
    let singles =
      List.filter_map completed_works ~f:(fun w ->
          let fee = T.fee w in
          if Currency.Fee.equal fee Currency.Fee.zero then None
          else Some (T.prover w, fee) )
    in
    let%bind singles_map =
      Or_error.try_with (fun () ->
          Public_key.Compressed.Map.of_alist_reduce singles ~f:(fun f1 f2 ->
              Option.value_exn (Currency.Fee.add f1 f2) ) )
      |> to_staged_ledger_or_error
    in
    (* deduct the coinbase work fee from the singles_map. It is already part of the coinbase *)
    Or_error.try_with (fun () ->
        List.fold coinbase_fts ~init:singles_map
          ~f:(fun accum { Coinbase.Fee_transfer.receiver_pk; fee = cb_fee } ->
            match Map.find accum receiver_pk with
            | None ->
                accum
            | Some fee ->
                let new_fee = Option.value_exn (Currency.Fee.sub fee cb_fee) in
                if Currency.Fee.(new_fee > Currency.Fee.zero) then
                  Map.update accum receiver_pk ~f:(fun _ -> new_fee)
                else Map.remove accum receiver_pk )
        (* TODO: This creates a weird incentive to have a small public_key *)
        |> Map.to_alist ~key_order:`Increasing
        |> List.map ~f:(fun (receiver_pk, fee) ->
            Fee_transfer.Single.create ~receiver_pk ~fee
              ~fee_token:Token_id.default )
        |> One_or_two.group_list
        |> List.map ~f:Fee_transfer.of_singles
        |> Or_error.all )
    |> Or_error.join |> to_staged_ledger_or_error

  let fee_remainder (type update a b c)
      ~(to_user_command : c -> (update, a, b) User_command.with_forest)
      (commands : c list) completed_works coinbase_fee =
    let open Result.Let_syntax in
    let%bind budget =
      sum_fees commands ~f:(fun t -> User_command.fee (to_user_command t))
      |> to_staged_ledger_or_error
    in
    let%bind work_fee =
      sum_fees completed_works ~f:T.fee |> to_staged_ledger_or_error
    in
    let total_work_fee =
      Option.value ~default:Currency.Fee.zero
        (Currency.Fee.sub work_fee coinbase_fee)
    in
    Option.value_map
      ~default:(Error (Error.Insufficient_fee (budget, total_work_fee)))
      ~f:(fun x -> Ok x)
      (Currency.Fee.sub budget total_work_fee)

  let get_transaction_data (type c) coinbase_parts ~receiver ~coinbase_amount
      ~fee_remainder (commands : c list) (completed_works : T.t list) :
      (c Transaction_data.t, Error.t) Result.t =
    let open Result.Let_syntax in
    let coinbase_fts =
      match coinbase_parts with `Zero -> [] | `One x -> Option.to_list x
    in
    let txn_works_others =
      List.filter completed_works ~f:(fun w ->
          not (Public_key.Compressed.equal receiver (T.prover w)) )
    in
    let%bind coinbase =
      O1trace.sync_thread "create_coinbase" (fun () ->
          create_coinbase coinbase_parts ~receiver ~coinbase_amount
            ~fee_remainder )
    in
    let%map fee_transfers =
      create_fee_transfers txn_works_others coinbase_fts
    in
    { Transaction_data.commands; coinbase; fee_transfers }

  (* Whatever the transaction fees do not spend on provers is paid to the
     coinbase receiver by the coinbase itself, rather than by a fee transfer of
     its own.

     It is a property of the whole diff rather than of either pre-diff. A block
     whose transactions span two scan state trees has its commands on one side
     and, since the coinbase is its last transaction, the coinbase on the
     other: only the side carrying the coinbase can pay the remainder out. *)
  let total_fee_remainder (type update a b c) ~receiver
      ~(to_user_command : c -> (update, a, b) User_command.with_forest)
      ~coinbase_fts (commands : c list) (completed_works : T.t list) =
    let coinbase_work_fees =
      sum_fees ~f:Coinbase.Fee_transfer.fee coinbase_fts |> Or_error.ok_exn
    in
    let txn_works_others =
      List.filter completed_works ~f:(fun w ->
          not (Public_key.Compressed.equal receiver (T.prover w)) )
    in
    fee_remainder commands txn_works_others coinbase_work_fees ~to_user_command
end

module Transaction_data_getter_unchecked =
  Transaction_data_getter (Transaction_snark_work)
module Transaction_data_getter_checked =
  Transaction_data_getter (Transaction_snark_work.Checked)
module Transaction_data_getter_stable =
  Transaction_data_getter (Transaction_snark_work.Stable.Latest)

let get_individual_info (type c)
    ~(get_transaction_data :
          [< `One of Coinbase_fee_transfer.t option | `Zero ]
       -> receiver:Public_key.Compressed.t
       -> coinbase_amount:Currency.Amount.t
       -> fee_remainder:Currency.Fee.t
       -> c With_status.t list
       -> 'work list
       -> (c With_status.t Transaction_data.t, Error.t) result ) coinbase_parts
    ~receiver ~coinbase_amount ~fee_remainder (commands : c With_status.t list)
    completed_works ~internal_command_statuses =
  let open Result.Let_syntax in
  let%bind { Transaction_data.commands; coinbase; fee_transfers } =
    get_transaction_data coinbase_parts ~receiver ~coinbase_amount
      ~fee_remainder commands completed_works
  in
  (* The coinbase is the last transaction of the block: every fee payment
     precedes it, so the fee excess it settles is the whole of what the block
     collected, and the ledger it leaves behind is the block's final one. *)
  let internal_commands =
    List.map fee_transfers ~f:(fun t -> Transaction.Fee_transfer t)
    @ List.map (Option.to_list coinbase) ~f:(fun t -> Transaction.Coinbase t)
  in
  let%map internal_commands_with_statuses =
    Or_error.try_with (fun () ->
        List.map2_exn internal_commands internal_command_statuses
          ~f:(fun cmd status ->
            match cmd with
            | Transaction.Coinbase _ | Transaction.Fee_transfer _ ->
                { With_status.data = cmd; status }
            | _ ->
                (* Caught by [try_with] above, it doesn't matter what we throw. *)
                assert false ) )
    |> Result.map_error ~f:(fun _ -> Error.Internal_command_status_mismatch)
  in
  let transactions =
    List.map commands ~f:(With_status.map ~f:(fun t -> Transaction.Command t))
    @ internal_commands_with_statuses
  in
  { transactions
  ; work = completed_works
  ; commands_count = List.length commands
  ; coinbase = Option.map coinbase ~f:(fun Coinbase.{ amount; _ } -> amount)
  }

let check_coinbase
    (diff :
      _ Staged_ledger_diff.Pre_diff_two.t
      * _ Staged_ledger_diff.Pre_diff_one.t option ) =
  match
    ( (fst diff).coinbase
    , Option.value_map ~default:Staged_ledger_diff.At_most_one.Zero (snd diff)
        ~f:(fun d -> d.coinbase ) )
  with
  | Zero, Zero | Zero, One _ | One _, Zero ->
      Ok ()
  | x, y ->
      Error
        (Error.Coinbase_error
           (sprintf
              !"Invalid coinbase value in staged ledger prediffs \
                %{sexp:Coinbase.Fee_transfer.t \
                Staged_ledger_diff.At_most_one.t} and \
                %{sexp:Coinbase.Fee_transfer.t \
                Staged_ledger_diff.At_most_one.t}"
              x y ) )

let compute_statuses
    ~(constraint_constants : Genesis_constants.Constraint_constants.t) ~diff
    ~coinbase_receiver ~coinbase_amount ~global_slot ~txn_state_view ~ledger :
    (Staged_ledger_diff.With_valid_signatures_and_proofs.diff, _) result =
  let open Result.Let_syntax in
  let ( (p1 :
          ( Transaction_snark_work.Checked.t
          , _ )
          Staged_ledger_diff.Pre_diff_two.t )
      , (p2 :
          ( Transaction_snark_work.Checked.t
          , _ )
          Staged_ledger_diff.Pre_diff_one.t
          option ) ) =
    diff
  in
  let coinbase_fts =
    let of_at_most_one = function
      | Staged_ledger_diff.At_most_one.Zero ->
          []
      | One x ->
          Option.to_list x
    in
    of_at_most_one p1.coinbase
    @ Option.value_map p2 ~default:[] ~f:(fun d -> of_at_most_one d.coinbase)
  in
  let%bind total_fee_remainder =
    Transaction_data_getter_checked.total_fee_remainder
      ~receiver:coinbase_receiver ~to_user_command:User_command.forget_check
      ~coinbase_fts
      (p1.commands @ Option.value_map p2 ~default:[] ~f:(fun d -> d.commands))
      ( p1.completed_works
      @ Option.value_map p2 ~default:[] ~f:(fun d -> d.completed_works) )
  in
  (* Only the pre-diff carrying the coinbase can pay the remainder out. *)
  let remainder_for = function
    | Staged_ledger_diff.At_most_one.Zero ->
        Currency.Fee.zero
    | One _ ->
        total_fee_remainder
  in
  (* project transactions into a sequence of transactions *)
  let project_transactions ~coinbase_parts ~commands ~completed_works
      ~fee_remainder =
    let%map { Transaction_data.commands; coinbase; fee_transfers } =
      Transaction_data_getter_checked.get_transaction_data coinbase_parts
        ~receiver:coinbase_receiver ~coinbase_amount ~fee_remainder commands
        (completed_works : Transaction_snark_work.Checked.t list)
    in
    List.map commands ~f:(fun t ->
        Transaction.Command (User_command.forget_check t) )
    @ List.map fee_transfers ~f:(fun t -> Transaction.Fee_transfer t)
    @ List.map (Option.to_list coinbase) ~f:(fun t -> Transaction.Coinbase t)
  in
  let project_transactions_pre_diff_two
      (p :
        (Transaction_snark_work.Checked.t, _) Staged_ledger_diff.Pre_diff_two.t
        ) =
    let coinbase_parts =
      match p.coinbase with Zero -> `Zero | One x -> `One x
    in
    project_transactions ~coinbase_parts ~commands:p.commands
      ~completed_works:p.completed_works
      ~fee_remainder:(remainder_for p.coinbase)
  in
  let project_transactions_pre_diff_one
      (p :
        (Transaction_snark_work.Checked.t, _) Staged_ledger_diff.Pre_diff_one.t
        ) =
    let coinbase_parts =
      match p.coinbase with Zero -> `Zero | One x -> `One x
    in
    project_transactions ~coinbase_parts ~commands:p.commands
      ~completed_works:p.completed_works
      ~fee_remainder:(remainder_for p.coinbase)
  in
  (* partition a sequence of transactions with statuses into user commands with statuses and internal command statuses *)
  let split_transaction_statuses txns_with_statuses =
    List.partition_map txns_with_statuses ~f:(fun txn_applied ->
        let { With_status.data = txn; status } =
          Mina_transaction_logic.Transaction_applied.transaction_with_status
            txn_applied
        in
        match txn with
        | Transaction.Command cmd ->
            (* this is safe because the commands we applied to the ledger were valid before *)
            let (`If_this_is_used_it_should_have_a_comment_justifying_it cmd') =
              User_command.to_valid_unsafe cmd
            in
            Either.First { With_status.data = cmd'; status }
        | Transaction.Fee_transfer _ | Transaction.Coinbase _ ->
            Either.Second status )
  in
  let%bind num_p1_txns, txns =
    let%map p1_txns = project_transactions_pre_diff_two p1
    and p2_txns =
      Option.value_map ~f:project_transactions_pre_diff_one ~default:(Ok []) p2
    in
    (List.length p1_txns, p1_txns @ p2_txns)
  in
  let%map txns_with_statuses =
    Transaction_snark.Transaction_validator.apply_transactions
      ~constraint_constants ~global_slot ~txn_state_view
      ~signature_kind:Mina_signature_kind.t_DEPRECATED ledger txns
    |> Result.map_error ~f:(fun err -> Error.Unexpected err)
  in
  let p1_txns_with_statuses, p2_txns_with_statuses =
    List.split_n txns_with_statuses num_p1_txns
  in
  let p1' =
    let commands, internal_command_statuses =
      split_transaction_statuses p1_txns_with_statuses
    in
    { p1 with commands; internal_command_statuses }
  in
  let p2' =
    Option.map p2 ~f:(fun p ->
        let commands, internal_command_statuses =
          split_transaction_statuses p2_txns_with_statuses
        in
        { p with commands; internal_command_statuses } )
  in
  (p1', p2')

let get_impl (type c) ~get_transaction_data ~total_fee_remainder
    ~(constraint_constants : Genesis_constants.Constraint_constants.t)
    ~(to_user_command : c With_status.t -> (_, _, _) User_command.with_forest)
    ~diff ~coinbase_receiver ~coinbase_amount =
  let open Result.Let_syntax in
  let%bind coinbase_amount =
    Option.value_map coinbase_amount
      ~default:
        (Error
           (Error.Coinbase_error
              (sprintf
                 !"Overflow when calculating coinbase amount: Supercharged \
                   coinbase factor (%d) x coinbase amount (%{sexp: \
                   Currency.Amount.t})"
                 constraint_constants.supercharged_coinbase_factor
                 constraint_constants.coinbase_amount ) ) )
      ~f:(fun x -> Ok x)
  in
  let t1, t2 = diff in
  let coinbase_fts =
    let of_at_most_one = function
      | Staged_ledger_diff.At_most_one.Zero ->
          []
      | One x ->
          Option.to_list x
    in
    of_at_most_one t1.Staged_ledger_diff.Pre_diff_two.coinbase
    @ Option.value_map t2 ~default:[] ~f:(fun d ->
        of_at_most_one d.Staged_ledger_diff.Pre_diff_one.coinbase )
  in
  let%bind total_fee_remainder =
    total_fee_remainder ~receiver:coinbase_receiver ~to_user_command
      ~coinbase_fts
      (t1.commands @ Option.value_map t2 ~default:[] ~f:(fun d -> d.commands))
      ( t1.completed_works
      @ Option.value_map t2 ~default:[] ~f:(fun d -> d.completed_works) )
  in
  (* Only the pre-diff carrying the coinbase can pay the remainder out. *)
  let remainder_for = function
    | Staged_ledger_diff.At_most_one.Zero ->
        Currency.Fee.zero
    | One _ ->
        total_fee_remainder
  in
  let apply_pre_diff_with_at_most_two (t1 : _ Staged_ledger_diff.Pre_diff_two.t)
      =
    let coinbase_parts =
      match t1.coinbase with Zero -> `Zero | One x -> `One x
    in
    get_individual_info ~get_transaction_data coinbase_parts
      ~receiver:coinbase_receiver t1.commands t1.completed_works
      ~coinbase_amount
      ~fee_remainder:(remainder_for t1.coinbase)
      ~internal_command_statuses:t1.internal_command_statuses
  in
  let apply_pre_diff_with_at_most_one (t2 : _ Staged_ledger_diff.Pre_diff_one.t)
      =
    let coinbase_added =
      match t2.coinbase with Zero -> `Zero | One x -> `One x
    in
    get_individual_info ~get_transaction_data coinbase_added
      ~receiver:coinbase_receiver t2.commands t2.completed_works
      ~coinbase_amount
      ~fee_remainder:(remainder_for t2.coinbase)
      ~internal_command_statuses:t2.internal_command_statuses
  in
  let%bind () = check_coinbase diff in
  let%bind p1 = apply_pre_diff_with_at_most_two (fst diff) in
  let%map p2 =
    Option.value_map
      ~f:(fun d -> apply_pre_diff_with_at_most_one d)
      (snd diff)
      ~default:
        (Ok
           { transactions = []; work = []; commands_count = 0; coinbase = None }
        )
  in
  ( p1.transactions @ p2.transactions
  , p1.work @ p2.work
  , p1.commands_count + p2.commands_count
  , Option.first_some p1.coinbase p2.coinbase )

(* TODO: This is important *)
let get ~check ~constraint_constants ~coinbase_receiver ~supercharge_coinbase t
    =
  let open Async in
  match%map Staged_ledger_diff.validate_commands t ~check with
  | Error e ->
      Error (Error.Unexpected e)
  | Ok (Error e) ->
      Error (Error.Verification_failed e)
  | Ok (Ok diff) ->
      let open Transaction_data_getter_unchecked in
      get_impl ~get_transaction_data ~total_fee_remainder ~constraint_constants
        ~to_user_command:(Fn.compose User_command.forget_check With_status.data)
        ~diff:diff.diff ~coinbase_receiver
        ~coinbase_amount:
          (Staged_ledger_diff.With_valid_signatures.coinbase
             ~constraint_constants ~supercharge_coinbase diff )

let get_unchecked ~constraint_constants ~coinbase_receiver ~supercharge_coinbase
    (t : Staged_ledger_diff.With_valid_signatures_and_proofs.t) =
  let t = Staged_ledger_diff.forget_proof_checks t in
  let open Transaction_data_getter_unchecked in
  get_impl ~get_transaction_data ~total_fee_remainder ~constraint_constants
    ~diff:t.diff ~coinbase_receiver
    ~to_user_command:(Fn.compose User_command.forget_check With_status.data)
    ~coinbase_amount:
      (Staged_ledger_diff.With_valid_signatures.coinbase ~constraint_constants
         ~supercharge_coinbase t )

let get_transactions_stable ~constraint_constants ~coinbase_receiver
    ~supercharge_coinbase ({ diff } : Staged_ledger_diff.Stable.Latest.t) =
  let open Result.Let_syntax in
  let open Transaction_data_getter_stable in
  let%map transactions, _, _, _ =
    get_impl ~get_transaction_data ~total_fee_remainder ~constraint_constants
      ~to_user_command:With_status.data ~diff ~coinbase_receiver
      ~coinbase_amount:
        (Staged_ledger_diff.Diff.Stable.Latest.coinbase ~constraint_constants
           ~supercharge_coinbase diff )
  in
  transactions

let get_transactions ~constraint_constants ~coinbase_receiver
    ~supercharge_coinbase ({ diff } : Staged_ledger_diff.t) =
  let open Result.Let_syntax in
  let open Transaction_data_getter_unchecked in
  let%map transactions, _, _, _ =
    get_impl ~get_transaction_data ~total_fee_remainder ~constraint_constants
      ~to_user_command:With_status.data ~diff ~coinbase_receiver
      ~coinbase_amount:
        (Staged_ledger_diff.Diff.coinbase ~constraint_constants
           ~supercharge_coinbase diff )
  in
  transactions
