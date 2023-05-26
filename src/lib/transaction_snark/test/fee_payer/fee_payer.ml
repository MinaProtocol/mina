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

    let test_empty_update ?(new_account = true) test_spec init_ledger
        (zkapp_kp : Keypair.t) =
      let open Mina_transaction_logic.For_tests in
      let get_account ledger id =
        let location =
          Option.value_exn (Ledger.location_of_account ledger id)
        in
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
                  ~constraint_constants test_spec
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
              assert (Option.is_none account.zkapp) ) )

    let%test_unit "unchanged zkapp field when zkapp update is noop" =
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          let fee = Fee.of_nanomina_int_exn 1_000_000 in
          let amount =
            Amount.of_fee U.constraint_constants.account_creation_fee
          in
          let spec = List.hd_exn specs in
          let new_account_spec : Spec.t =
            { sender = spec.sender
            ; fee
            ; fee_payer = None
            ; receivers = []
            ; amount
            ; zkapp_account_keypairs = [ new_kp ]
            ; memo
            ; new_zkapp_account = true
            ; snapp_update = Account_update.Update.dummy
            ; current_auth = Permissions.Auth_required.Signature
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
            ; preconditions = None
            }
          in
          test_empty_update new_account_spec init_ledger new_kp ;
          let existing_account_spec =
            { new_account_spec with
              amount = Amount.zero
            ; zkapp_account_keypairs = [ fst spec.sender ]
            ; new_zkapp_account = false
            }
          in
          test_empty_update ~new_account:false existing_account_spec init_ledger
            (fst spec.sender) )

    let%test_unit "No account updates, only fee payer in a zkapp transaction" =
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, _new_kp) ->
          let fee = Fee.of_nanomina_int_exn 1_000_000 in
          let spec = List.hd_exn specs in
          let test_spec : Spec.t =
            { sender = spec.sender
            ; fee
            ; fee_payer = None
            ; receivers = []
            ; amount = Amount.zero
            ; zkapp_account_keypairs = []
            ; memo
            ; new_zkapp_account = false
            ; snapp_update = Account_update.Update.dummy
            ; current_auth = Permissions.Auth_required.Signature
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
            ; preconditions = None
            }
          in
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Mina_transaction_logic.For_tests.Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  let open Async.Deferred.Let_syntax in
                  let%bind zkapp_command =
                    let zkapp_prover_and_vk = (zkapp_prover, vk) in
                    Transaction_snark.For_tests.update_states
                      ~zkapp_prover_and_vk ~constraint_constants test_spec
                  in
                  assert (
                    List.is_empty
                      (Zkapp_command.account_updates_list zkapp_command) ) ;
                  U.check_zkapp_command_with_merges_exn ledger [ zkapp_command ] ) ) )
  end )
