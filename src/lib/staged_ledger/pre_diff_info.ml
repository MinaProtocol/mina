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
         * Currency.Amount.t list
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
  ; coinbases : Currency.Amount.t list
  }

(*A Coinbase is a single transaction that accommodates the coinbase amount
    and a fee transfer for the work required to add the coinbase. It also
    contains the state body hash corresponding to a particular protocol state.
    Unlike a transaction, a coinbase (including the fee transfer) just requires one slot
    in the jobs queue.

    The minimum number of slots required to add a single transaction is three (at
    worst case number of provers: when each pair of proofs is from a different
    prover). One slot for the transaction and two slots for fee transfers.

    When the diff is split into two prediffs (why? refer to #687) and if after
    adding transactions, the first prediff has two slots remaining which cannot
    not accommodate transactions, then those slots are filled by splitting the
    coinbase into two parts.

    If it has one slot, then we simply add one coinbase. It is also possible that
    the first prediff may have no slots left after adding transactions (for
    example, when there are three slots and maximum number of provers), in which case,
    we simply add one coinbase as part of the second prediff.
*)
let create_coinbase
    ~(constraint_constants : Genesis_constants.Constraint_constants.t)
    coinbase_parts ~(receiver : Public_key.Compressed.t) ~coinbase_amount =
  let open Result.Let_syntax in
  let coinbase_or_error = function
    | Ok x ->
        Ok x
    | Error e ->
        Error (Error.Coinbase_error (Core.Error.to_string_hum e))
  in
  let underflow_err a1 a2 =
    Option.value_map
      ~default:
        (Error
           (Error.Coinbase_error
              (sprintf
                 !"underflow when splitting coinbase: Minuend: %{sexp: \
                   Currency.Amount.t} Subtrahend: %{sexp: Currency.Amount.t} \n"
                 a1 a2 ) ) )
      (Currency.Amount.sub a1 a2)
      ~f:(fun x -> Ok x)
  in
  let two_parts amt ft1 (ft2 : Coinbase.Fee_transfer.t option) =
    let%bind rem_coinbase = underflow_err coinbase_amount amt in
    let%bind _ =
      underflow_err rem_coinbase
        (Option.value_map ~default:Currency.Amount.zero ft2
           ~f:(fun { fee; _ } -> Currency.Amount.of_fee fee) )
    in
    let%bind cb1 =
      coinbase_or_error
        (Coinbase.create ~amount:amt ~receiver ~fee_transfer:ft1)
    in
    let%map cb2 =
      Coinbase.create ~amount:rem_coinbase ~receiver ~fee_transfer:ft2
      |> coinbase_or_error
    in
    [ cb1; cb2 ]
  in
  match coinbase_parts with
  | `Zero ->
      return []
  | `One x ->
      let%map cb =
        Coinbase.create ~amount:coinbase_amount ~receiver ~fee_transfer:x
        |> coinbase_or_error
      in
      [ cb ]
  | `Two None ->
      two_parts
        (Currency.Amount.of_fee constraint_constants.account_creation_fee)
        None None
  | `Two (Some (({ Coinbase.Fee_transfer.fee; _ } as ft1), ft2)) ->
      let%bind amount =
        let%map fee =
          Currency.Fee.add constraint_constants.account_creation_fee fee
          |> Option.value_map
               ~default:
                 (Error
                    (Error.Coinbase_error
                       (sprintf
                          !"Overflow when trying to add account_creation_fee \
                            %{sexp: Currency.Fee.t} to a fee transfer %{sexp: \
                            Currency.Fee.t}"
                          constraint_constants.account_creation_fee fee ) ) )
               ~f:(fun v -> Ok v)
        in
        Currency.Amount.of_fee fee
      in
      two_parts amount (Some ft1) ft2

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
    ; coinbases : Coinbase.t list
    ; fee_transfers : Fee_transfer.t list
    }
end

