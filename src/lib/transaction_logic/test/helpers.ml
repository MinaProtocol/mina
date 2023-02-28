open Core
open Mina_base
open Mina_numbers
open Mina_transaction_logic
open Currency
open Signature_lib
open Zkapp_command
module Ledger = Mina_ledger.Ledger.Ledger_inner
module Transaction_logic = Mina_transaction_logic.Make (Ledger)

module Zk_cmd_result = struct
  type t =
    Transaction_logic.Transaction_applied.Zkapp_command_applied.t * Ledger.t

  let sexp_of_t (txn, _) =
    Transaction_logic.Transaction_applied.Zkapp_command_applied.sexp_of_t txn
end

module Test_account = struct
  type t =
    { pk : Public_key.Compressed.t
    ; nonce : Account_nonce.t
    ; balance : Balance.t
    }
  [@@deriving equal]

  let make ?nonce ?(balance = Balance.zero) pk =
    { pk = Public_key.Compressed.of_base58_check_exn pk
    ; balance
    ; nonce =
        Option.value_map ~f:Account_nonce.of_int ~default:Account_nonce.zero
          nonce
    }

  let non_empty { balance; _ } = Balance.(balance > zero)

  let account_id { pk; _ } = Account_id.create pk Token_id.default

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%bind pk = Public_key.Compressed.gen in
    let%bind balance = Balance.gen in
    let%map nonce = Account_nonce.gen in
    { pk; nonce; balance }
end

let epoch_seed = Epoch_seed.of_decimal_string "500"

let epoch_data =
  Epoch_data.Poly.
    { ledger =
        Epoch_ledger.Poly.
          { hash = Frozen_ledger_hash.empty_hash
          ; total_currency = Amount.of_mina_int_exn 10_000_000
          }
    ; seed = epoch_seed
    ; start_checkpoint = State_hash.dummy
    ; lock_checkpoint = State_hash.dummy
    ; epoch_length = Length.of_int 20
    }

let protocol_state : Zkapp_precondition.Protocol_state.View.t =
  Zkapp_precondition.Protocol_state.Poly.
    { snarked_ledger_hash = Frozen_ledger_hash.empty_hash
    ; blockchain_length = Length.of_int 119
    ; min_window_density = Length.of_int 10
    ; last_vrf_output = ()
    ; total_currency = Amount.of_mina_int_exn 10
    ; global_slot_since_genesis = Global_slot.of_int 120
    ; staking_epoch_data = epoch_data
    ; next_epoch_data = epoch_data
    }

let noncemap (accounts : Test_account.t list) :
    Account_nonce.t Public_key.Compressed.Map.t =
  Public_key.Compressed.Map.of_alist_exn
  @@ List.map ~f:(fun a -> (a.pk, a.nonce)) accounts

let rec iter_result ~f = function
  | [] ->
      Result.return ()
  | x :: xs ->
      let open Result.Let_syntax in
      let%bind () = f x in
      iter_result ~f xs

let bin_log n =
  let rec find candidate =
    if Int.pow 2 candidate >= n then candidate else find (Int.succ candidate)
  in
  find 0

let test_ledger accounts =
  let open Result.Let_syntax in
  let open Test_account in
  let depth = bin_log @@ List.length accounts in
  let ledger = Ledger.empty ~depth () in
  let%map () =
    iter_result accounts ~f:(fun a ->
        let acc_id = account_id a in
        let account = Account.initialize acc_id in
        Ledger.create_new_account ledger acc_id
          { account with balance = a.balance; nonce = a.nonce } )
  in
  ledger

type nonces = Account_nonce.t Public_key.Compressed.Map.t

type account_update =
  ( (Account_update.t, Digest.Account_update.t, Digest.Forest.t) Call_forest.tree
  , Digest.Forest.t )
  With_stack_hash.t

type transaction = < updates : (account_update list, nonces) Monad_lib.State.t >

let mk_updates (t : transaction) = t#updates

