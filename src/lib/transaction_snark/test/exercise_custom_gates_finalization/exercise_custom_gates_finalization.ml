open Async
open Core_kernel
open Mina_base
module Init_ledger = Mina_transaction_logic.For_tests.Init_ledger

let keypair_and_amounts = Quickcheck.random_value ~seed:(`Deterministic "") (Init_ledger.gen ())

let fish1_kp = fst keypair_and_amounts.(0)

let fish2_kp = fst keypair_and_amounts.(1)

let zkapp_keypairs = List.init 3 ~f:(fun _ -> Signature_lib.Keypair.create ())

let constraint_constants = Genesis_constants.Constraint_constants.compiled

let mk_cmds () =
  (* Shamelessly inlined from src/app/test_executive/zkapps.ml *)
  let%bind zkapp_command_create_accounts =
    (* construct a Zkapp_command.t, similar to zkapp_test_transaction create-zkapp-account *)
    let amount = Currency.Amount.of_mina_int_exn 10 in
    let nonce = Account.Nonce.zero in
    let memo =
      Signed_command_memo.create_from_string_exn "Zkapp create account"
    in
    let fee = Currency.Fee.of_nanomina_int_exn 20_000_000 in
    let (zkapp_command_spec : Transaction_snark.For_tests.Deploy_snapp_spec.t) =
      { sender = (fish1_kp, nonce)
      ; fee
      ; fee_payer = None
      ; amount
      ; zkapp_account_keypairs = zkapp_keypairs
      ; memo
      ; new_zkapp_account = true
      ; snapp_update = Account_update.Update.dummy
      ; preconditions = None
      ; authorization_kind = Signature
      }
    in
    return
    @@ Transaction_snark.For_tests.deploy_snapp ~constraint_constants
         zkapp_command_spec
  in
  let%bind.Deferred zkapp_command_update_permissions =
    (* construct a Zkapp_command.t, similar to zkapp_test_transaction update-permissions *)
    let nonce = Account.Nonce.zero in
    let memo =
      Signed_command_memo.create_from_string_exn "Zkapp update permissions"
    in
    (* Lower fee so that zkapp_command_create_accounts gets applied first *)
    let fee = Currency.Fee.of_nanomina_int_exn 10_000_000 in
    let new_permissions : Permissions.t =
      { Permissions.user_default with
        edit_state = Permissions.Auth_required.Proof
      ; edit_sequence_state = Proof
      ; set_delegate = Proof
      ; set_verification_key = Proof
      ; set_permissions = Proof
      ; set_zkapp_uri = Proof
      ; set_token_symbol = Proof
      ; set_voting_for = Proof
      ; set_timing = Proof
      ; send = Proof
      }
    in
    let (zkapp_command_spec : Transaction_snark.For_tests.Update_states_spec.t)
        =
      { sender = (fish2_kp, nonce)
      ; fee
      ; fee_payer = None
      ; receivers = []
      ; amount = Currency.Amount.zero
      ; zkapp_account_keypairs = zkapp_keypairs
      ; memo
      ; new_zkapp_account = false
      ; snapp_update =
          { Account_update.Update.dummy with permissions = Set new_permissions }
      ; current_auth =
          (* current set_permissions permission requires Signature *)
          Permissions.Auth_required.Signature
      ; call_data = Snark_params.Tick.Field.zero
      ; events = []
      ; actions = []
      ; preconditions = None
      }
    in
    let%map.Deferred zkapp_command =
      Transaction_snark.For_tests.update_states ~constraint_constants
        zkapp_command_spec
    in
    zkapp_command
  in
  let%bind.Deferred zkapp_command_update_all =
    let amount = Currency.Amount.zero in
    let nonce = Account.Nonce.of_int 1 in
    let memo = Signed_command_memo.create_from_string_exn "Zkapp update all" in
    let fee = Currency.Fee.of_nanomina_int_exn 10_000_000 in
    let app_state =
      let len = Zkapp_state.Max_state_size.n |> Pickles_types.Nat.to_int in
      let fields =
        Quickcheck.random_value
          (Quickcheck.Generator.list_with_length len Snark_params.Tick.Field.gen)
      in
      List.map fields ~f:(fun field -> Zkapp_basic.Set_or_keep.Set field)
      |> Zkapp_state.V.of_list_exn
    in
    let new_delegate =
      Quickcheck.random_value Signature_lib.Public_key.Compressed.gen
    in
    let new_verification_key =
      let data = Pickles.Side_loaded.Verification_key.dummy in
      let hash = Zkapp_account.digest_vk data in
      ({ data; hash } : _ With_hash.t)
    in
    let new_permissions =
      Quickcheck.random_value (Permissions.gen ~auth_tag:Proof)
    in
    let new_zkapp_uri = "https://www.minaprotocol.com" in
    let new_token_symbol = "SHEKEL" in
    let new_voting_for = Quickcheck.random_value State_hash.gen in
    let snapp_update : Account_update.Update.t =
      { app_state
      ; delegate = Set new_delegate
      ; verification_key = Set new_verification_key
      ; permissions = Set new_permissions
      ; zkapp_uri = Set new_zkapp_uri
      ; token_symbol = Set new_token_symbol
      ; timing = (* timing can't be updated for an existing account *)
                 Keep
      ; voting_for = Set new_voting_for
      }
    in
    let (zkapp_command_spec : Transaction_snark.For_tests.Update_states_spec.t)
        =
      { sender = (fish2_kp, nonce)
      ; fee
      ; fee_payer = None
      ; receivers = []
      ; amount
      ; zkapp_account_keypairs = zkapp_keypairs
      ; memo
      ; new_zkapp_account = false
      ; snapp_update
      ; current_auth = Permissions.Auth_required.Proof
      ; call_data = Snark_params.Tick.Field.zero
      ; events = []
      ; actions = []
      ; preconditions = None
      }
    in
    let%bind.Deferred zkapp_command_update_all =
      Transaction_snark.For_tests.update_states ~constraint_constants
        zkapp_command_spec
    in
    return zkapp_command_update_all
  in
  return
    [ zkapp_command_create_accounts
    ; zkapp_command_update_permissions
    ; zkapp_command_update_all
    ]

(* NOTE: THIS TEST ONLY FAILS WITH THE `develop` DUNE PROFILE
Run with
```
dune runtest --profile=devnet --no-buffer src/lib/transaction_snark/test/exercise_custom_gates_finalization/
```
*)
let%test_unit "Prove transaction" =
  let open Async in
  Thread_safe.block_on_async_exn (fun () ->
      let%bind txns = mk_cmds () in
      let ledger =
        Mina_ledger.Ledger.create_ephemeral
          ~depth:constraint_constants.ledger_depth ()
      in
      Init_ledger.init
        (module Mina_ledger.Ledger.Ledger_inner)
        keypair_and_amounts ledger ;
      let%map () =
        Transaction_snark_tests.Util.check_zkapp_command_with_merges_exn ledger
          txns
      in
      Mina_ledger.Ledger.close ledger )