module Transaction_data_getter (T : Transaction_snark_work.S) = struct
  let create_fee_transfers completed_works delta public_key coinbase_fts =
    let open Result.Let_syntax in
    let singles =
      (if Currency.Fee.(equal zero delta) then [] else [ (public_key, delta) ])
      @ List.filter_map completed_works ~f:(fun w ->
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
            match Public_key.Compressed.Map.find accum receiver_pk with
            | None ->
                accum
            | Some fee ->
                let new_fee = Option.value_exn (Currency.Fee.sub fee cb_fee) in
                if Currency.Fee.(new_fee > Currency.Fee.zero) then
                  Public_key.Compressed.Map.update accum receiver_pk
                    ~f:(fun _ -> new_fee)
                else Public_key.Compressed.Map.remove accum receiver_pk )
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

  let get_transaction_data (type update a b c) ~constraint_constants
      coinbase_parts ~receiver ~coinbase_amount
      ~(to_user_command : c -> (update, a, b) User_command.with_forest)
      (commands : c list) (completed_works : T.t list) :
      (c Transaction_data.t, Error.t) Result.t =
    let open Result.Let_syntax in
    let%bind coinbases =
      O1trace.sync_thread "create_coinbase" (fun () ->
          create_coinbase ~constraint_constants coinbase_parts ~receiver
            ~coinbase_amount )
    in
    let coinbase_fts =
      List.concat_map coinbases ~f:(fun cb -> Option.to_list cb.fee_transfer)
    in
    let coinbase_work_fees =
      sum_fees ~f:Coinbase.Fee_transfer.fee coinbase_fts |> Or_error.ok_exn
    in
    let txn_works_others =
      List.filter completed_works ~f:(fun w ->
          not (Public_key.Compressed.equal receiver (T.prover w)) )
    in
    let%bind delta =
      fee_remainder commands txn_works_others coinbase_work_fees
        ~to_user_command
    in
    let%map fee_transfers =
      create_fee_transfers txn_works_others delta receiver coinbase_fts
    in
    { Transaction_data.commands; coinbases; fee_transfers }
end

module Transaction_data_getter_unchecked =
  Transaction_data_getter (Transaction_snark_work)
module Transaction_data_getter_checked =
  Transaction_data_getter (Transaction_snark_work.Checked)
module Transaction_data_getter_stable =
  Transaction_data_getter (Transaction_snark_work.Stable.Latest)

