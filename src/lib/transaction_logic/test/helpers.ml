open Core
open Mina_base
open Mina_numbers
open Mina_transaction_logic
open Currency
open Signature_lib

module Ledger = Mina_ledger.Ledger.Ledger_inner

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

let alice = Public_key.Compressed.of_base58_check_exn
              "B62qoFwCfztCrpPF6RENap3izXZ5rawhhrgw6ebFfCiDNfPdoRSvrxG"

let bob = Public_key.Compressed.of_base58_check_exn
            "B62qq5YioU3zPgdob8WAiKo7niwbHM24dmAkfT6LJQcbAPjZZaRDjZ6"

let rec iter_result ~f = function
  | [] -> Result.return ()
  | (x :: xs) ->
     let open Result.Let_syntax in
     let%bind () = f x in
     iter_result ~f xs

let test_ledger accounts =
  let open Result.Let_syntax in
  let ledger = Ledger.empty ~depth:3 () in
  let%map () = iter_result accounts ~f:(fun (public_key, balance) ->
                   let acc_id = Account_id.create public_key Token_id.default in
                   let account = Account.initialize acc_id in
                   Ledger.create_new_account ledger acc_id { account with balance })
  in
  ledger

type transaction = { sender : Public_key.Compressed.t
                   ; receiver : Public_key.Compressed.t
                   ; amount : Amount.t }

let update_body ~account amount =
  Account_update.Body.
    { dummy with
      public_key = account
    ; update = Account_update.Update.noop
    ; token_id = Token_id.default
    ; balance_change = amount
    ; increment_nonce = false
    ; implicit_account_creation_fee = true
    ; may_use_token = No
    ; authorization_kind = None_given
    }

let mk_txn (t : transaction) : (Account_update.t, Zkapp_command.Digest.Account_update.t,
                                Zkapp_command.Digest.Forest.t)
                                 Zkapp_command.Call_forest.t =
  let sender_decrease =
    Account_update.{ body = update_body ~account:t.sender Amount.Signed.(negate @@ of_unsigned t.amount)
                   ; authorization = None_given  }
  in
  let receiver_increase =
    Account_update.{ body = update_body ~account:t.receiver Amount.Signed.(of_unsigned t.amount)
                   ; authorization = None_given }
  in
  [
    { elt =
        { account_update = sender_decrease
        ; account_update_digest =
            Zkapp_command.Call_forest.Digest.Account_update.create
              sender_decrease
        ; calls = []
        }
    ; stack_hash = Zkapp_command.Call_forest.Digest.Forest.empty
    };
    { elt =
        { account_update = receiver_increase
        ; account_update_digest =
            Zkapp_command.Call_forest.Digest.Account_update.create
              receiver_increase
        ; calls = []
        }
    ; stack_hash = Zkapp_command.Call_forest.Digest.Forest.empty
    };
  ]

let fee_payer_body (account, amount) =
  Account_update.Body.Fee_payer.
    { public_key = account
    ; fee = amount
    ; valid_until = None
    ; nonce = Account_nonce.zero
    }

let zkapp_cmd ~fee transactions : Zkapp_command.t =
  { fee_payer = { body = fee_payer_body fee; authorization = Signature.dummy }
  ; account_updates = List.concat_map ~f:mk_txn transactions
  ; memo = Signed_command_memo.dummy
  }
