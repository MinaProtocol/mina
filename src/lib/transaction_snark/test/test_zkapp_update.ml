open Core
open Mina_ledger
open Currency
open Signature_lib
module U = Util
module Spec = Transaction_snark.For_tests.Update_states_spec
open Mina_base

module type Input_intf = sig
  (*Spec for all the updates to generate a zkapp_command transaction*)
  val snapp_update : Account_update.Update.t

  val test_description : string

  val failure_expected : Mina_base.Transaction_status.Failure.t
end

module Make (Input : Input_intf) = struct
  open Input

  let `VK vk, `Prover zkapp_prover = Lazy.force U.trivial_zkapp

  let memo = Signed_command_memo.create_from_string_exn test_description

  let%test_unit "update a snapp account with signature" =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs = _ }, new_kp) ->
        let fee = Fee.nanomina_unsafe 1_000_000 in
        let amount = Amount.mina_unsafe 10 in
        let test_spec : Spec.t =
          { sender = (new_kp, Mina_base.Account.Nonce.zero)
          ; fee
          ; fee_payer = None
          ; receivers = []
          ; amount
          ; zkapp_account_keypairs = [ new_kp ]
          ; memo
          ; new_zkapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.Signature
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          ; preconditions = None
          }
        in
        U.test_snapp_update test_spec ~init_ledger ~vk ~zkapp_prover
          ~snapp_pk:(Public_key.compress new_kp.public_key) )

  let%test_unit "update a snapp account with proof" =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs = _ }, new_kp) ->
        let fee = Fee.nanomina_unsafe 1_000_000 in
        let amount = Amount.mina_unsafe 10 in
        let test_spec : Spec.t =
          { sender = (new_kp, Mina_base.Account.Nonce.zero)
          ; fee
          ; fee_payer = None
          ; receivers = []
          ; amount
          ; zkapp_account_keypairs = [ new_kp ]
          ; memo
          ; new_zkapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.Proof
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          ; preconditions = None
          }
        in
        U.test_snapp_update
          ~snapp_permissions:
            (U.permissions_from_update snapp_update ~auth:Proof)
          test_spec ~init_ledger ~vk ~zkapp_prover
          ~snapp_pk:(Public_key.compress new_kp.public_key) )

  let%test_unit "update a snapp account with None permission" =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs }, new_kp) ->
        let fee = Fee.nanomina_unsafe 1_000_000 in
        let amount = Amount.mina_unsafe 10 in
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
          ; current_auth = Permissions.Auth_required.None
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          ; preconditions = None
          }
        in
        U.test_snapp_update
          ~snapp_permissions:(U.permissions_from_update snapp_update ~auth:None)
          test_spec ~init_ledger ~vk ~zkapp_prover
          ~snapp_pk:(Public_key.compress new_kp.public_key) )

  let%test_unit "update a snapp account with None permission and Signature auth"
      =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs }, new_kp) ->
        let fee = Fee.nanomina_unsafe 1_000_000 in
        let amount = Amount.mina_unsafe 10 in
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
          ; current_auth = Permissions.Auth_required.Signature
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          ; preconditions = None
          }
        in
        U.test_snapp_update
          ~snapp_permissions:(U.permissions_from_update snapp_update ~auth:None)
          test_spec ~init_ledger ~vk ~zkapp_prover
          ~snapp_pk:(Public_key.compress new_kp.public_key) )

  let%test_unit "update a snapp account with None permission and Proof auth" =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs }, new_kp) ->
        let fee = Fee.nanomina_unsafe 1_000_000 in
        let amount = Amount.mina_unsafe 10 in
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
          ; current_auth = Permissions.Auth_required.Proof
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          ; preconditions = None
          }
        in
        U.test_snapp_update
          ~snapp_permissions:(U.permissions_from_update snapp_update ~auth:None)
          test_spec ~init_ledger ~vk ~zkapp_prover
          ~snapp_pk:(Public_key.compress new_kp.public_key) )

  let%test_unit "update a snapp account with Either permission and Signature \
                 auth" =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs }, new_kp) ->
        let fee = Fee.nanomina_unsafe 1_000_000 in
        let amount = Amount.mina_unsafe 10 in
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
          ; current_auth = Permissions.Auth_required.Signature
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          ; preconditions = None
          }
        in
        U.test_snapp_update
          ~snapp_permissions:
            (U.permissions_from_update snapp_update ~auth:Either)
          test_spec ~init_ledger ~vk ~zkapp_prover
          ~snapp_pk:(Public_key.compress new_kp.public_key) )

  let%test_unit "update a snapp account with Either permission and Proof auth" =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs }, new_kp) ->
        let fee = Fee.nanomina_unsafe 1_000_000 in
        let amount = Amount.mina_unsafe 10 in
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
          ; current_auth = Permissions.Auth_required.Proof
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          ; preconditions = None
          }
        in
        U.test_snapp_update
          ~snapp_permissions:
            (U.permissions_from_update snapp_update ~auth:Either)
          test_spec ~init_ledger ~vk ~zkapp_prover
          ~snapp_pk:(Public_key.compress new_kp.public_key) )

  let%test_unit "update a snapp account with Either permission and None auth" =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs }, new_kp) ->
        let fee = Fee.nanomina_unsafe 1_000_000 in
        let amount = Amount.mina_unsafe 10_000_000_000 in
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
          ; current_auth = Permissions.Auth_required.None
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          ; preconditions = None
          }
        in
        U.test_snapp_update ~expected_failure:failure_expected
          ~snapp_permissions:
            (U.permissions_from_update snapp_update ~auth:Either)
          test_spec ~init_ledger ~vk ~zkapp_prover
          ~snapp_pk:(Public_key.compress new_kp.public_key) )

  let%test_unit "Update when not permitted but transaction is applied" =
    let open Mina_transaction_logic.For_tests in
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs }, new_kp) ->
        Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
            let spec = List.hd_exn specs in
            let fee = Fee.nanomina_unsafe 1_000_000 in
            let amount = Amount.mina_unsafe 10_000_000_000 in
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
              ; current_auth = Permissions.Auth_required.Signature
              ; call_data = Snark_params.Tick.Field.zero
              ; events = []
              ; sequence_events = []
              ; preconditions = None
              }
            in
            let snapp_pk = Public_key.compress new_kp.public_key in
            Init_ledger.init (module Ledger.Ledger_inner) init_ledger ledger ;
            (*Create snapp transaction*)
            Transaction_snark.For_tests.create_trivial_zkapp_account
              ~permissions:(U.permissions_from_update snapp_update ~auth:Proof)
              ~vk ~ledger snapp_pk ;
            (*Ledger.apply_transaction should be successful if fee payer update
              is successful*)
            U.test_snapp_update ~expected_failure:failure_expected
              ~snapp_permissions:
                (U.permissions_from_update snapp_update ~auth:Proof)
              ~vk ~zkapp_prover test_spec ~init_ledger ~snapp_pk ) )
end
