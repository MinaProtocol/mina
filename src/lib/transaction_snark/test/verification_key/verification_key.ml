open Core_kernel
open Mina_base
open Pickles

module Test_input : Transaction_snark_tests.Test_zkapp_update.Input_intf =
struct
  let test_description = "verification_key"

  let failure_expected =
    ( Mina_base.Transaction_status.Failure.Update_not_permitted_verification_key
    , Transaction_snark_tests.Util.Pass_2 )

  let snapp_update : Account_update.Update.t =
    let new_verification_key :
        (Side_loaded.Verification_key.t, Zkapp_basic.F.t) With_hash.t =
      let data = Pickles.Side_loaded.Verification_key.dummy in
      let hash = Zkapp_account.dummy_vk_hash () in
      ({ data; hash } : _ With_hash.t)
    in
    { Account_update.Update.dummy with
      verification_key = Zkapp_basic.Set_or_keep.Set new_verification_key
    }

  let is_non_zkapp_update = false
end

let suite () =
  Transaction_snark_test_suite.make ~name:"verification_key"
    ~proof_cache_json:Proof_cache_json.contents
  @@ fun ~test ->
  let module _ = struct
    include
      Transaction_snark_tests.Test_zkapp_update.Make
        (Test_input)
        (struct
          let test = test
        end)

    open Currency
    open Signature_lib
    module U = Transaction_snark_tests.Util
    module Spec = Transaction_snark.For_tests.Update_states_spec
    open Test_input

    let `VK vk, `Prover zkapp_prover = Lazy.force U.trivial_zkapp

    let older_version =
      let oldest = Mina_numbers.Txn_version.of_int 1 in
      if Mina_numbers.Txn_version.equal_to_current oldest then
        failwith "already oldest version"
      else oldest

    let check_vk_txn_version_after ~update ~expected () =
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, zkapp_kp) ->
          let open Mina_transaction_logic.For_tests in
          let spec = List.hd_exn specs in
          let zkapp_pk = Public_key.compress zkapp_kp.public_key in
          let zkapp_id = Account_id.create zkapp_pk Token_id.default in
          U.Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let open Async.Deferred.Let_syntax in
                  Init_ledger.init
                    (module U.Ledger.Ledger_inner)
                    init_ledger ledger ;
                  let%bind vk' = vk in
                  Transaction_snark.For_tests.create_trivial_zkapp_account
                    ~vk_txn_version:older_version ~vk:vk' ~ledger zkapp_pk ;
                  let test_spec : Spec.t =
                    { sender = spec.sender
                    ; fee = Fee.of_nanomina_int_exn 1_000_000
                    ; fee_payer = None
                    ; receivers = []
                    ; amount = Amount.of_mina_int_exn 10
                    ; zkapp_account_keypairs = [ zkapp_kp ]
                    ; memo
                    ; new_zkapp_account = false
                    ; snapp_update = update
                    ; current_auth = Signature
                    ; call_data = Snark_params.Tick.Field.zero
                    ; events = []
                    ; actions = []
                    ; preconditions = None
                    }
                  in
                  let%bind zkapp_command =
                    Transaction_snark.For_tests.update_states
                      ~zkapp_prover_and_vk:(zkapp_prover, vk)
                      ~constraint_constants:U.constraint_constants test_spec
                  in
                  let%map () =
                    U.check_zkapp_command_with_merges_exn ledger
                      [ zkapp_command ]
                  in
                  let account =
                    U.Ledger.location_of_account ledger zkapp_id
                    |> Option.value_exn |> U.Ledger.get ledger
                    |> Option.value_exn
                  in
                  [%test_eq: Mina_numbers.Txn_version.t option] (Some expected)
                    (Option.bind account.zkapp
                       ~f:Zkapp_account.verification_key_txn_version ) ) ) )

    let () =
      test "setting the key records the current transaction version"
      @@ check_vk_txn_version_after ~update:snapp_update
           ~expected:Mina_numbers.Txn_version.current

    let () =
      test "keeping the key leaves its transaction version unchanged"
      @@ check_vk_txn_version_after ~update:Account_update.Update.dummy
           ~expected:older_version
  end in
  ()
