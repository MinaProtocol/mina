open! Core_kernel
open Currency
open Mina_base
open Mina_numbers
open Signature_lib
open Zkapp_command

type nonces = Account_nonce.t Public_key.Compressed.Map.t

type account_update =
  ( (Account_update.t, Digest.Account_update.t, Digest.Forest.t) Call_forest.tree
  , Digest.Forest.t )
  With_stack_hash.t

type transaction = < updates : (account_update list, nonces) Monad_lib.State.t >

let dummy_auth = Control.Signature Signature.dummy

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

let update_body ?preconditions ?(update = Account_update.Update.noop) ~account amount =
  let open Monad_lib.State.Let_syntax in
  let open Account_update in
  let%map default =
    let%map nonce = get_nonce_exn account in
    Account_update.Preconditions.
    { network = Zkapp_precondition.Protocol_state.accept
    ; account = Account_precondition.Nonce nonce
    ; valid_while = Ignore
    }
  in
  let update_preconditions = Option.value ~default preconditions in
  let account_update = update in
  Body.
    { dummy with
      public_key = account
    ; update = account_update
    ; token_id = Token_id.default
    ; balance_change = amount
    ; increment_nonce = true
    ; implicit_account_creation_fee = true
    ; may_use_token = No
    ; authorization_kind = Signature
    ; use_full_commitment = true
    ; preconditions = update_preconditions
    }

let update ?(calls = []) body =
  let open With_stack_hash in
  let open Zkapp_command.Call_forest.Tree in
  { elt =
      { account_update = body
      ; account_update_digest =
          Zkapp_command.Call_forest.Digest.Account_update.create body
      ; calls
      }
  ; stack_hash = Zkapp_command.Call_forest.Digest.Forest.empty
  }

let gen_balance_split ?limit balance =
  let open Quickcheck.Generator.Let_syntax in
  let rec generate ?limit acc remaining =
    if Amount.(equal remaining zero) then return acc
    else if Option.value_map ~default:false ~f:(Int.( <= ) 1) limit then
      return (remaining :: acc)
    else
      let%bind amt = Amount.(gen_incl (of_nanomina_int_exn 1) remaining) in
      generate
        ?limit:(Option.map ~f:Int.pred limit)
        (amt :: acc)
        Amount.(Option.value ~default:zero (remaining - amt))
  in
  generate ?limit [] (Balance.to_amount balance)

module Simple_txn = struct
  let make ?preconditions ~sender ~receiver amount =
    object
      method sender : Public_key.Compressed.t = sender

      method receiver : Public_key.Compressed.t = receiver

      method amount : Amount.t = amount

      method updates : (account_update list, nonces) Monad_lib.State.t =
        let open Monad_lib.State.Let_syntax in
        let%bind sender_decrease_body =
          update_body ?preconditions ~account:sender
            Amount.Signed.(negate @@ of_unsigned amount)
        in
        let%map receiver_increase_body =
          update_body ?preconditions ~account:receiver Amount.Signed.(of_unsigned amount)
        in
        [ update
            Account_update.
              { body = sender_decrease_body; authorization = dummy_auth }
        ; update
            Account_update.
              { body = receiver_increase_body; authorization = dummy_auth }
        ]
    end

  let gen known_accounts =
    let open Quickcheck in
    let open Generator.Let_syntax in
    let make_txn = make in
    let open Test_account in
    let eligible_senders = List.filter ~f:non_empty known_accounts in
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
    make_txn ~sender:sender.pk ~receiver:receiver.pk amount

  let gen_account_pair_and_txn =
    let open Quickcheck in
    let open Generator.Let_syntax in
    let%bind sender =
      Generator.filter ~f:Test_account.non_empty Test_account.gen
    in
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
    let txn = make ~sender:sender.pk ~receiver:receiver.pk amount in
    ((sender, receiver), txn)
end

module Single = struct
  let make ~account amount =
    object
      method account : Public_key.Compressed.t = account

      method amount : Amount.Signed.t = amount

      method updates =
        let open Monad_lib.State.Let_syntax in
        let open Account_update in
        let%map body = update_body ~account amount in
        [ update { body; authorization = dummy_auth } ]
    end
end

module Alter_account = struct
  let make ~account ?(amount = Amount.Signed.zero) state_update =
    object
      method account : Public_key.Compressed.t = account

      method amount : Amount.Signed.t = amount

      method update : Account_update.Update.t = state_update

      method updates =
        let open Monad_lib.State.Let_syntax in
        let open Account_update in
        let%map body = update_body ~update:state_update ~account amount in
        [ update { body; authorization = dummy_auth } ]
    end
end

module Txn_tree = struct
  let make ~account ?(amount = Amount.Signed.zero) ?(children = []) state_update
      =
    object
      method account : Public_key.Compressed.t = account

      method amount : Amount.Signed.t = amount

      method update : Account_update.Update.t = state_update

      method children : transaction list = children

      method updates =
        let open Monad_lib.State.Let_syntax in
        let open Account_update in
        let module State_ext = Monad_lib.Make_ext2 (Monad_lib.State) in
        let%bind body = update_body ~update:state_update ~account amount in
        let%map calls =
          State_ext.concat_map_m children ~f:(fun c -> c#updates)
        in
        [ update ~calls { body; authorization = dummy_auth } ]
    end
end

let mk_updates (t : transaction) = t#updates

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
