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
    ; balance : Balance.t
    }
  [@@deriving equal]

  let to_keypair { pk; sk; _ } = (pk, sk)

  let make ?nonce ?(balance = Balance.zero) pk sk =
    { pk = Public_key.Compressed.of_base58_check_exn pk
    ; sk = Private_key.of_base58_check_exn sk
    ; balance
    ; nonce =
        Option.value_map ~f:Account_nonce.of_int ~default:Account_nonce.zero
          nonce
    }

  let non_empty { balance; _ } = Balance.(balance > zero)

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%bind sk = Private_key.gen in
    let pk = Public_key.(compress @@ of_private_key_exn sk) in
    let%bind balance = Balance.gen in
    let%map nonce = Account_nonce.gen in
    { pk; sk; nonce; balance }
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

let keymap (accounts : Test_account.t list) :
    Private_key.t Public_key.Compressed.Map.t =
  Public_key.Compressed.Map.of_alist_exn
  @@ List.map ~f:Test_account.to_keypair accounts

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
        let acc_id = Account_id.create a.pk Token_id.default in
        let account = Account.initialize acc_id in
        Ledger.create_new_account ledger acc_id
          { account with balance = a.balance; nonce = a.nonce } )
  in
  ledger

module Test_transaction = struct
  type t =
    { sender : Public_key.Compressed.t
    ; receiver : Public_key.Compressed.t
    ; amount : Amount.t
    }

  let gen known_accounts =
    let open Quickcheck in
    let open Generator.Let_syntax in
    let open Test_account in
    let eligible_senders =
      List.filter ~f:Test_account.non_empty known_accounts
    in
    let%bind sender = Generator.of_list eligible_senders in
    let eligible_receivers =
      List.filter
        ~f:(fun a -> not Public_key.Compressed.(equal a.pk sender.pk))
        known_accounts
    in
    let%bind receiver = Generator.of_list eligible_receivers in
    let max_amt =
      let sender_balance = Balance.to_amount sender.balance in
      let receiver_capacity =
        Amount.(max_int - Balance.to_amount receiver.balance)
      in
      Amount.min sender_balance
        (Option.value ~default:sender_balance receiver_capacity)
    in
    let%map amount = Amount.(gen_incl zero max_amt) in
    { sender = sender.pk; receiver = receiver.pk; amount }
end

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

let mk_txn ~auth:(auth_kind, auth) (t : Test_transaction.t) =
  let open Monad_lib.State.Let_syntax in
  let open With_stack_hash in
  let open Zkapp_command.Call_forest.Tree in
  let open Test_transaction in
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

let gen_account_pair_and_txn =
  let open Quickcheck in
  let open Generator.Let_syntax in
  let%bind sender = Generator.filter ~f:Test_account.non_empty Test_account.gen in
  let%bind receiver = Test_account.gen in
  let max_amt =
    let sender_balance = Balance.to_amount sender.balance in
    let receiver_capacity =
      Amount.(max_int - Balance.to_amount receiver.balance)
    in
    Amount.min sender_balance
      (Option.value ~default:sender_balance receiver_capacity)
  in
  let%map amount = Amount.(gen_incl zero max_amt) in
  let txn = Test_transaction.{ sender = sender.pk; receiver = receiver.pk; amount } in
  ((sender, receiver), txn)
