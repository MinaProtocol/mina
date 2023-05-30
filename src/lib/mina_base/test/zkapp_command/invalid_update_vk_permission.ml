open Core_kernel
open Mina_base

let%test_module "update vk with proof or impossible" =
  ( module struct
    let update_vk_perm_to_be ~auth : Zkapp_command.t =
      let account_update : Account_update.t =
        { body =
            { Account_update.Body.dummy with
              update =
                { Account_update.Body.dummy.update with
                  permissions =
                    Set
                      { Permissions.user_default with
                        set_verification_key = auth
                      }
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

    let%test "update vk with proof" =
      match
        User_command.check_well_formedness
          ~genesis_constants:Genesis_constants.for_unit_tests
          (Zkapp_command
             (update_vk_perm_to_be ~auth:Permissions.Auth_required.Proof) )
      with
      | Error [ Permission_for_update_vk_can_not_be_proof_or_impossible ] ->
          true
      | Ok _ | Error _ ->
          false

    let%test "update vk with impossible" =
      match
        User_command.check_well_formedness
          ~genesis_constants:Genesis_constants.for_unit_tests
          (Zkapp_command
             (update_vk_perm_to_be ~auth:Permissions.Auth_required.Impossible)
          )
      with
      | Error [ Permission_for_update_vk_can_not_be_proof_or_impossible ] ->
          true
      | Ok _ | Error _ ->
          false

    let%test "update vk with signature" =
      match
        User_command.check_well_formedness
          ~genesis_constants:Genesis_constants.for_unit_tests
          (Zkapp_command
             (update_vk_perm_to_be ~auth:Permissions.Auth_required.Signature) )
      with
      | Ok _ ->
          true
      | Error _ ->
          false

    let%test "update vk with either" =
      match
        User_command.check_well_formedness
          ~genesis_constants:Genesis_constants.for_unit_tests
          (Zkapp_command
             (update_vk_perm_to_be ~auth:Permissions.Auth_required.Either) )
      with
      | Ok _ ->
          true
      | Error _ ->
          false

    let%test "update vk with none" =
      match
        User_command.check_well_formedness
          ~genesis_constants:Genesis_constants.for_unit_tests
          (Zkapp_command
             (update_vk_perm_to_be ~auth:Permissions.Auth_required.None) )
      with
      | Ok _ ->
          true
      | Error _ ->
          false
  end )
