open Core_kernel
open Currency
open Mina_base
open Mina_base_test_helpers
open Mina_ledger_test_helpers
open Signature_lib
open Transaction_logic_tests
open Helpers
open Protocol_config_examples

let mk_command ~(sender : Test_account.t) ~fee body =
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
    Signed_command_payload.Body.(
      Stake_delegation (Set_delegate { new_delegate }))

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
  |> Or_error.ok_exn |> List.hd_exn

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
    Amount.to_nanomina_int (Balance.to_amount delegator.balance) / (num_txns + 1)
  in
  let%map fee =
    Fee.gen_incl Fee.one (Fee.max Fee.one (Fee.of_nanomina_int_exn max_fee))
  in
  (delegator, validator, fee)

let mk_ledger accounts =
  Ledger_helpers.ledger_of_accounts accounts |> Or_error.ok_exn

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
      ignore
        ( apply_txn ledger
            (delegation_command ~sender:delegator ~new_delegate:validator.pk
               ~fee )
          : Mina_transaction_logic.Transaction_applied.t ) ;
      assert (
        Option.equal Public_key.Compressed.equal
          (get_account_exn ledger delegator.pk).delegate (Some validator.pk) ) )

(* Test Case 1 (partial): an account that is delegating can opt out
   by delegating to the empty public key. *)