let get_nonce_exn (pk : Public_key.Compressed.t) :
    ( Account_nonce.t
    , Account_nonce.t Public_key.Compressed.Map.t )
    Monad_lib.State.t =
  let open Monad_lib in
  let open State.Let_syntax in
  let%bind nonce =
    State.getf (fun m -> Public_key.Compressed.Map.find_exn m pk)
  in
  let%map () =
    State.modify ~f:(fun m ->
        Public_key.Compressed.Map.set m ~key:pk ~data:(Account_nonce.succ nonce) )
  in
  nonce

let fee_payer_body (account, amount) =
  let open Monad_lib in
  let open State.Let_syntax in
  let open Account_update.Body.Fee_payer in
  let%map nonce = get_nonce_exn account in
  { public_key = account; fee = amount; valid_until = None; nonce }

let build_zkapp_cmd ~fee transactions :
    ( Zkapp_command.t
    , Account_nonce.t Public_key.Compressed.Map.t )
    Monad_lib.State.t =
  let open Monad_lib in
  let open State.Let_syntax in
  let%bind body = fee_payer_body fee in
  let%map updates = State.concat_map_m ~f:mk_updates transactions in
  Zkapp_command.
    { fee_payer = { body; authorization = Signature.dummy }
    ; account_updates = updates
    ; memo = Signed_command_memo.dummy
    }

let zkapp_cmd ~noncemap ~fee transactions =
  Monad_lib.State.eval_state (build_zkapp_cmd ~fee transactions) noncemap

let add_to_balance balance amount =
  let open Option.Let_syntax in
  let b = Balance.to_amount balance in
  let%bind Signed_poly.{ magnitude; sgn } =
    Amount.Signed.(of_unsigned b + amount)
  in
  match sgn with
  | Pos ->
      Some (Balance.of_uint64 @@ Amount.to_uint64 magnitude)
  | Neg ->
      None

module Pred = struct
  let pure ?(with_error = Fn.const false) ~f result =
    match Result.map result ~f with Ok b -> b | Error e -> with_error e

  let result ?(with_error = Fn.const false) ~f result =
    match Result.bind result ~f with Ok b -> b | Error e -> with_error e

  let verify_account_updates ~(ledger : Ledger.t)
      ~(txn : Transaction_logic.Transaction_applied.Zkapp_command_applied.t)
      ~(f : Amount.Signed.t -> Account.t option * Account.t option -> bool)
      (account : Test_account.t) =
    let account_id = Test_account.account_id account in
    let outdated =
      List.find_map txn.accounts ~f:(fun (aid, a) ->
          if Account_id.equal aid account_id then a else None )
    in
    let updated =
      let open Option.Let_syntax in
      let%bind loc = Ledger.location_of_account ledger account_id in
      Ledger.get ledger loc
    in
    let fee =
      if
        Public_key.Compressed.equal account.pk
          txn.command.data.fee_payer.body.public_key
      then
        Signed_poly.
          { magnitude =
              Amount.of_uint64
              @@ Fee.to_uint64 txn.command.data.fee_payer.body.fee
          ; sgn = Sgn.Neg
          }
      else Amount.Signed.zero
    in
    let balance_updates =
      Call_forest.fold txn.command.data.account_updates ~init:Amount.Signed.zero
        ~f:(fun acc upd ->
          if Public_key.Compressed.equal account.pk upd.body.public_key then
            Option.value_exn @@ Amount.Signed.add acc upd.body.balance_change
          else acc )
    in
    let balance_change =
      Amount.Signed.(balance_updates + fee) |> Option.value_exn
    in
    f balance_change (outdated, updated)

  let verify_balance_change ~balance_change orig updt =
    let open Account.Poly in
    add_to_balance orig.balance balance_change
    |> Option.value_map ~default:false ~f:(Balance.equal updt.balance)

  let verify_balance_changes ~txn ~ledger accounts =
    List.for_all accounts
      ~f:
        (verify_account_updates ~txn ~ledger ~f:(fun balance_change -> function
           | Some orig, Some updt ->
               verify_balance_change ~balance_change orig updt
           | _ ->
               false ) )
end
