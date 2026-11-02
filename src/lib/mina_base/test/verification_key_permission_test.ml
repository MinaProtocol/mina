open Core_kernel
open Mina_base

let update_vk_perm_to_be ~auth : Zkapp_command.t =
  let signature_kind = Mina_signature_kind.Testnet in
  let account_update : Account_update.t =
    Account_update.with_aux
      ~body:
        { Account_update.Body.dummy with
          update =
            { Account_update.Body.dummy.update with
              permissions =
                Set
                  { Permissions.user_default with set_verification_key = auth }
            }
        }
      ~authorization:(Control.Poly.Signature Signature.dummy)
  in
  let fee_payer : Account_update.Fee_payer.t =
    Account_update.Fee_payer.make
      ~body:
        { Account_update.Body.Fee_payer.dummy with
          fee = Currency.Fee.of_mina_int_exn 100
        }
      ~authorization:Signature.dummy
  in
  { fee_payer
  ; account_updates =
      Zkapp_command.Call_forest.cons ~signature_kind account_update []
  ; memo = Signed_command_memo.empty
  }

let auth_gen =
  Quickcheck.Generator.of_list
    [ Permissions.Auth_required.Either; Impossible; None; Proof; Signature ]

let update_vk_perm () =
  Quickcheck.test ~trials:10 auth_gen ~f:(fun auth ->
      match
        User_command.check_well_formedness
          ~genesis_constants:Genesis_constants.For_unit_tests.t
          (Zkapp_command (update_vk_perm_to_be ~auth))
      with
      | Ok () ->
          ()
      | Error _ ->
          raise
            (Failure "Well-formedness check was expected to pass, but didn't") )
