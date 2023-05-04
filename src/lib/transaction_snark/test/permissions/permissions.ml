open Mina_base

module Test_input : Transaction_snark_tests.Test_zkapp_update.Input_intf =
struct
  let test_description = "permissions"

  let failure_expected =
    ( Mina_base.Transaction_status.Failure.Update_not_permitted_permissions
    , Transaction_snark_tests.Util.Pass_2 )

  let snapp_update =
    { Account_update.Update.dummy with
      permissions =
        Zkapp_basic.Set_or_keep.Set
          { Permissions.user_default with
            set_permissions = Permissions.Auth_required.Proof
          ; set_zkapp_uri = Proof
          ; set_token_symbol = Proof
          ; set_voting_for = Proof
          }
    }

  let is_non_zkapp_update = true
end

let%test_module "Update account permissions" =
  ( module struct
    include Transaction_snark_tests.Test_zkapp_update.Make (Test_input)
    open Core
    module U = Transaction_snark_tests.Util

    let constraint_constants = U.constraint_constants

    let `VK vk, `Prover prover = Lazy.force U.trivial_zkapp

    let%test_unit "update verification key can not be set to be proof or \
                   impossible" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let%bind ledger = U.gen_snapp_ledger in
        let%map auth =
          Quickcheck.Generator.of_list
            [ Permissions.Auth_required.Proof; Impossible ]
        in
        (ledger, auth)
      in
      Quickcheck.test ~trials:1 gen
        ~f:(fun (({ init_ledger; specs }, new_kp), auth) ->
          Mina_ledger.Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Mina_transaction_logic.For_tests.Init_ledger.init
                    (module Mina_ledger.Ledger.Ledger_inner)
                    init_ledger ledger ;
                  Transaction_snark.For_tests.create_trivial_zkapp_account ~vk
                    ~ledger
                    (Signature_lib.Public_key.compress new_kp.public_key) ;
                  let open Async.Deferred.Let_syntax in
                  let%bind zkapp_command =
                    Transaction_snark.For_tests.update_states
                      ~zkapp_prover_and_vk:(prover, vk) ~constraint_constants
                      { sender = (List.hd_exn specs).sender
                      ; fee = Currency.Fee.of_nanomina_int_exn 1_000_000
                      ; fee_payer = None
                      ; receivers = []
                      ; amount = Currency.Amount.zero
                      ; zkapp_account_keypairs = [ new_kp ]
                      ; memo =
                          Signed_command_memo.create_from_string_exn "update vk"
                      ; new_zkapp_account = false
                      ; snapp_update =
                          { Account_update.Update.dummy with
                            permissions =
                              Zkapp_basic.Set_or_keep.Set
                                { Permissions.user_default with
                                  set_verification_key = auth
                                }
                          }
                      ; current_auth = Permissions.Auth_required.Signature
                      ; call_data = Snark_params.Tick.Field.zero
                      ; events = []
                      ; actions = []
                      ; preconditions = None
                      }
                  in
                  U.check_zkapp_command_with_merges_exn
                    ~expected_failure:
                      ( Transaction_status.Failure
                        .Permission_for_update_vk_can_not_be_proof_or_impossible
                      , U.Pass_2 )
                    ledger [ zkapp_command ] ) ) )
  end )
