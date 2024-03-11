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

let%test_module "Update account verification key" =
  ( module struct
    let proof_cache =
      Result.ok_or_failwith @@ Pickles.Proof_cache.of_yojson
      @@ Yojson.Safe.from_file "proof_cache.json"

    let () = Transaction_snark.For_tests.set_proof_cache proof_cache

    include Transaction_snark_tests.Test_zkapp_update.Make (Test_input)
    open Currency
    open Signature_lib
    module U = Transaction_snark_tests.Util
    module Spec = Transaction_snark.For_tests.Update_states_spec
    open Test_input

    let `VK vk, `Prover zkapp_prover = Lazy.force U.trivial_zkapp

    let mk_update_perm_check ~current_auth ~account_perm ?txn_version
        ?failure_expected () =
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
            ; memo
            ; new_zkapp_account = false
            ; snapp_update
            ; current_auth
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
            ; preconditions = None
            }
          in
          U.test_snapp_update ?expected_failure:failure_expected
            ~snapp_permissions:
              (U.permissions_from_update snapp_update ~auth:account_perm
                 ?txn_version )
            test_spec ~init_ledger ~vk ~zkapp_prover
            ~snapp_pk:(Public_key.compress new_kp.public_key) )

    let older_version =
      let oldest = Mina_numbers.Txn_version.of_int 1 in
      if Mina_numbers.Txn_version.equal_to_current oldest then
        failwith "already oldest version"
      else oldest

    let%test_unit "account update using Signature auth when perm is set to \
                   Proof" =
      mk_update_perm_check ~current_auth:Signature ~account_perm:Proof
        ~txn_version:older_version ()

    let%test_unit "account update using Signature auth when perm is set to \
                   Impossible" =
      mk_update_perm_check ~current_auth:Signature ~account_perm:Impossible
        ~txn_version:older_version ()

    let%test_unit "account update using Proof auth when perm is set to Proof" =
      mk_update_perm_check ~current_auth:Proof ~account_perm:Proof
        ~txn_version:older_version ~failure_expected:Test_input.failure_expected
        ()

    let%test_unit "account update using Proof auth when perm is set to Either" =
      mk_update_perm_check ~current_auth:Proof ~account_perm:Either
        ~txn_version:older_version ()

    let () =
      match Sys.getenv_opt "PROOF_CACHE_OUT" with
      | Some path ->
          Yojson.Safe.to_file path @@ Pickles.Proof_cache.to_yojson proof_cache
      | None ->
          ()
  end )
