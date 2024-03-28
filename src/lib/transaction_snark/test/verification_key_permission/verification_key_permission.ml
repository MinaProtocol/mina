open Core_kernel
open Mina_base

module Test_input : Transaction_snark_tests.Test_zkapp_update.Input_intf =
struct
  let test_description = "vk-permission-proof"

  let failure_expected =
    ( Mina_base.Transaction_status.Failure.Update_not_permitted_permissions
    , Transaction_snark_tests.Util.Pass_2 )

  let snapp_update =
    { Account_update.Update.dummy with
      permissions =
        Zkapp_basic.Set_or_keep.Set
          { Permissions.user_default with
            set_verification_key = (Proof, Mina_numbers.Txn_version.current)
          }
    }

  let is_non_zkapp_update = true
end

let%test_module "Update account verification key permission from mainnet to \
                 berkeley" =
  ( module struct
    let proof_cache =
      Result.ok_or_failwith @@ Pickles.Proof_cache.of_yojson
      @@ Yojson.Safe.from_file "proof_cache.json"

    let () = Transaction_snark.For_tests.set_proof_cache proof_cache

    open Currency
    open Signature_lib
    module U = Transaction_snark_tests.Util
    module Spec = Transaction_snark.For_tests.Update_states_spec
    include Transaction_snark_tests.Test_zkapp_update.Make (Test_input)

    let `VK vk, `Prover zkapp_prover = Lazy.force U.trivial_zkapp

    let snapp_update ~perm_after =
      { Account_update.Update.dummy with
        permissions =
          Zkapp_basic.Set_or_keep.Set
            { Permissions.user_default with
              set_verification_key =
                (perm_after, Mina_numbers.Txn_version.current)
            }
      }

    let older_version =
      let oldest = Mina_numbers.Txn_version.of_int 1 in
      if Mina_numbers.Txn_version.equal_to_current oldest then
        failwith "already oldest version"
      else oldest

    let mk_update_perm_check ~perm_after () =
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          let fee = Fee.of_nanomina_int_exn 1_000_000 in
          let amount = Amount.of_mina_int_exn 10 in
          let spec = List.hd_exn specs in
          let test_spec : Spec.t =
            { sender = spec.sender
            ; fee
            ; fee_payer = None
            ; receivers = []
            ; amount
            ; zkapp_account_keypairs = [ new_kp ]
            ; memo = Signed_command_memo.dummy
            ; new_zkapp_account = false
            ; snapp_update = snapp_update ~perm_after
            ; current_auth = Signature
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
            ; preconditions = None
            }
          in
          U.test_snapp_update
            ~snapp_permissions:
              (U.permissions_from_update (snapp_update ~perm_after)
                 ~auth:Signature ~txn_version:older_version )
            test_spec ~init_ledger ~vk ~zkapp_prover
            ~snapp_pk:(Public_key.compress new_kp.public_key) )

    let%test_unit "change verification key perm to Signature and bump txn \
                   version" =
      mk_update_perm_check ~perm_after:Signature ()

    let%test_unit "change verification key perm to Proof and bump txn version" =
      mk_update_perm_check ~perm_after:Proof ()

    let%test_unit "change verification key perm to Impossible and bump txn \
                   version" =
      mk_update_perm_check ~perm_after:Impossible ()

    let%test_unit "change verification key perm to Either and bump txn version"
        =
      mk_update_perm_check ~perm_after:Either ()

    let () =
      match Sys.getenv_opt "PROOF_CACHE_OUT" with
      | Some path ->
          Yojson.Safe.to_file path @@ Pickles.Proof_cache.to_yojson proof_cache
      | None ->
          ()
  end )
