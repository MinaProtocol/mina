open Core_kernel
open Currency
open Mina_base
open Mina_base_test_helpers
open Mina_ledger_test_helpers
open Signature_lib
open Transaction_logic_tests
open Helpers
open Protocol_config_examples

let mk_command ~sender:(sender : Test_account.t) ~fee body =
  let open Mina_transaction.Transaction in
  Command
    (User_command.Signed_command
       Signed_command.Poly.
         { payload =
             Signed_command_payload.Poly.
               { body
               ; common =
                   (let open Signed_command.Payload.Common.Poly in
                   { fee
                   ; fee_payer_pk = sender.pk
                   ; nonce = sender.nonce
                   ; valid_until =
                       Mina_numbers.Global_slot_since_genesis.max_value
                   ; memo = Signed_command_memo.dummy
                   })
               }
         ; signer = Public_key.decompress_exn sender.pk
         ; signature = Signature.dummy
         } )

let delegation_command ~sender ~new_delegate ~fee =
  mk_command ~sender ~fee
    Signed_command_payload.Body.(Stake_delegation (Set_delegate { new_delegate }))

let payment_command ~sender ~receiver_pk ~amount ~fee =
  let rcv = receiver_pk in
  let amt = amount in
  mk_command ~sender ~fee
    Signed_command_payload.Body.(Payment { receiver_pk = rcv; amount = amt })

let max_test_balance = Balance.of_mina_int_exn 1_000_000

let global_slot = Mina_numbers.Global_slot_since_genesis.of_int 120

let apply_txn ledger txn =
  Transaction_logic.apply_transactions ~signature_kind ~constraint_constants
    ~global_slot ~txn_state_view:protocol_state ledger [ txn ]
  |> Or_error.ok_exn
  |> (ignore : Mina_transaction_logic.Transaction_applied.t list -> unit)

let get_account_exn ledger pk =
  let account_id = Account_id.create pk Token_id.default in
  Ledger.location_of_account ledger account_id
  |> Option.bind ~f:(Ledger.get ledger)
  |> Option.value_exn

let gen_account ?(min = Balance.of_nanomina_int_exn 1) () =
  Test_account.gen_constrained_balance () ~min ~max:max_test_balance

let gen_delegation_scenario ~num_txns =
  let open Quickcheck.Generator.Let_syntax in
  let%bind delegator = gen_account ~min:(Balance.of_mina_int_exn 1) () in
  let%bind validator = gen_account () in
  let max_fee =
    Amount.to_nanomina_int (Balance.to_amount delegator.balance)
    / (num_txns + 1)
  in
  let%map fee =
    Fee.gen_incl Fee.one (Fee.max Fee.one (Fee.of_nanomina_int_exn max_fee))
  in
  (delegator, validator, fee)

let mk_ledger accounts = Ledger_helpers.ledger_of_accounts accounts |> Or_error.ok_exn

let sender_from_ledger ledger (account : Test_account.t) =
  let acct = get_account_exn ledger account.pk in
  { account with nonce = acct.nonce; balance = acct.balance }

(* Test Case 2 (partial): new accounts start with delegate = None.
   Delegating to a real validator sets the delegate field. *)
let opt_in_from_default_unstaked () =
  Quickcheck.test ~trials:100 (gen_delegation_scenario ~num_txns:1)
    ~f:(fun (delegator, validator, fee) ->
      let ledger = mk_ledger [ delegator; validator ] in
      assert (Option.is_none (get_account_exn ledger delegator.pk).delegate) ;
      apply_txn ledger
        (delegation_command ~sender:delegator ~new_delegate:validator.pk ~fee) ;
      assert (
        Option.equal Public_key.Compressed.equal
          (get_account_exn ledger delegator.pk).delegate
          (Some validator.pk) ) )

(* Test Case 1 (partial): an account that is delegating can opt out
   by delegating to the empty public key. *)
let opt_out_via_empty_delegation () =
  Quickcheck.test ~trials:100 (gen_delegation_scenario ~num_txns:2)
    ~f:(fun (delegator, validator, fee) ->
      let ledger = mk_ledger [ delegator; validator ] in
      apply_txn ledger
        (delegation_command ~sender:delegator ~new_delegate:validator.pk ~fee) ;
      assert (
        Option.equal Public_key.Compressed.equal
          (get_account_exn ledger delegator.pk).delegate
          (Some validator.pk) ) ;
      let sender = sender_from_ledger ledger delegator in
      apply_txn ledger
        (delegation_command ~sender ~new_delegate:Public_key.Compressed.empty
           ~fee ) ;
      assert (Option.is_none (get_account_exn ledger delegator.pk).delegate) )

(* Test Case 3/4 (partial): payments to and from unstaked accounts
   succeed and balances are correct. *)
let payments_with_unstaked_accounts () =
  Quickcheck.test ~trials:100
    (let open Quickcheck.Generator.Let_syntax in
    let%bind sender = gen_account ~min:(Balance.of_nanomina_int_exn 3) () in
    let%bind receiver = gen_account () in
    let max_amount =
      Amount.min
        ( Balance.sub_amount sender.balance Amount.one
        |> Option.value_map ~f:Balance.to_amount ~default:Amount.one )
        ( Balance.sub_amount Balance.max_int (Balance.to_amount receiver.balance)
        |> Option.value_map ~f:Balance.to_amount ~default:Amount.one )
    in
    let%bind amount =
      Amount.gen_incl Amount.one (Amount.max Amount.one max_amount)
    in
    let remaining =
      Balance.sub_amount sender.balance amount
      |> Option.value ~default:Balance.zero
    in
    let%map fee =
      Fee.gen_incl Fee.one
        (Fee.max Fee.one (Amount.to_fee (Balance.to_amount remaining)))
    in
    (sender, receiver, amount, fee))
    ~f:(fun (sender, receiver, amount, fee) ->
      let ledger = mk_ledger [ sender; receiver ] in
      assert (Option.is_none (get_account_exn ledger sender.pk).delegate) ;
      assert (Option.is_none (get_account_exn ledger receiver.pk).delegate) ;
      apply_txn ledger
        (payment_command ~sender ~receiver_pk:receiver.pk ~amount ~fee) ;
      let sender_after = get_account_exn ledger sender.pk in
      let receiver_after = get_account_exn ledger receiver.pk in
      assert (
        Balance.equal sender_after.balance
          ( Balance.sub_amount sender.balance
              (Amount.add (Amount.of_fee fee) amount |> Option.value_exn)
          |> Option.value_exn ) ) ;
      assert (
        Balance.equal receiver_after.balance
          (Balance.add_amount receiver.balance amount |> Option.value_exn) ) ;
      assert (Option.is_none sender_after.delegate) ;
      assert (Option.is_none receiver_after.delegate) )
