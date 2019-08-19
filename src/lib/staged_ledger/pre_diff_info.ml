open Core
open Coda_base
open Signature_lib

module Make (Inputs : Coda_intf.Tmp_test_stub_hack.For_staged_ledger_intf) : sig
  open Inputs

  include
    Coda_intf.Staged_ledger_pre_diff_info_generalized_intf
    with type transaction_snark_work := Transaction_snark_work.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type valid_staged_ledger_diff :=
                Staged_ledger_diff.With_valid_signatures_and_proofs.t
end = struct
  open Inputs

  module Error = struct
    type t =
      | Bad_signature of User_command.t
      | Coinbase_error of string
      | Insufficient_fee of Currency.Fee.t * Currency.Fee.t
      | Unexpected of Error.t
    [@@deriving sexp]

    let to_string = function
      | Bad_signature t ->
          Format.asprintf
            !"Bad signature of the user command: %{sexp: Sexp.t} \n"
            (User_command.sexp_of_t t)
      | Coinbase_error err ->
          Format.asprintf !"Coinbase error: %s \n" err
      | Insufficient_fee (f1, f2) ->
          Format.asprintf
            !"Transaction fees %{sexp: Currency.Fee.t} does not suffice proof \
              fees %{sexp: Currency.Fee.t} \n"
            f1 f2
      | Unexpected e ->
          Error.to_string_hum e

    let to_error = Fn.compose Error.of_string to_string
  end

  type t =
    { transactions: Transaction.t list
    ; work: Transaction_snark_work.t list
    ; user_commands_count: int
    ; coinbases: Coinbase.t list }

  (* A Coinbase is a single transaction that accommodates the coinbase amount
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
  let create_coinbase coinbase_parts (proposer : Public_key.Compressed.t)
      (state_body_hash : State_body_hash.t) =
    let open Result.Let_syntax in
    let coinbase = Coda_compile_config.coinbase in
    let coinbase_or_error = function
      | Ok x ->
          Ok x
      | Error e ->
          Error (Error.Coinbase_error (Core.Error.to_string_hum e))
    in
    let overflow_err a1 a2 =
      Option.value_map
        ~default:
          (Error
             (Error.Coinbase_error
                (sprintf
                   !"Overflow when splitting coinbase: Minuend: %{sexp: \
                     Currency.Amount.t} Subtrahend: %{sexp: Currency.Amount.t}"
                   a1 a2)))
        (Currency.Amount.sub a1 a2)
        ~f:(fun x -> Ok x)
    in
    let two_parts amt (ft1 : Fee_transfer.Single.t option) ft2 =
      let%bind rem_coinbase = overflow_err coinbase amt in
      let%bind _ =
        overflow_err rem_coinbase
          (Option.value_map ~default:Currency.Amount.zero ft2 ~f:(fun single ->
               Currency.Amount.of_fee (snd single) ))
      in
      let%bind cb1 =
        coinbase_or_error
          (Coinbase.create ~amount:amt ~proposer ~fee_transfer:ft1
             ~state_body_hash)
      in
      let%map cb2 =
        Coinbase.create ~amount:rem_coinbase ~proposer ~fee_transfer:ft2
          ~state_body_hash
        |> coinbase_or_error
      in
      [cb1; cb2]
    in
    match coinbase_parts with
    | `Zero ->
        return []
    | `One x ->
        let%map cb =
          Coinbase.create ~amount:coinbase ~proposer ~fee_transfer:x
            ~state_body_hash
          |> coinbase_or_error
        in
        [cb]
    | `Two None ->
        two_parts (Currency.Amount.of_int 1) None None
    | `Two (Some (ft1, ft2)) ->
        two_parts (Currency.Amount.of_fee (snd ft1)) (Some ft1) ft2

  let sum_fees xs ~f =
    with_return (fun {return} ->
        Ok
          (List.fold ~init:Currency.Fee.zero xs ~f:(fun acc x ->
               match Currency.Fee.add acc (f x) with
               | None ->
                   return (Or_error.error_string "Fee overflow")
               | Some res ->
                   res )) )

  let to_staged_ledger_or_error =
    Result.map_error ~f:(fun error -> Error.Unexpected error)

  let fee_remainder (user_commands : User_command.With_valid_signature.t list)
      completed_works coinbase_fee =
    let open Result.Let_syntax in
    let%bind budget =
      sum_fees user_commands ~f:(fun t -> User_command.fee (t :> User_command.t)
      )
      |> to_staged_ledger_or_error
    in
    let%bind work_fee =
      sum_fees completed_works ~f:(fun {Transaction_snark_work.fee; _} -> fee)
      |> to_staged_ledger_or_error
    in
    let total_work_fee =
      Option.value ~default:Currency.Fee.zero
        (Currency.Fee.sub work_fee coinbase_fee)
    in
    Option.value_map
      ~default:(Error (Error.Insufficient_fee (budget, total_work_fee)))
      ~f:(fun x -> Ok x)
      (Currency.Fee.sub budget total_work_fee)

  let create_fee_transfers completed_works delta public_key coinbase_fts =
    let open Result.Let_syntax in
    let singles =
      (if Currency.Fee.(equal zero delta) then [] else [(public_key, delta)])
      @ List.filter_map completed_works
          ~f:(fun {Transaction_snark_work.fee; prover; _} ->
            if Currency.Fee.equal fee Currency.Fee.zero then None
            else Some (prover, fee) )
    in
    let%bind singles_map =
      Or_error.try_with (fun () ->
          Public_key.Compressed.Map.of_alist_reduce singles ~f:(fun f1 f2 ->
              Option.value_exn (Currency.Fee.add f1 f2) ) )
      |> to_staged_ledger_or_error
    in
    (* deduct the coinbase work fee from the singles_map. It is already part of the coinbase *)
    Or_error.try_with (fun () ->
        List.fold coinbase_fts ~init:singles_map ~f:(fun accum single ->
            match Public_key.Compressed.Map.find accum (fst single) with
            | None ->
                accum
            | Some fee ->
                let new_fee =
                  Option.value_exn (Currency.Fee.sub fee (snd single))
                in
                if new_fee > Currency.Fee.zero then
                  Public_key.Compressed.Map.update accum (fst single)
                    ~f:(fun _ -> new_fee)
                else Public_key.Compressed.Map.remove accum (fst single) )
        (* TODO: This creates a weird incentive to have a small public_key *)
        |> Map.to_alist ~key_order:`Increasing
        |> Fee_transfer.of_single_list )
    |> to_staged_ledger_or_error

  let get_individual_info coinbase_parts (proposer : Public_key.Compressed.t)
      user_commands completed_works state_body_hash =
    let open Result.Let_syntax in
    let%map user_commands, coinbase, transactions =
      let open Result.Let_syntax in
      let%bind user_commands =
        let%map user_commands' =
          List.fold_until user_commands ~init:[]
            ~f:(fun acc t ->
              match User_command.check t with
              | Some t ->
                  Continue (t :: acc)
              | None ->
                  Stop (Error (Error.Bad_signature t)) )
            ~finish:(fun acc -> Ok acc)
        in
        List.rev user_commands'
      in
      let%bind coinbase =
        create_coinbase coinbase_parts proposer state_body_hash
      in
      let coinbase_fts =
        List.concat_map coinbase ~f:(fun cb ->
            Option.value_map cb.fee_transfer ~default:[] ~f:(fun ft -> [ft]) )
      in
      let%bind coinbase_work_fees =
        sum_fees coinbase_fts ~f:snd |> to_staged_ledger_or_error
      in
      let completed_works_others =
        List.filter completed_works
          ~f:(fun {Transaction_snark_work.prover; _} ->
            not (Public_key.Compressed.equal proposer prover) )
      in
      let%bind delta =
        fee_remainder user_commands completed_works_others coinbase_work_fees
      in
      let%map fee_transfers =
        create_fee_transfers completed_works_others delta proposer
          (coinbase_fts : Fee_transfer.Single.t list)
      in
      let transactions =
        List.map user_commands ~f:(fun t -> Transaction.User_command t)
        @ List.map coinbase ~f:(fun t -> Transaction.Coinbase t)
        @ List.map fee_transfers ~f:(fun t -> Transaction.Fee_transfer t)
      in
      (user_commands, coinbase, transactions)
    in
    { transactions
    ; work= completed_works
    ; user_commands_count= List.length user_commands
    ; coinbases= coinbase }

  open Staged_ledger_diff

  let get t =
    let apply_pre_diff_with_at_most_two
        (t1 : Pre_diff_with_at_most_two_coinbase.t) =
      let coinbase_parts =
        match t1.coinbase with
        | Zero ->
            `Zero
        | One x ->
            `One x
        | Two x ->
            `Two x
      in
      get_individual_info coinbase_parts t.creator t1.user_commands
        t1.completed_works t.state_body_hash
    in
    let apply_pre_diff_with_at_most_one
        (t2 : Pre_diff_with_at_most_one_coinbase.t) =
      let coinbase_added =
        match t2.coinbase with Zero -> `Zero | One x -> `One x
      in
      get_individual_info coinbase_added t.creator t2.user_commands
        t2.completed_works t.state_body_hash
    in
    let open Result.Let_syntax in
    let%bind p1 = apply_pre_diff_with_at_most_two (fst t.diff) in
    let%map p2 =
      Option.value_map
        ~f:(fun d -> apply_pre_diff_with_at_most_one d)
        (snd t.diff)
        ~default:
          (Ok
             {transactions= []; work= []; user_commands_count= 0; coinbases= []})
    in
    ( p1.transactions @ p2.transactions
    , p1.work @ p2.work
    , p1.user_commands_count + p2.user_commands_count
    , List.map (p1.coinbases @ p2.coinbases) ~f:(fun Coinbase.{amount; _} ->
          amount ) )

  let ok_exn' (t : ('a, Error.t) Result.t) =
    match t with Ok x -> x | Error e -> Core.Error.raise (Error.to_error e)

  let get_individual_diff_unchecked coinbase_parts proposer user_commands
      completed_works state_body_hash =
    let txn_works =
      List.map ~f:Transaction_snark_work.forget completed_works
    in
    let coinbase_parts =
      O1trace.measure "create_coinbase" (fun () ->
          ok_exn' (create_coinbase coinbase_parts proposer state_body_hash) )
    in
    let coinbase_fts =
      List.concat_map coinbase_parts ~f:(fun cb ->
          Option.value_map cb.fee_transfer ~default:[] ~f:(fun ft -> [ft]) )
    in
    let coinbase_work_fees = sum_fees coinbase_fts ~f:snd |> Or_error.ok_exn in
    let txn_works_others =
      List.filter txn_works ~f:(fun {Transaction_snark_work.prover; _} ->
          not (Public_key.Compressed.equal proposer prover) )
    in
    let delta =
      ok_exn' (fee_remainder user_commands txn_works_others coinbase_work_fees)
    in
    let fee_transfers =
      ok_exn'
        (create_fee_transfers txn_works_others delta proposer coinbase_fts)
    in
    let transactions =
      List.map user_commands ~f:(fun t -> Transaction.User_command t)
      @ List.map coinbase_parts ~f:(fun t -> Transaction.Coinbase t)
      @ List.map fee_transfers ~f:(fun t -> Transaction.Fee_transfer t)
    in
    ( transactions
    , txn_works
    , List.map coinbase_parts ~f:(fun Coinbase.{amount; _} -> amount) )

  let get_unchecked (t : With_valid_signatures_and_proofs.t) =
    let apply_pre_diff_with_at_most_two
        (pre_diff1 :
          With_valid_signatures_and_proofs.pre_diff_with_at_most_two_coinbase)
        =
      let coinbase_parts =
        match pre_diff1.coinbase with
        | Zero ->
            `Zero
        | One x ->
            `One x
        | Two x ->
            `Two x
      in
      get_individual_diff_unchecked coinbase_parts t.creator
        pre_diff1.user_commands pre_diff1.completed_works t.state_body_hash
    in
    let apply_pre_diff_with_at_most_one
        (pre_diff2 :
          With_valid_signatures_and_proofs.pre_diff_with_at_most_one_coinbase)
        =
      let coinbase_added =
        match pre_diff2.coinbase with Zero -> `Zero | One x -> `One x
      in
      get_individual_diff_unchecked coinbase_added t.creator
        pre_diff2.user_commands pre_diff2.completed_works t.state_body_hash
    in
    let data1, work1, coinbases1 =
      apply_pre_diff_with_at_most_two (fst t.diff)
    in
    let data2, work2, coinbases2 =
      Option.value_map
        ~f:(fun d -> apply_pre_diff_with_at_most_one d)
        (snd t.diff) ~default:([], [], [])
    in
    (data1 @ data2, work1 @ work2, coinbases1 @ coinbases2)

  let get_transactions (sl_diff : t) =
    let open Result.Let_syntax in
    let%map transactions, _, _, _ = get sl_diff in
    transactions
end
