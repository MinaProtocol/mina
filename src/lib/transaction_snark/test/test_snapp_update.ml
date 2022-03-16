open Core
open Mina_ledger
open Currency
open Signature_lib
module U = Util
module Spec = Transaction_snark.For_tests.Spec
open Mina_base

module type Input_intf = sig
  (*Spec for all the updates to generate a parties transaction*)
  val snapp_update : Party.Update.t

  val test_description : string
end

module T = U.T

module Make (Input : Input_intf) = struct
  open Input

  let `VK vk, `Prover snapp_prover = Lazy.force U.trivial_snapp

  let memo = Signed_command_memo.create_from_string_exn test_description

  let%test_unit "update a snapp account with signature" =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs = _ }, new_kp) ->
        let fee = Fee.of_int 1_000_000 in
        let amount = Amount.of_int 10_000_000_000 in
        let test_spec : Spec.t =
          { sender = (new_kp, Mina_base.Account.Nonce.zero)
          ; fee
          ; receivers = []
          ; amount
          ; snapp_account_keypairs = [ new_kp ]
          ; memo
          ; new_snapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.Signature
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          }
        in
        U.test_snapp_update test_spec ~init_ledger ~vk ~snapp_prover
          ~snapp_pk:(Public_key.compress new_kp.public_key))

  let%test_unit "update a snapp account with proof" =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs = _ }, new_kp) ->
        let fee = Fee.of_int 1_000_000 in
        let amount = Amount.of_int 10_000_000_000 in
        let test_spec : Spec.t =
          { sender = (new_kp, Mina_base.Account.Nonce.zero)
          ; fee
          ; receivers = []
          ; amount
          ; snapp_account_keypairs = [ new_kp ]
          ; memo
          ; new_snapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.Proof
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          }
        in
        U.test_snapp_update
          ~snapp_permissions:
            (U.permissions_from_update snapp_update ~auth:Proof)
          test_spec ~init_ledger ~vk ~snapp_prover
          ~snapp_pk:(Public_key.compress new_kp.public_key))

  let%test_unit "update a snapp account with None permission" =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs }, new_kp) ->
        let fee = Fee.of_int 1_000_000 in
        let amount = Amount.of_int 10_000_000_000 in
        let spec = List.hd_exn specs in
        let test_spec : Spec.t =
          { sender = spec.sender
          ; fee
          ; receivers = []
          ; amount
          ; snapp_account_keypairs = [ new_kp ]
          ; memo
          ; new_snapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.None
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          }
        in
        U.test_snapp_update
          ~snapp_permissions:(U.permissions_from_update snapp_update ~auth:None)
          test_spec ~init_ledger ~vk ~snapp_prover
          ~snapp_pk:(Public_key.compress new_kp.public_key))

  let%test_unit "update a snapp account with None permission and Signature auth"
      =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs }, new_kp) ->
        let fee = Fee.of_int 1_000_000 in
        let amount = Amount.of_int 10_000_000_000 in
        let spec = List.hd_exn specs in
        let test_spec : Spec.t =
          { sender = spec.sender
          ; fee
          ; receivers = []
          ; amount
          ; snapp_account_keypairs = [ new_kp ]
          ; memo
          ; new_snapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.Signature
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          }
        in
        U.test_snapp_update
          ~snapp_permissions:(U.permissions_from_update snapp_update ~auth:None)
          test_spec ~init_ledger ~vk ~snapp_prover
          ~snapp_pk:(Public_key.compress new_kp.public_key))

  let%test_unit "update a snapp account with None permission and Proof auth" =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs }, new_kp) ->
        let fee = Fee.of_int 1_000_000 in
        let amount = Amount.of_int 10_000_000_000 in
        let spec = List.hd_exn specs in
        let test_spec : Spec.t =
          { sender = spec.sender
          ; fee
          ; receivers = []
          ; amount
          ; snapp_account_keypairs = [ new_kp ]
          ; memo
          ; new_snapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.Proof
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          }
        in
        U.test_snapp_update
          ~snapp_permissions:(U.permissions_from_update snapp_update ~auth:None)
          test_spec ~init_ledger ~vk ~snapp_prover
          ~snapp_pk:(Public_key.compress new_kp.public_key))

  let%test_unit "update a snapp account with Either permission and Signature \
                 auth" =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs }, new_kp) ->
        let fee = Fee.of_int 1_000_000 in
        let amount = Amount.of_int 10_000_000_000 in
        let spec = List.hd_exn specs in
        let test_spec : Spec.t =
          { sender = spec.sender
          ; fee
          ; receivers = []
          ; amount
          ; snapp_account_keypairs = [ new_kp ]
          ; memo
          ; new_snapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.Signature
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          }
        in
        U.test_snapp_update
          ~snapp_permissions:
            (U.permissions_from_update snapp_update ~auth:Either)
          test_spec ~init_ledger ~vk ~snapp_prover
          ~snapp_pk:(Public_key.compress new_kp.public_key))

  let%test_unit "update a snapp account with Either permission and Proof auth" =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs }, new_kp) ->
        let fee = Fee.of_int 1_000_000 in
        let amount = Amount.of_int 10_000_000_000 in
        let spec = List.hd_exn specs in
        let test_spec : Spec.t =
          { sender = spec.sender
          ; fee
          ; receivers = []
          ; amount
          ; snapp_account_keypairs = [ new_kp ]
          ; memo
          ; new_snapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.Proof
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          }
        in
        U.test_snapp_update
          ~snapp_permissions:
            (U.permissions_from_update snapp_update ~auth:Either)
          test_spec ~init_ledger ~vk ~snapp_prover
          ~snapp_pk:(Public_key.compress new_kp.public_key))

  let%test_unit "update a snapp account with Either permission and None auth" =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs }, new_kp) ->
        let fee = Fee.of_int 1_000_000 in
        let amount = Amount.of_int 10_000_000_000 in
        let spec = List.hd_exn specs in
        let test_spec : Spec.t =
          { sender = spec.sender
          ; fee
          ; receivers = []
          ; amount
          ; snapp_account_keypairs = [ new_kp ]
          ; memo
          ; new_snapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.None
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          }
        in
        U.test_snapp_update
          ~snapp_permissions:
            (U.permissions_from_update snapp_update ~auth:Either)
          test_spec ~init_ledger ~vk ~snapp_prover
          ~snapp_pk:(Public_key.compress new_kp.public_key))

  let%test_unit "Update when not permitted but transaction is applied" =
    let open Mina_base.Transaction_logic.For_tests in
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs }, new_kp) ->
        Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
            let spec = List.hd_exn specs in
            let fee = Fee.of_int 1_000_000 in
            let amount = Amount.of_int 10_000_000_000 in
            let test_spec : Spec.t =
              { sender = spec.sender
              ; fee
              ; receivers = []
              ; amount
              ; snapp_account_keypairs = [ new_kp ]
              ; memo
              ; new_snapp_account = false
              ; snapp_update
              ; current_auth = Permissions.Auth_required.Signature
              ; call_data = Snark_params.Tick.Field.zero
              ; events = []
              ; sequence_events = []
              }
            in
            let snapp_pk = Public_key.compress new_kp.public_key in
            (*Ledger.apply_transaction should be successful if fee payer update
              is successful*)
            let parties =
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Transaction_snark.For_tests.update_states test_spec
                    ~snapp_prover ~constraint_constants)
            in
            Init_ledger.init (module Ledger.Ledger_inner) init_ledger ledger ;
            (*Create snapp transaction*)
            Transaction_snark.For_tests.create_trivial_snapp_account
              ~permissions:(U.permissions_from_update snapp_update ~auth:Proof)
              ~vk ~ledger snapp_pk ;
            ( match
                Ledger.apply_transaction ledger ~constraint_constants
                  ~txn_state_view:
                    (Mina_state.Protocol_state.Body.view U.state_body)
                  (Transaction.Command (Parties parties))
              with
            | Error e ->
                Error.raise e
            | Ok _ ->
                (*TODO: match the transaction status*) () ) ;
            (*generate snark*)
            U.test_snapp_update
              ~snapp_permissions:
                (U.permissions_from_update snapp_update ~auth:Proof)
              ~vk ~snapp_prover test_spec ~init_ledger ~snapp_pk))
end
