open Core_kernel
open Mina_base

let different_version = Mina_numbers.Txn_version.(succ current)

let update_vk_perm_to_be ~auth : Zkapp_command.t =
  let account_update : Account_update.t =
    { body =
        { Account_update.Body.dummy with
          update =
            { Account_update.Body.dummy.update with
              permissions =
                Set
                  { Permissions.user_default with set_verification_key = auth }
            }
        }
    ; authorization = Control.dummy_of_tag Signature
    }
  in
  let fee_payer : Account_update.Fee_payer.t =
    { body =
        { Account_update.Body.Fee_payer.dummy with
          fee = Currency.Fee.of_mina_int_exn 100
        }
    ; authorization = Signature.dummy
    }
  in
  { fee_payer
  ; account_updates = Zkapp_command.Call_forest.cons account_update []
  ; memo = Signed_command_memo.empty
  }

let auth_gen =
  Quickcheck.Generator.of_list
    [ Permissions.Auth_required.Either; Impossible; None; Proof; Signature ]

let update_vk_perm_with_different_version () =
  Quickcheck.test ~trials:10 auth_gen ~f:(fun auth ->
      match
        User_command.check_well_formedness
          ~genesis_constants:Genesis_constants.for_unit_tests
          (Zkapp_command (update_vk_perm_to_be ~auth:(auth, different_version)))
      with
      | Ok _ ->
          raise
            (Failure "Well-formedness check was expected to fail, but didn't")
      | Error e ->
          [%test_eq: User_command.Well_formedness_error.t list] e
            [ Incompatible_version ] )

let update_vk_perm_with_current_version () =
  Quickcheck.test ~trials:10 auth_gen ~f:(fun auth ->
      match
        User_command.check_well_formedness
          ~genesis_constants:Genesis_constants.for_unit_tests
          (Zkapp_command
             (update_vk_perm_to_be
                ~auth:(auth, Mina_numbers.Txn_version.current) ) )
      with
      | Ok () ->
          ()
      | Error _ ->
          raise
            (Failure "Well-formedness check was expected to pass, but didn't") )
