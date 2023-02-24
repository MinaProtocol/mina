open Core
open Mina_base
open Mina_numbers
open Mina_transaction_logic
open Currency
open Signature_lib
open Zkapp_command
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