let opt_out_via_empty_delegation () =
  Quickcheck.test ~trials:100 (gen_delegation_scenario ~num_txns:2)
    ~f:(fun (delegator, validator, fee) ->
      let ledger = mk_ledger [ delegator; validator ] in
      ignore
        ( apply_txn ledger
            (delegation_command ~sender:delegator ~new_delegate:validator.pk
               ~fee )
          : Mina_transaction_logic.Transaction_applied.t ) ;
      assert (
        Option.equal Public_key.Compressed.equal
          (get_account_exn ledger delegator.pk).delegate (Some validator.pk) ) ;
      let sender = sender_from_ledger ledger delegator in
      ignore
        ( apply_txn ledger
            (delegation_command ~sender
               ~new_delegate:Public_key.Compressed.empty ~fee )
          : Mina_transaction_logic.Transaction_applied.t ) ;
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
      ignore
        ( apply_txn ledger
            (payment_command ~sender ~receiver_pk:receiver.pk ~amount ~fee)
          : Mina_transaction_logic.Transaction_applied.t ) ;
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

let get_account ledger account_id =
  Ledger.location_of_account ledger account_id
  |> Option.bind ~f:(Ledger.get ledger)

let compute_stake_change ledger applied =
  Mina_transaction_logic.Transaction_applied.stake_change
    ~get_account_after:(get_account ledger) applied

let assert_stake_change ~label ~expected actual =
  if not (Amount.Signed.equal actual expected) then
    failwith
      (sprintf "%s: expected %s, got %s" label
         (Amount.Signed.to_yojson expected |> Yojson.Safe.to_string)
         (Amount.Signed.to_yojson actual |> Yojson.Safe.to_string) )

(* Apply a delegation and assert the resulting stake_change.
   Returns the updated sender (with fresh nonce/balance from ledger). *)
let delegate_and_assert_stake_change ~label ledger (sender : Test_account.t)
    ~new_delegate ~fee =
  let pre_balance =
    Balance.to_amount (get_account_exn ledger sender.pk).balance
  in
  let is_opt_in = Option.is_none (get_account_exn ledger sender.pk).delegate in
  let is_opt_out =
    Public_key.Compressed.(equal new_delegate Public_key.Compressed.empty)
  in
  let applied =
    apply_txn ledger (delegation_command ~sender ~new_delegate ~fee)
  in
  let expected =
    match (is_opt_in, is_opt_out) with
    | true, false ->
        (* None→Some: +(pre_balance - fee) *)
        Amount.Signed.create
          ~magnitude:
            (Amount.sub pre_balance (Amount.of_fee fee) |> Option.value_exn)
          ~sgn:Sgn.Pos
    | false, true ->
        (* Some→None: -pre_balance *)
        Amount.Signed.create ~magnitude:pre_balance ~sgn:Sgn.Neg
    | false, false ->
        (* Some→Some: -fee *)
        Amount.Signed.create ~magnitude:(Amount.of_fee fee) ~sgn:Sgn.Neg
    | true, true ->
        (* None→None: 0 *)
        Amount.Signed.zero
  in
  assert_stake_change ~label ~expected (compute_stake_change ledger applied) ;
  sender_from_ledger ledger sender

let gen_stake_change_scenario =
  let open Quickcheck.Generator.Let_syntax in
  let%bind sender = gen_account ~min:(Balance.of_mina_int_exn 10) () in
  let%bind receiver = gen_account () in
  let%bind validator = gen_account () in
  let%bind amount =
    Amount.gen_incl (Amount.of_mina_int_exn 1) (Amount.of_mina_int_exn 3)
  in
  let%map fee =
    Fee.gen_incl
      (Fee.of_nanomina_int_exn 1_000_000)
      (Fee.of_nanomina_int_exn 10_000_000)
  in
  (sender, receiver, validator, amount, fee)

(* unstaked sender → unstaked receiver: stake_change = 0 *)
let stake_change_unstaked_payment () =
  Quickcheck.test ~trials:100 gen_stake_change_scenario
    ~f:(fun (sender, receiver, _validator, amount, fee) ->
      let ledger = mk_ledger [ sender; receiver ] in
      let applied =
        apply_txn ledger
          (payment_command ~sender ~receiver_pk:receiver.pk ~amount ~fee)
      in
      assert_stake_change ~label:"unstaked→unstaked payment"
        ~expected:Amount.Signed.zero
        (compute_stake_change ledger applied) )

(* 1. opt-in sender   → stake_change = +(bal - del_fee)
   2. opt-in receiver → stake_change = +(bal - del_fee)
   3. staked payment  → stake_change = -fee *)
let stake_change_staked_payment () =
  Quickcheck.test ~trials:100
    (let open Quickcheck.Generator.Let_syntax in
    let%bind sender = gen_account ~min:(Balance.of_mina_int_exn 10) () in
    let%bind receiver = gen_account ~min:(Balance.of_mina_int_exn 10) () in
    let%bind validator_a = gen_account () in
    let%bind validator_b = gen_account () in
    let%bind amount =
      Amount.gen_incl (Amount.of_mina_int_exn 1) (Amount.of_mina_int_exn 3)
    in
    let%map fee =
      Fee.gen_incl
        (Fee.of_nanomina_int_exn 1_000_000)
        (Fee.of_nanomina_int_exn 10_000_000)
    in
    (sender, receiver, validator_a, validator_b, amount, fee))
    ~f:(fun (sender, receiver, validator_a, validator_b, amount, fee) ->
      let ledger = mk_ledger [ sender; receiver; validator_a; validator_b ] in
      let del_fee = Fee.of_nanomina_int_exn 1_000_000 in
      let sender' =
        delegate_and_assert_stake_change ~label:"sender opt-in" ledger sender
          ~new_delegate:validator_a.pk ~fee:del_fee
      in
      ignore
        ( delegate_and_assert_stake_change ~label:"receiver opt-in" ledger
            receiver ~new_delegate:validator_b.pk ~fee:del_fee
          : Test_account.t ) ;
      let applied =
        apply_txn ledger
          (payment_command ~sender:sender' ~receiver_pk:receiver.pk ~amount ~fee)
      in
      assert_stake_change ~label:"staked→staked payment"
        ~expected:
          (Amount.Signed.create ~magnitude:(Amount.of_fee fee) ~sgn:Sgn.Neg)
        (compute_stake_change ledger applied) )

(* 1. opt-in  (None→Some) → stake_change = +(bal - fee)
   2. opt-out (Some→None) → stake_change = -pre_balance *)
let stake_change_opt_out () =
  Quickcheck.test ~trials:100 gen_stake_change_scenario
    ~f:(fun (sender, _receiver, validator, _amount, fee) ->
      let ledger = mk_ledger [ sender; validator ] in
      let sender' =
        delegate_and_assert_stake_change ~label:"opt-in before opt-out" ledger
          sender ~new_delegate:validator.pk ~fee
      in
      ignore
        ( delegate_and_assert_stake_change ~label:"opt-out" ledger sender'
            ~new_delegate:Public_key.Compressed.empty ~fee
          : Test_account.t ) )

(* opt-in (None→Some): stake_change = +(bal - fee) *)
let stake_change_opt_in () =
  Quickcheck.test ~trials:100 gen_stake_change_scenario
    ~f:(fun (sender, _receiver, validator, _amount, fee) ->
      let ledger = mk_ledger [ sender; validator ] in
      ignore
        ( delegate_and_assert_stake_change ~label:"opt-in" ledger sender
            ~new_delegate:validator.pk ~fee
          : Test_account.t ) )

(* Zkapp: fee_payer unstaked, payment between unstaked accounts.
   stake_change = 0 for both fee_payer and account_updates. *)
let zkapp_stake_change_unstaked () =
  Quickcheck.test ~trials:100
    (let open Quickcheck.Generator.Let_syntax in
    let%bind sender = gen_account ~min:(Balance.of_mina_int_exn 10) () in
    let%bind receiver = gen_account () in
    let%bind amount =
      Amount.gen_incl (Amount.of_mina_int_exn 1) (Amount.of_mina_int_exn 3)
    in
    let%map fee =
      Fee.gen_incl
        (Fee.of_nanomina_int_exn 1_000_000)
        (Fee.of_nanomina_int_exn 10_000_000)
    in
    (sender, receiver, amount, fee))
    ~f:(fun (sender, receiver, amount, fee) ->
      let accounts = [ sender; receiver ] in
      let txn = Zkapp_cmd_builder.Simple_txn.make ~sender ~receiver amount in
      let cmd =
        Zkapp_cmd_builder.zkapp_cmd
          ~noncemap:(Ledger_helpers.noncemap accounts)
          ~fee:(sender.pk, fee)
          [ (txn :> Zkapp_cmd_builder.transaction) ]
      in
      let ledger = mk_ledger accounts in
      (* apply_zkapp_command_unchecked mutates ledger in place *)
      let applied, _local =
        Transaction_logic.apply_zkapp_command_unchecked ~signature_kind
          ~constraint_constants ~global_slot ~state_view:protocol_state ledger
          cmd
        |> Or_error.ok_exn
      in
      (* ledger is now post-tx *)
      let stake_change =
        compute_stake_change ledger
          { previous_hash = Ledger_hash.empty_hash
          ; varying = Command (Zkapp_command applied)
          }
      in
      assert_stake_change ~label:"zkapp unstaked payment"
        ~expected:Amount.Signed.zero stake_change )

(* Zkapp: fee_payer is staked (has delegate), sends payment.
   stake_change = -fee from fee_payer. *)
let zkapp_stake_change_staked_fee_payer () =
  Quickcheck.test ~trials:100
    (let open Quickcheck.Generator.Let_syntax in
    let%bind sender = gen_account ~min:(Balance.of_mina_int_exn 10) () in
    let%bind receiver = gen_account () in
    let%bind validator = gen_account () in
    let%bind amount =
      Amount.gen_incl (Amount.of_mina_int_exn 1) (Amount.of_mina_int_exn 3)
    in
    let%map fee =
      Fee.gen_incl
        (Fee.of_nanomina_int_exn 1_000_000)
        (Fee.of_nanomina_int_exn 10_000_000)
    in
    (sender, receiver, validator, amount, fee))
    ~f:(fun (sender, receiver, validator, amount, fee) ->
      let accounts = [ sender; receiver; validator ] in
      let ledger = mk_ledger accounts in
      (* First opt-in the sender via signed command *)
      ignore
        ( delegate_and_assert_stake_change ~label:"sender opt-in" ledger sender
            ~new_delegate:validator.pk
            ~fee:(Fee.of_nanomina_int_exn 1_000_000)
          : Test_account.t ) ;
      let sender' = sender_from_ledger ledger sender in
      (* Now send a zkapp payment — both sender and receiver account_updates
         are unstaked, but fee_payer (= sender) is staked so fee affects stake *)
      let txn =
        Zkapp_cmd_builder.Simple_txn.make ~sender:sender' ~receiver amount
      in
      let cmd =
        Zkapp_cmd_builder.zkapp_cmd
          ~noncemap:(Ledger_helpers.noncemap [ sender'; receiver ])
          ~fee:(sender'.pk, fee)
          [ (txn :> Zkapp_cmd_builder.transaction) ]
      in
      (* apply_zkapp_command_unchecked mutates ledger in place *)
      let applied, _local =
        Transaction_logic.apply_zkapp_command_unchecked ~signature_kind
          ~constraint_constants ~global_slot ~state_view:protocol_state ledger
          cmd
        |> Or_error.ok_exn
      in
      (* ledger is now post-tx; fee_payer is staked so fee leaves staking.
         Sender account_update also decreases sender's staked balance by
         amount. Receiver is unstaked. Total = -(fee + amount) *)
      let stake_change =
        compute_stake_change ledger
          { previous_hash = Ledger_hash.empty_hash
          ; varying = Command (Zkapp_command applied)
          }
      in
      let expected =
        let fee_plus_amount =
          Option.value_exn (Amount.add (Amount.of_fee fee) amount)
        in
        Amount.Signed.create ~magnitude:fee_plus_amount ~sgn:Sgn.Neg
      in
      assert_stake_change ~label:"zkapp staked fee_payer payment" ~expected
        stake_change )

(* Zkapp: account_update sets delegate from None to validator (opt-in).
   Fee_payer is unstaked (0 from fee). The account_update has zero
   balance_change but changes delegate None→Some, so its post-balance
   enters staking. stake_change = +account_balance *)
let zkapp_stake_change_delegate_opt_in () =
  Quickcheck.test ~trials:100
    (let open Quickcheck.Generator.Let_syntax in
    let%bind account = gen_account ~min:(Balance.of_mina_int_exn 10) () in
    let%bind validator = gen_account () in
    let%map fee =
      Fee.gen_incl
        (Fee.of_nanomina_int_exn 1_000_000)
        (Fee.of_nanomina_int_exn 10_000_000)
    in
    (account, validator, fee))
    ~f:(fun (account, validator, fee) ->
      let accounts = [ account; validator ] in
      let delegate_update =
        { Mina_base.Account_update.Update.noop with
          delegate = Set validator.pk
        }
      in
      let txn =
        object
          method updates =
            let open Monad_lib.State.Let_syntax in
            let%map body =
              Zkapp_cmd_builder.update_body ~update:delegate_update ~account
                Amount.Signed.zero
            in
            [ Zkapp_cmd_builder.update
              @@ Mina_base.Account_update.with_aux ~body
                   ~authorization:Zkapp_cmd_builder.dummy_auth
            ]
        end
      in
      let cmd =
        Zkapp_cmd_builder.zkapp_cmd
          ~noncemap:(Ledger_helpers.noncemap accounts)
          ~fee:(account.pk, fee)
          [ (txn :> Zkapp_cmd_builder.transaction) ]
      in
      let ledger = mk_ledger accounts in
      let pre_balance =
        Balance.to_amount (get_account_exn ledger account.pk).balance
      in
      (* apply_zkapp_command_unchecked mutates ledger in place *)
      let applied, _local =
        Transaction_logic.apply_zkapp_command_unchecked ~signature_kind
          ~constraint_constants ~global_slot ~state_view:protocol_state ledger
          cmd
        |> Or_error.ok_exn
      in
      (* ledger is now post-tx; account opted in via account_update.
         Fee_payer is unstaked: 0 from fee.
         Account_update: None→Some, post_balance = pre_balance - fee.
         stake_change = +(pre_balance - fee) *)
      let stake_change =
        compute_stake_change ledger
          { previous_hash = Ledger_hash.empty_hash
          ; varying = Command (Zkapp_command applied)
          }
      in
      let expected =
        let post_balance =
          Option.value_exn (Amount.sub pre_balance (Amount.of_fee fee))
        in
        Amount.Signed.create ~magnitude:post_balance ~sgn:Sgn.Pos
      in
      assert_stake_change ~label:"zkapp delegate opt-in" ~expected stake_change
      )

(* Zkapp: account_update sets delegate from validator to empty (opt-out).
   Account starts staked (via signed command delegation), then a zkapp
   account_update sets delegate to empty. Fee_payer = same account, staked
   at fee time so fee leaves staking. Account_update: Some→None, entire
   pre-balance (at time of account_update = post_fee_balance) leaves staking.
   But fee_payer and account_update are the same account — fee_payer uses
   pre-tx delegate (staked), so fp_contrib = -fee. Account_update sees
   Some→None, so its contrib = -pre_update_balance = -(post_fee_balance).
   Total = -(fee + post_fee_balance) = -original_balance *)
let zkapp_stake_change_delegate_opt_out () =
  Quickcheck.test ~trials:100
    (let open Quickcheck.Generator.Let_syntax in
    let%bind account = gen_account ~min:(Balance.of_mina_int_exn 10) () in
    let%bind validator = gen_account () in
    let%map fee =
      Fee.gen_incl
        (Fee.of_nanomina_int_exn 1_000_000)
        (Fee.of_nanomina_int_exn 10_000_000)
    in
    (account, validator, fee))
    ~f:(fun (account, validator, fee) ->
      let accounts = [ account; validator ] in
      let ledger = mk_ledger accounts in
      (* First opt-in via signed command *)
      ignore
        ( delegate_and_assert_stake_change ~label:"opt-in before zkapp opt-out"
            ledger account ~new_delegate:validator.pk
            ~fee:(Fee.of_nanomina_int_exn 1_000_000)
          : Test_account.t ) ;
      let account' = sender_from_ledger ledger account in
      let pre_balance =
        Balance.to_amount (get_account_exn ledger account'.pk).balance
      in
      (* Now opt-out via zkapp account_update *)
      let delegate_update =
        { Mina_base.Account_update.Update.noop with
          delegate = Set Public_key.Compressed.empty
        }
      in
      let txn =
        object
          method updates =
            let open Monad_lib.State.Let_syntax in
            let%map body =
              Zkapp_cmd_builder.update_body ~update:delegate_update
                ~account:account' Amount.Signed.zero
            in
            [ Zkapp_cmd_builder.update
              @@ Mina_base.Account_update.with_aux ~body
                   ~authorization:Zkapp_cmd_builder.dummy_auth
            ]
        end
      in
      let cmd =
        Zkapp_cmd_builder.zkapp_cmd
          ~noncemap:(Ledger_helpers.noncemap [ account' ])
          ~fee:(account'.pk, fee)
          [ (txn :> Zkapp_cmd_builder.transaction) ]
      in
      (* apply_zkapp_command_unchecked mutates ledger in place *)
      let applied, _local =
        Transaction_logic.apply_zkapp_command_unchecked ~signature_kind
          ~constraint_constants ~global_slot ~state_view:protocol_state ledger
          cmd
        |> Or_error.ok_exn
      in
      (* ledger is now post-tx; account opted out.
         Total stake_change = -pre_balance (entire staked balance leaves) *)
      let stake_change =
        compute_stake_change ledger
          { previous_hash = Ledger_hash.empty_hash
          ; varying = Command (Zkapp_command applied)
          }
      in
      assert_stake_change ~label:"zkapp delegate opt-out"
        ~expected:(Amount.Signed.create ~magnitude:pre_balance ~sgn:Sgn.Neg)
        stake_change )

(* Zkapp: account_update re-delegates from validator_a to validator_b.
   Account stays staked throughout, so stake_change = -fee (only the
   fee leaves staking, via the fee_payer = same account). *)
let zkapp_stake_change_redelegate () =
  Quickcheck.test ~trials:100
    (let open Quickcheck.Generator.Let_syntax in
    let%bind account = gen_account ~min:(Balance.of_mina_int_exn 10) () in
    let%bind validator_a = gen_account () in
    let%bind validator_b = gen_account () in
    let%map fee =
      Fee.gen_incl
        (Fee.of_nanomina_int_exn 1_000_000)
        (Fee.of_nanomina_int_exn 10_000_000)
    in
    (account, validator_a, validator_b, fee))
    ~f:(fun (account, validator_a, validator_b, fee) ->
      let accounts = [ account; validator_a; validator_b ] in
      let ledger = mk_ledger accounts in
      (* First opt-in via signed command *)
      ignore
        ( delegate_and_assert_stake_change ~label:"opt-in before redelegate"
            ledger account ~new_delegate:validator_a.pk
            ~fee:(Fee.of_nanomina_int_exn 1_000_000)
          : Test_account.t ) ;
      let account' = sender_from_ledger ledger account in
      (* Re-delegate via zkapp account_update *)
      let delegate_update =
        { Mina_base.Account_update.Update.noop with
          delegate = Set validator_b.pk
        }
      in
      let txn =
        object
          method updates =
            let open Monad_lib.State.Let_syntax in
            let%map body =
              Zkapp_cmd_builder.update_body ~update:delegate_update
                ~account:account' Amount.Signed.zero
            in
            [ Zkapp_cmd_builder.update
              @@ Mina_base.Account_update.with_aux ~body
                   ~authorization:Zkapp_cmd_builder.dummy_auth
            ]
        end
      in
      let cmd =
        Zkapp_cmd_builder.zkapp_cmd
          ~noncemap:(Ledger_helpers.noncemap [ account' ])
          ~fee:(account'.pk, fee)
          [ (txn :> Zkapp_cmd_builder.transaction) ]
      in
      (* apply_zkapp_command_unchecked mutates ledger in place *)
      let applied, _local =
        Transaction_logic.apply_zkapp_command_unchecked ~signature_kind
          ~constraint_constants ~global_slot ~state_view:protocol_state ledger
          cmd
        |> Or_error.ok_exn
      in
      (* ledger is now post-tx; account re-delegated (Some→Some).
         Fee_payer staked: -fee. Account_update staked→staked with
         zero balance_change: 0. Total = -fee *)
      let stake_change =
        compute_stake_change ledger
          { previous_hash = Ledger_hash.empty_hash
          ; varying = Command (Zkapp_command applied)
          }
      in
      assert_stake_change ~label:"zkapp redelegate"
        ~expected:
          (Amount.Signed.create ~magnitude:(Amount.of_fee fee) ~sgn:Sgn.Neg)
        stake_change )
