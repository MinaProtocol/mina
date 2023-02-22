open Core
open Mina_base
open Mina_numbers
open Mina_transaction_logic
open Currency
open Signature_lib
module Ledger = Mina_ledger.Ledger.Ledger_inner

module Test_account = struct
  type t =
    { pk : Public_key.Compressed.t
    ; sk : Private_key.t
    ; nonce : Account_nonce.t
    }

  let to_keypair { pk; sk; _ } = (pk, sk)

  let make ?nonce pk sk =
    { pk = Public_key.Compressed.of_base58_check_exn pk
    ; sk = Private_key.of_base58_check_exn sk
    ; nonce =
        Option.value_map ~f:Account_nonce.of_int ~default:Account_nonce.zero
          nonce
    }
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

let alice =
  Test_account.make "B62qoFwCfztCrpPF6RENap3izXZ5rawhhrgw6ebFfCiDNfPdoRSvrxG"
    "EKEbiLkgvBrJBpfu9UuGXtgRj2KJXAjnFoMD5M7wnrQnVsHvhTjY"

let bob =
  Test_account.make "B62qq5YioU3zPgdob8WAiKo7niwbHM24dmAkfT6LJQcbAPjZZaRDjZ6"
    "EKED5bxVo9nWnLuQA22kkQf3Qw4XUgyZZNXQFpa33XExs3yUwUeA"

let keymap : Private_key.t Public_key.Compressed.Map.t =
  Public_key.Compressed.Map.of_alist_exn
  @@ List.map ~f:Test_account.to_keypair [ alice; bob ]

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

let test_ledger accounts =
  let open Result.Let_syntax in
  let ledger = Ledger.empty ~depth:3 () in
  let%map () =
    iter_result accounts ~f:(fun (public_key, balance) ->
        let acc_id = Account_id.create public_key Token_id.default in
        let account = Account.initialize acc_id in
        Ledger.create_new_account ledger acc_id { account with balance } )
  in
  ledger

type transaction =
  { sender : Public_key.Compressed.t
  ; receiver : Public_key.Compressed.t
  ; amount : Amount.t
  }

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

let update_body ~auth_kind ~account amount =
  let open Monad_lib.State.Let_syntax in
  let open Account_update in
  let%map nonce = get_nonce_exn account in
  Body.
    { dummy with
      public_key = account
    ; update = Account_update.Update.noop
    ; token_id = Token_id.default
    ; balance_change = amount
    ; increment_nonce = true
    ; implicit_account_creation_fee = true
    ; may_use_token = No
    ; authorization_kind = auth_kind
    ; preconditions =
        { network = Zkapp_precondition.Protocol_state.accept
        ; account = Account_precondition.Nonce nonce
        ; valid_while = Ignore
        }
    }

let mk_txn ~auth:(auth_kind, auth) (t : transaction) =
  let open Monad_lib.State.Let_syntax in
  let open With_stack_hash in
  let open Zkapp_command.Call_forest.Tree in
  let%bind sender_decrease_body =
    update_body ~auth_kind ~account:t.sender
      Amount.Signed.(negate @@ of_unsigned t.amount)
  in
  let sender_decrease =
    Account_update.{ body = sender_decrease_body; authorization = auth }
  in
  let%bind receiver_increase_body =
    update_body ~auth_kind ~account:t.receiver
      Amount.Signed.(of_unsigned t.amount)
  in
  let receiver_increase =
    Account_update.{ body = receiver_increase_body; authorization = auth }
  in
  return
    [ { elt =
          { account_update = sender_decrease
          ; account_update_digest =
              Zkapp_command.Call_forest.Digest.Account_update.create
                sender_decrease
          ; calls = []
          }
      ; stack_hash = Zkapp_command.Call_forest.Digest.Forest.empty
      }
    ; { elt =
          { account_update = receiver_increase
          ; account_update_digest =
              Zkapp_command.Call_forest.Digest.Account_update.create
                receiver_increase
          ; calls = []
          }
      ; stack_hash = Zkapp_command.Call_forest.Digest.Forest.empty
      }
    ]

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
  let auth =
    ( Account_update.Authorization_kind.Signature
    , Control.Signature Signature.dummy )
  in
  let%map updates = State.concat_map_m ~f:(mk_txn ~auth) transactions in
  Zkapp_command.
    { fee_payer = { body; authorization = Signature.dummy }
    ; account_updates = updates
    ; memo = Signed_command_memo.dummy
    }

let zkapp_cmd ~noncemap ~fee transactions =
  Monad_lib.State.eval_state (build_zkapp_cmd ~fee transactions) noncemap
