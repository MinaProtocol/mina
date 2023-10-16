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

let%test_module "Update account verification key" =
  ( module struct
    include Transaction_snark_tests.Test_zkapp_update.Make (Test_input)
    open Core
    open Mina_ledger
    open Currency
    open Signature_lib
    module U = Transaction_snark_tests.Util
    module Spec = Transaction_snark.For_tests.Update_states_spec

    let constraint_constants = U.constraint_constants

    let%test_unit "Update when not permitted but transaction is applied" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              let spec = List.hd_exn specs in
              let fee = Fee.of_nanomina_int_exn 1_000_000 in
              let amount = Amount.of_mina_int_exn 10 in
              let test_spec : Spec.t =
                { sender = spec.sender
                ; fee
                ; fee_payer = None
                ; receivers = []
                ; amount
                ; zkapp_account_keypairs = [ new_kp ]
                ; memo
                ; new_zkapp_account = false
                ; snapp_update = Test_input.snapp_update
                ; current_auth = Permissions.Auth_required.Signature
                ; call_data = Snark_params.Tick.Field.zero
                ; events = []
                ; actions = []
                ; preconditions = None
                }
              in
              let snapp_pk = Public_key.compress new_kp.public_key in
              Init_ledger.init (module Ledger.Ledger_inner) init_ledger ledger ;
              (*Create snapp transaction*)
              Transaction_snark.For_tests.create_trivial_zkapp_account
                ~permissions:
                  (U.permissions_from_update Test_input.snapp_update ~auth:Proof)
                ~vk ~ledger snapp_pk ;
              (*Ledger.apply_transaction should be successful if fee payer update
                is successful*)
              U.test_snapp_update ~expected_failure:Test_input.failure_expected
                ~snapp_permissions:
                  (U.permissions_from_update Test_input.snapp_update ~auth:Proof)
                ~vk ~zkapp_prover test_spec ~init_ledger ~snapp_pk ) )
  end )
