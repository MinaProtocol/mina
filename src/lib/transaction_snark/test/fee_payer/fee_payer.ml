open Core
open Mina_ledger
open Currency
open Signature_lib
module U = Transaction_snark_tests.Util
module Spec = Transaction_snark.For_tests.Update_states_spec
open Mina_base
open Mina_transaction

let%test_module "Fee payer tests" =
  ( module struct
    let `VK vk, `Prover zkapp_prover = Lazy.force U.trivial_zkapp

    let memo = Signed_command_memo.create_from_string_exn "Fee payer tests"

    let constraint_constants = U.constraint_constants

    let snapp_update : Account_update.Update.t =
      { Account_update.Update.dummy with
        app_state =
          Pickles_types.Vector.init Zkapp_state.Max_state_size.n ~f:(fun i ->
              Zkapp_basic.Set_or_keep.Set (Pickles.Backend.Tick.Field.of_int i) )
      }

    let%test_unit "update a snapp account with signature and fee paid by the \
                   snapp account" =
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

    let%test_unit "update a snapp account with signature and fee paid by a \
                   non-snapp account" =
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          let fee = Fee.of_nanomina_int_exn 1_000_000 in
          let amount = Amount.zero in
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
          U.test_snapp_update test_spec ~init_ledger ~vk ~zkapp_prover
            ~snapp_pk:(Public_key.compress new_kp.public_key) )

    let%test_unit "update a snapp account with proof and fee paid by the snapp \
                   account" =
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

    let%test_unit "update a snapp account with proof and fee paid by a \
                   non-snapp account" =
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
              (U.permissions_from_update snapp_update ~auth:Proof)
            test_spec ~init_ledger ~vk ~zkapp_prover
            ~snapp_pk:(Public_key.compress new_kp.public_key) )

    let%test_unit "snapp transaction with non-existent fee payer account" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:1
        Quickcheck.Generator.(tuple2 U.gen_snapp_ledger small_positive_int)
        ~f:(fun (({ init_ledger; specs }, new_kp), global_slot) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              let spec = List.hd_exn specs in
              let fee = Fee.of_nanomina_int_exn 1_000_000 in
              let amount = Amount.of_mina_int_exn 10 in
              (*making new_kp the fee-payer for this to fail*)
              let test_spec : Transaction_snark.For_tests.Deploy_snapp_spec.t =
                { sender = (new_kp, Account.Nonce.zero)
                ; fee
                ; fee_payer = None
                ; amount
                ; zkapp_account_keypairs = [ fst spec.sender ]
                ; memo
                ; new_zkapp_account = true
                ; snapp_update
                ; preconditions = None
                ; authorization_kind = Signature
                }
              in
              let zkapp_command =
                Transaction_snark.For_tests.deploy_snapp test_spec
                  ~constraint_constants
              in
              let txn_state_view =
                Mina_state.Protocol_state.Body.view U.genesis_state_body
              in
              let global_slot = Mina_numbers.Global_slot.of_int global_slot in
              Init_ledger.init (module Ledger.Ledger_inner) init_ledger ledger ;
              ( match
                  let mask = Ledger.Mask.create ~depth:U.ledger_depth () in
                  let ledger0 = Ledger.register_mask ledger mask in
                  Ledger.apply_transactions ledger0 ~constraint_constants
                    ~global_slot ~txn_state_view
                    [ Transaction.Command (Zkapp_command zkapp_command) ]
                with
              | Error _ ->
                  (*TODO : match on exact error*) ()
              | Ok _ ->
                  failwith "Ledger.apply_transaction should have failed" ) ;
              (*Sparse ledger application fails*)
              match
                let sparse_ledger =
                  Sparse_ledger.of_any_ledger
                    (Ledger.Any_ledger.cast
                       (module Ledger.Mask.Attached)
                       ledger )
                in
                Sparse_ledger.apply_transaction_first_pass ~constraint_constants
                  ~global_slot ~txn_state_view sparse_ledger
                  (Mina_transaction.Transaction.Command
                     (Zkapp_command zkapp_command) )
              with
              | Ok _a ->
                  failwith "Expected sparse ledger application to fail"
              | Error _e ->
                  () ) )
  end )
