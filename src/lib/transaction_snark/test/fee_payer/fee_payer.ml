open Core
open Mina_ledger
open Currency
open Signature_lib
module U = Transaction_snark_tests.Util
module Spec = Transaction_snark.For_tests.Spec
open Mina_base
open Mina_transaction

let%test_module "Fee payer tests" =
  ( module struct
    let `VK vk, `Prover snapp_prover = Lazy.force U.trivial_zkapp

    let memo = Signed_command_memo.create_from_string_exn "Fee payer tests"

    let constraint_constants = U.constraint_constants

    let snapp_update : Party.Update.t =
      { Party.Update.dummy with
        app_state =
          Pickles_types.Vector.init Zkapp_state.Max_state_size.n ~f:(fun i ->
              Zkapp_basic.Set_or_keep.Set (Pickles.Backend.Tick.Field.of_int i))
      }

    let%test_unit "update a snapp account with signature and fee paid by the \
                   snapp account" =
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs = _ }, new_kp) ->
          let fee = Fee.of_int 1_000_000 in
          let amount = Amount.of_int 10_000_000_000 in
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
            ; protocol_state_precondition = None
            ; account_precondition = None
            }
          in
          U.test_snapp_update test_spec ~init_ledger ~vk ~snapp_prover
            ~snapp_pk:(Public_key.compress new_kp.public_key))

    let%test_unit "update a snapp account with signature and fee paid by a \
                   non-snapp account" =
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          let fee = Fee.of_int 1_000_000 in
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
            ; sequence_events = []
            ; protocol_state_precondition = None
            ; account_precondition = None
            }
          in
          U.test_snapp_update test_spec ~init_ledger ~vk ~snapp_prover
            ~snapp_pk:(Public_key.compress new_kp.public_key))

    let%test_unit "update a snapp account with proof and fee paid by the snapp \
                   account" =
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs = _ }, new_kp) ->
          let fee = Fee.of_int 1_000_000 in
          let amount = Amount.of_int 10_000_000_000 in
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
            ; protocol_state_precondition = None
            ; account_precondition = None
            }
          in
          U.test_snapp_update
            ~snapp_permissions:
              (U.permissions_from_update snapp_update ~auth:Proof)
            test_spec ~init_ledger ~vk ~snapp_prover
            ~snapp_pk:(Public_key.compress new_kp.public_key))

    let%test_unit "update a snapp account with proof and fee paid by a \
                   non-snapp account" =
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          let fee = Fee.of_int 1_000_000 in
          let amount = Amount.of_int 10_000_000_000 in
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
            ; protocol_state_precondition = None
            ; account_precondition = None
            }
          in
          U.test_snapp_update
            ~snapp_permissions:
              (U.permissions_from_update snapp_update ~auth:Proof)
            test_spec ~init_ledger ~vk ~snapp_prover
            ~snapp_pk:(Public_key.compress new_kp.public_key))

    let%test_unit "snapp transaction with non-existent fee payer account" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              let spec = List.hd_exn specs in
              let fee = Fee.of_int 1_000_000 in
              let amount = Amount.of_int 10_000_000_000 in
              (*making new_kp the fee-payer for this to fail*)
              let test_spec : Spec.t =
                { sender = (new_kp, Account.Nonce.zero)
                ; fee
                ; fee_payer = None
                ; receivers = []
                ; amount
                ; zkapp_account_keypairs = [ fst spec.sender ]
                ; memo
                ; new_zkapp_account = true
                ; snapp_update
                ; current_auth = Permissions.Auth_required.Signature
                ; call_data = Snark_params.Tick.Field.zero
                ; events = []
                ; sequence_events = []
                ; protocol_state_precondition = None
                ; account_precondition = None
                }
              in
              let parties =
                Transaction_snark.For_tests.deploy_snapp test_spec
                  ~constraint_constants
              in
              Init_ledger.init (module Ledger.Ledger_inner) init_ledger ledger ;
              ( match
                  let mask = Ledger.Mask.create ~depth:U.ledger_depth () in
                  let ledger0 = Ledger.register_mask ledger mask in
                  Ledger.apply_transaction ledger0 ~constraint_constants
                    ~txn_state_view:
                      (Mina_state.Protocol_state.Body.view U.genesis_state_body)
                    (Transaction.Command (Parties parties))
                with
              | Error _ ->
                  (*TODO : match on exact error*) ()
              | Ok _ ->
                  failwith "Ledger.apply_transaction should have failed" ) ;
              (*Sparse ledger application fails*)
              match
                Or_error.try_with (fun () ->
                    Transaction_snark.parties_witnesses_exn
                      ~constraint_constants ~state_body:U.genesis_state_body
                      ~fee_excess:Amount.Signed.zero (`Ledger ledger)
                      [ ( `Pending_coinbase_init_stack U.init_stack
                        , `Pending_coinbase_of_statement
                            (U.pending_coinbase_state_stack
                               ~state_body_hash:U.genesis_state_body_hash)
                        , parties )
                      ])
              with
              | Ok _a ->
                  failwith "Expected sparse ledger application to fail"
              | Error _e ->
                  ()))
  end )