let get_individual_info (type c)
    ~(get_transaction_data :
          constraint_constants:Genesis_constants.Constraint_constants.t
       -> [< `One of Coinbase_fee_transfer.t option
          | `Two of
            (Coinbase_fee_transfer.t * Coinbase_fee_transfer.t option) option
          | `Zero ]
       -> receiver:Public_key.Compressed.t
       -> coinbase_amount:Currency.Amount.t
       -> to_user_command:(c With_status.t -> (_, _, _) User_command.with_forest)
       -> c With_status.t list
       -> 'work list
       -> (c With_status.t Transaction_data.t, Error.t) result )
    ~constraint_constants coinbase_parts ~receiver ~coinbase_amount
    (commands : c With_status.t list) completed_works ~internal_command_statuses
    ~to_user_command =
  let open Result.Let_syntax in
  let%bind { Transaction_data.commands
           ; coinbases = coinbase_parts
           ; fee_transfers
           } =
    get_transaction_data ~constraint_constants coinbase_parts ~receiver
      ~coinbase_amount commands completed_works ~to_user_command
  in
  let internal_commands =
    List.map coinbase_parts ~f:(fun t -> Transaction.Coinbase t)
    @ List.map fee_transfers ~f:(fun t -> Transaction.Fee_transfer t)
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
  ; coinbases =
      List.map coinbase_parts ~f:(fun Coinbase.{ amount; _ } -> amount)
  }

let check_coinbase
    (diff :
      _ Staged_ledger_diff.Pre_diff_two.t
      * _ Staged_ledger_diff.Pre_diff_one.t option ) =
  match
    ( (fst diff).coinbase
    , Option.value_map ~default:Staged_ledger_diff.At_most_one.Zero (snd diff)
        ~f:(fun d -> d.coinbase) )
  with
  | Zero, Zero | Zero, One _ | One _, Zero | Two _, Zero ->
      Ok ()
  | x, y ->
      Error
        (Error.Coinbase_error
           (sprintf
              !"Invalid coinbase value in staged ledger prediffs \
                %{sexp:Coinbase.Fee_transfer.t \
                Staged_ledger_diff.At_most_two.t} and \
                %{sexp:Coinbase.Fee_transfer.t \
                Staged_ledger_diff.At_most_one.t}"
              x y ) )

let compute_statuses
    ~(constraint_constants : Genesis_constants.Constraint_constants.t) ~diff
    ~coinbase_receiver ~coinbase_amount ~global_slot ~txn_state_view ~ledger :
    (Staged_ledger_diff.With_valid_signatures_and_proofs.diff, _) result =
  let open Result.Let_syntax in
  (* project transactions into a sequence of transactions *)
  let project_transactions ~coinbase_parts ~commands ~completed_works =
    let%map { Transaction_data.commands; coinbases; fee_transfers } =
      Transaction_data_getter_checked.get_transaction_data ~constraint_constants
        coinbase_parts ~receiver:coinbase_receiver ~coinbase_amount commands
        (completed_works : Transaction_snark_work.Checked.t list)
        ~to_user_command:User_command.forget_check
    in
    List.map commands ~f:(fun t ->
        Transaction.Command (User_command.forget_check t) )
    @ List.map coinbases ~f:(fun t -> Transaction.Coinbase t)
    @ List.map fee_transfers ~f:(fun t -> Transaction.Fee_transfer t)
  in
  let project_transactions_pre_diff_two
      (p :
        (Transaction_snark_work.Checked.t, _) Staged_ledger_diff.Pre_diff_two.t
        ) =
    let coinbase_parts =
      match p.coinbase with Zero -> `Zero | One x -> `One x | Two x -> `Two x
    in
    project_transactions ~coinbase_parts ~commands:p.commands
      ~completed_works:p.completed_works
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
  in
  (* partition a sequence of transactions with statuses into user commands with statuses and internal command statuses *)
  let split_transaction_statuses txns_with_statuses =
    List.partition_map txns_with_statuses ~f:(fun txn_applied ->
        let { With_status.data = txn; status } =
          Mina_ledger.Ledger.transaction_of_applied txn_applied
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
  let p1, p2 = diff in
  let%bind num_p1_txns, txns =
    let%map p1_txns = project_transactions_pre_diff_two p1
    and p2_txns =
      Option.value_map ~f:project_transactions_pre_diff_one ~default:(Ok []) p2
    in
    (List.length p1_txns, p1_txns @ p2_txns)
  in
  let%map txns_with_statuses =
    Transaction_snark.Transaction_validator.apply_transactions
      ~constraint_constants ~global_slot ~txn_state_view ledger txns
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

let get_impl (type c) ~get_transaction_data
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
  let apply_pre_diff_with_at_most_two (t1 : _ Staged_ledger_diff.Pre_diff_two.t)
      =
    let coinbase_parts =
      match t1.coinbase with Zero -> `Zero | One x -> `One x | Two x -> `Two x
    in
    get_individual_info ~get_transaction_data coinbase_parts
      ~receiver:coinbase_receiver t1.commands t1.completed_works
      ~coinbase_amount ~internal_command_statuses:t1.internal_command_statuses
      ~to_user_command
  in
  let apply_pre_diff_with_at_most_one (t2 : _ Staged_ledger_diff.Pre_diff_one.t)
      =
    let coinbase_added =
      match t2.coinbase with Zero -> `Zero | One x -> `One x
    in
    get_individual_info ~get_transaction_data coinbase_added
      ~receiver:coinbase_receiver t2.commands t2.completed_works
      ~coinbase_amount ~internal_command_statuses:t2.internal_command_statuses
      ~to_user_command
  in
  let%bind () = check_coinbase diff in
  let%bind p1 =
    apply_pre_diff_with_at_most_two ~constraint_constants (fst diff)
  in
  let%map p2 =
    Option.value_map
      ~f:(fun d -> apply_pre_diff_with_at_most_one ~constraint_constants d)
      (snd diff)
      ~default:
        (Ok { transactions = []; work = []; commands_count = 0; coinbases = [] })
  in
  ( p1.transactions @ p2.transactions
  , p1.work @ p2.work
  , p1.commands_count + p2.commands_count
  , p1.coinbases @ p2.coinbases )

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
      get_impl ~get_transaction_data ~constraint_constants
        ~to_user_command:(Fn.compose User_command.forget_check With_status.data)
        ~diff:diff.diff ~coinbase_receiver
        ~coinbase_amount:
          (Staged_ledger_diff.With_valid_signatures.coinbase
             ~constraint_constants ~supercharge_coinbase diff )

let get_unchecked ~constraint_constants ~coinbase_receiver ~supercharge_coinbase
    (t : Staged_ledger_diff.With_valid_signatures_and_proofs.t) =
  let t = Staged_ledger_diff.forget_proof_checks t in
  let open Transaction_data_getter_unchecked in
  get_impl ~get_transaction_data ~constraint_constants ~diff:t.diff
    ~coinbase_receiver
    ~to_user_command:(Fn.compose User_command.forget_check With_status.data)
    ~coinbase_amount:
      (Staged_ledger_diff.With_valid_signatures.coinbase ~constraint_constants
         ~supercharge_coinbase t )

let get_transactions_stable ~constraint_constants ~coinbase_receiver
    ~supercharge_coinbase ({ diff } : Staged_ledger_diff.Stable.Latest.t) =
  let open Result.Let_syntax in
  let open Transaction_data_getter_stable in
  let%map transactions, _, _, _ =
    get_impl ~get_transaction_data ~constraint_constants
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
    get_impl ~get_transaction_data ~constraint_constants
      ~to_user_command:With_status.data ~diff ~coinbase_receiver
      ~coinbase_amount:
        (Staged_ledger_diff.Diff.coinbase ~constraint_constants
           ~supercharge_coinbase diff )
  in
  transactions
