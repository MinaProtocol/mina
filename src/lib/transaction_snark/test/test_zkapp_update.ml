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

  val failure_expected : Mina_base.Transaction_status.Failure.t * U.pass_number

  val is_non_zkapp_update : bool
end

module Make (Input : Input_intf) = struct
  open Input

  let `VK vk, `Prover zkapp_prover = Lazy.force U.trivial_zkapp

  let memo = Signed_command_memo.create_from_string_exn test_description

  let%test_unit "update a snapp account with signature" =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs = _ }, new_kp) ->
        let fee = Fee.of_nanomina_int_exn 1_000_000 in
        let amount = Amount.of_mina_int_exn 10 in
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
          ; actions = []
          ; preconditions = None
          }
        in
        U.test_snapp_update test_spec ~init_ledger ~vk ~zkapp_prover
          ~snapp_pk:(Public_key.compress new_kp.public_key) )

  let%test_unit "update a snapp account with proof" =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs = _ }, new_kp) ->
        let fee = Fee.of_nanomina_int_exn 1_000_000 in
        let amount = Amount.of_mina_int_exn 10 in
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
          ; actions = []
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
          ; current_auth = Permissions.Auth_required.None
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; actions = []
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
          ; current_auth = Permissions.Auth_required.Signature
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; actions = []
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
          ; current_auth = Permissions.Auth_required.Proof
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; actions = []
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
          ; current_auth = Permissions.Auth_required.Signature
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; actions = []
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
          ; current_auth = Permissions.Auth_required.Proof
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; actions = []
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
          ; current_auth = Permissions.Auth_required.None
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; actions = []
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
              ; snapp_update
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
              ~permissions:(U.permissions_from_update snapp_update ~auth:Proof)
              ~vk ~ledger snapp_pk ;
            (*Ledger.apply_transaction should be successful if fee payer update
              is successful*)
            U.test_snapp_update ~expected_failure:failure_expected
              ~snapp_permissions:
                (U.permissions_from_update snapp_update ~auth:Proof)
              ~vk ~zkapp_prover test_spec ~init_ledger ~snapp_pk ) )

  let test_non_zkapp_to_zkapp ?(new_account = true) test_spec init_ledger
      (zkapp_kp : Keypair.t) =
    let open Mina_transaction_logic.For_tests in
    let get_account ledger id =
      let location = Option.value_exn (Ledger.location_of_account ledger id) in
      Option.value_exn (Ledger.get ledger location)
    in
    Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
        Async.Thread_safe.block_on_async_exn (fun () ->
            let open Async.Deferred.Let_syntax in
            (*Create non-zkapp accounts*)
            Init_ledger.init ~zkapp:false
              (module Ledger.Ledger_inner)
              init_ledger ledger ;
            let zkapp_acc_id =
              Account_id.create
                (Public_key.compress zkapp_kp.public_key)
                Token_id.default
            in
            let%bind zkapp_command =
              let zkapp_prover_and_vk = (zkapp_prover, vk) in
              Transaction_snark.For_tests.update_states ~zkapp_prover_and_vk
                ~constraint_constants:U.constraint_constants test_spec
            in
            ( if new_account then
              ignore
                ( Option.value_map
                    ~f:(fun location ->
                      Some (Option.value_exn (Ledger.get ledger location)) )
                    ~default:None
                    (Ledger.location_of_account ledger zkapp_acc_id)
                  : Account.t option )
            else
              let account = get_account ledger zkapp_acc_id in
              assert (Option.is_none account.zkapp) ) ;
            let%map () =
              U.check_zkapp_command_with_merges_exn ledger [ zkapp_command ]
            in
            let account = get_account ledger zkapp_acc_id in
            if is_non_zkapp_update then
              (*zkapp field should be not be set*)
              assert (Option.is_none account.zkapp)
            else assert (Option.is_some account.zkapp) ) )

  let%test_unit "update a new non-zkapp account specified update" =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs }, new_kp) ->
        let fee = Fee.of_nanomina_int_exn 1_000_000 in
        let amount =
          Amount.of_fee U.constraint_constants.account_creation_fee
        in
        let spec = List.hd_exn specs in
        let test_spec : Spec.t =
          { sender = spec.sender
          ; fee
          ; fee_payer = None
          ; receivers = []
          ; amount
          ; zkapp_account_keypairs = [ new_kp ]
          ; memo
          ; new_zkapp_account = true
          ; snapp_update
          ; current_auth = Permissions.Auth_required.Signature
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; actions = []
          ; preconditions = None
          }
        in
        test_non_zkapp_to_zkapp test_spec init_ledger new_kp )

  let%test_unit "Update an existing non-zkapp account with the specified update"
      =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs }, _new_kp) ->
        let fee = Fee.of_nanomina_int_exn 1_000_000 in
        let amount = Amount.zero in
        let spec = List.hd_exn specs in
        let test_spec : Spec.t =
          { sender = spec.sender
          ; fee
          ; fee_payer = None
          ; receivers = []
          ; amount
          ; zkapp_account_keypairs = [ fst spec.sender ]
          ; memo
          ; new_zkapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.Signature
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; actions = []
          ; preconditions = None
          }
        in
        test_non_zkapp_to_zkapp ~new_account:false test_spec init_ledger
          (fst spec.sender) )
end
