open Core
open Currency
open Signature_lib
module U = Transaction_snark_tests.Util
module Spec = Transaction_snark.For_tests.Spec
open Mina_base

let%test_module "Protocol state precondition tests" =
  ( module struct
    let `VK vk, `Prover snapp_prover = Lazy.force U.trivial_snapp

    let memo =
      Signed_command_memo.create_from_string_exn "protocol state precondition"

    let snapp_update : Party.Update.t =
      { Party.Update.dummy with
        app_state =
          Pickles_types.Vector.init Zkapp_state.Max_state_size.n ~f:(fun i ->
              Zkapp_basic.Set_or_keep.Set (Pickles.Backend.Tick.Field.of_int i))
      }

    let _precondition_exact
        (protocol_state : Zkapp_precondition.Protocol_state.View.t) =
      let open Mina_base.Zkapp_basic.Or_ignore in
      let open Zkapp_precondition in
      let interval v =
        { Closed_interval.lower = v; Closed_interval.upper = v }
      in
      let epoch_data (e : _ Zkapp_precondition.Protocol_state.Epoch_data.Poly.t)
          =
        { Zkapp_precondition.Protocol_state.Epoch_data.Poly.ledger =
            { Mina_base.Epoch_ledger.Poly.hash =
                Check e.ledger.Epoch_ledger.Poly.hash
            ; total_currency = Check (interval e.ledger.total_currency)
            }
        ; seed = Check e.seed
        ; start_checkpoint = Check e.start_checkpoint
        ; lock_checkpoint = Check e.lock_checkpoint
        ; epoch_length = Check (interval e.epoch_length)
        }
      in
      { Zkapp_precondition.Protocol_state.Poly.snarked_ledger_hash =
          Check protocol_state.snarked_ledger_hash
      ; timestamp = Check (interval protocol_state.timestamp)
      ; blockchain_length = Check (interval protocol_state.blockchain_length)
      ; min_window_density = Check (interval protocol_state.min_window_density)
      ; last_vrf_output = ()
      ; total_currency = Check (interval protocol_state.total_currency)
      ; global_slot_since_hard_fork =
          Check (interval protocol_state.global_slot_since_hard_fork)
      ; global_slot_since_genesis =
          Check (interval protocol_state.global_slot_since_genesis)
      ; staking_epoch_data = epoch_data protocol_state.staking_epoch_data
      ; next_epoch_data = epoch_data protocol_state.next_epoch_data
      }

    let%test_unit "exact protocol state predicate" =
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          printf "Starting test\n%!" ;
          let state_body = U.genesis_state_body in
          let fee = Fee.of_int 1_000_000 in
          let _amount = Amount.of_int 10_000_000_000 in
          let spec = List.hd_exn specs in
          let test_spec : Spec.t =
            { sender =
                spec.sender
                (* TODO: Transaction application passes when we do this and protocol preconditon is accept (new_kp, Mina_base.Account.Nonce.zero)*)
            ; fee
            ; receivers = []
            ; amount = Amount.zero
            ; zkapp_account_keypairs = [ new_kp ]
            ; memo
            ; new_zkapp_account = false
            ; snapp_update
            ; current_auth = Permissions.Auth_required.Signature
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; sequence_events = []
            ; protocol_state_precondition =
                Some
                  (_precondition_exact
                     (Mina_state.Protocol_state.Body.view state_body))
            ; account_precondition = None
            }
          in
          U.test_snapp_update test_spec ~state_body ~init_ledger ~vk
            ~snapp_prover
            ~snapp_pk:(Public_key.compress new_kp.public_key))

    (*let%test_unit "update a snapp account with signature and fee paid by a \
                     non-snapp account" =
        Quickcheck.test ~trials:1 U.gen_snapp_ledger
          ~f:(fun ({ init_ledger; specs }, new_kp) ->
            let state_body = Util.genesis_state_body in
            let fee = Fee.of_int 1_000_000 in
            let amount = Amount.zero in
            let spec = List.hd_exn specs in
            let test_spec : Spec.t =
              { sender = spec.sender
              ; fee
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
          ; protocol_state_precondition=Some (precondition_exact (Mina_state.Protocol_state.Body.view state_body))
          ; account_precondition=None
              }
            in
            U.test_snapp_update test_spec ~state_body ~init_ledger ~vk ~snapp_prover
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
          ; protocol_state_precondition=None
          ; account_precondition=None
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
          ; protocol_state_precondition=None
          ; account_precondition=None
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
          ; protocol_state_precondition=None
          ; account_precondition=None
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
                    ()))*)
  end )
