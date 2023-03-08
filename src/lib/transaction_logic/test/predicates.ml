open Core
open Currency
open Mina_base
open Signature_lib
open Zkapp_command

let pure ?(with_error = Fn.const false) ~f result =
  match Result.map result ~f with Ok b -> b | Error e -> with_error e

let result ?(with_error = Fn.const false) ~f result =
  match Result.bind result ~f with Ok b -> b | Error e -> with_error e

let verify_account_updates ~(ledger : Helpers.Ledger.t)
    ~(txn :
       Helpers.Transaction_logic.Transaction_applied.Zkapp_command_applied.t )
    ~(f : Amount.Signed.t -> Account.t option * Account.t option -> bool)
    (account : Test_account.t) =
  let open Helpers in
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
