open Core_kernel
open Currency
open Mina_base
open Mina_base_test_helpers
open Mina_ledger_test_helpers
open Mina_transaction_logic
open Signature_lib
open Transaction_logic_tests
open Helpers
open Protocol_config_examples

let expect_success =
  [%test_pred: Transaction_applied.t list Or_error.t] Or_error.is_ok

let expect_failure ~error = function
  | Ok _ ->
      failwith "Success where failure was expected."
  | Error e when String.equal error (Error.to_string_hum e) ->
      ()
  | Error e ->
      failwithf "Unexpected error: '%s'." (Error.to_string_hum e) ()

let signed_command ?(valid_until = Global_slot_since_genesis.max_value) ?signer
    ~sender ~receiver ~fee amount =
  let open Mina_transaction.Transaction in
  let open Test_account in
  let signer =
    Option.value_map ~f:Test_account.public_key signer ~default:sender.pk
    |> Public_key.decompress_exn
  in
  let amt = amount in
  let rcv = receiver.pk in
  let fee' = fee in
  let valid = valid_until in
  let payload =
    let open Signed_command_payload in
    Poly.
      { body = Body.Payment { receiver_pk = rcv; amount = amt }
      ; common =
          (let open Signed_command.Payload.Common.Poly in
          { fee = fee'
          ; fee_payer_pk = sender.pk
          ; nonce = sender.nonce
          ; valid_until = valid
          ; memo = Signed_command_memo.dummy
          })
      }
  in
  Command
    (User_command.Signed_command
       Signed_command.Poly.{ payload; signer; signature = Signature.dummy } )

let balance_to_fee b = Balance.to_amount b |> Amount.to_fee

let setup =
  let open Quickcheck.Generator.Let_syntax in
  let%bind global_slot = Global_slot_since_genesis.gen in
  (* Sender must pay at least 1 nanomina of fee and at least 1 nanomina of transfer. *)
  let%bind sender =
    Test_account.gen_constrained_balance () ~min:Balance.(of_nanomina_int_exn 2)
  in
  (* Amount cannot drain whole sender's balance, because we want a non-zero fee. *)
  let max_amount =
    Balance.(sub_amount sender.balance Amount.one)
    |> Option.value_map ~f:Balance.to_amount ~default:Amount.one
  in
  let%bind amount = Amount.gen_incl Amount.one max_amount in
  (* Receiver's balance must be able to pay the fee and also to accept the amount. *)
  let max_recv_balance =
    Balance.(sub_amount max_int amount) |> Option.value ~default:Balance.zero
  in
  let%bind receiver =
    Test_account.gen_constrained_balance () ~max:max_recv_balance
      ~min:Balance.(of_nanomina_int_exn 1)
  in
  (* We don't decide, who pays the fee yet, so both parties must be able to do so. *)
  let max_sender_fee =
    Balance.(sub_amount sender.balance amount)
    |> Option.value_map ~f:balance_to_fee ~default:Fee.one
  in
  let max_recv_fee = balance_to_fee receiver.balance in
  let%map fee = Fee.(gen_incl Fee.one (min max_sender_fee max_recv_fee)) in
  (global_slot, sender, receiver, amount, fee)

let simple_payment () =
  Quickcheck.test ~trials:1000 setup
    ~f:(fun (global_slot, sender, receiver, amount, fee) ->
      let accounts = [ sender; receiver ] in
      let txn = signed_command ~fee ~sender ~receiver amount in
      let txn_state_view = protocol_state in
      let ledger =
        match Ledger_helpers.ledger_of_accounts accounts with
        | Ok l ->
            l
        | Error _ ->
            assert false
      in
      [%test_pred: Transaction_applied.t list Or_error.t] Or_error.is_ok
        (Transaction_logic.apply_transactions ~constraint_constants ~global_slot
           ~txn_state_view ledger [ txn ] ) )

let simple_payment_signer_different_from_fee_payer () =
  Quickcheck.test ~trials:1000 setup
    ~f:(fun (global_slot, sender, receiver, amount, fee) ->
      let accounts = [ sender; receiver ] in
      let txn = signed_command ~signer:receiver ~fee ~sender ~receiver amount in
      let txn_state_view = protocol_state in
      let ledger =
        match Ledger_helpers.ledger_of_accounts accounts with
        | Ok l ->
            l
        | Error _ ->
            assert false
      in
      expect_failure
        ~error:
          "Cannot pay fees from a public key that did not sign the transaction"
        (Transaction_logic.apply_transactions ~constraint_constants ~global_slot
           ~txn_state_view ledger [ txn ] ) )

let coinbase_order_of_created_accounts_is_correct ~with_fee_transfer () =
  let amount = Amount.of_mina_int_exn 720 in
  let make_nondeterministic_pk () =
    Private_key.create () |> Public_key.of_private_key_exn
    |> Public_key.compress
  in
  let receiver = make_nondeterministic_pk () in
  let fee_transfer =
    if with_fee_transfer then
      let receiver_pk = make_nondeterministic_pk () in
      let fee = Fee.of_mina_int_exn 10 in
      Some (Coinbase_fee_transfer.create ~receiver_pk ~fee)
    else None
  in
  let coinbase_txn =
    Or_error.ok_exn @@ Coinbase.create ~amount ~receiver ~fee_transfer
  in
  let accounts = [] (* All accounts are new *) in
  let ledger =
    match Ledger_helpers.ledger_of_accounts ~depth:(Fixed_depth 2) accounts with
    | Ok l ->
        l
    | Error _ ->
        assert false
  in
  let txn_global_slot = Global_slot_since_genesis.of_int 5 in
  [%test_pred: Transaction_applied.Coinbase_applied.t Or_error.t] Or_error.is_ok
    (Transaction_logic.apply_coinbase ~constraint_constants ~txn_global_slot
       ledger coinbase_txn ) ;
  let int_loc_of_account pk =
    Ledger.location_of_account ledger pk
    |> Option.value_exn |> Mina_ledger.Ledger.Location.to_path_exn
    |> Mina_ledger.Ledger.Addr.to_int
  in
  let coinbase_accounts_referenced =
    Coinbase.accounts_referenced coinbase_txn
  in
  List.iteri coinbase_accounts_referenced ~f:(fun idx pk ->
      let actual_idx = int_loc_of_account pk in
      [%test_eq: int] actual_idx idx )
