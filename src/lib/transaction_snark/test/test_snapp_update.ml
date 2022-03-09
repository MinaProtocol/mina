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

  let test_snapp_update ?snapp_permissions test_spec ~init_ledger ~snapp_pk =
    let open Transaction_logic.For_tests in
    Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
        Async.Thread_safe.block_on_async_exn (fun () ->
            Init_ledger.init (module Ledger.Ledger_inner) init_ledger ledger ;
            (*create a snapp account*)
            Transaction_snark.For_tests.create_trivial_snapp_account
              ?permissions:snapp_permissions ~vk ~ledger snapp_pk ;
            let open Async.Deferred.Let_syntax in
            let%bind parties =
              Transaction_snark.For_tests.update_state ~snapp_prover
                ~constraint_constants test_spec
            in
            U.apply_parties_with_merges ledger [ parties ]))

  let permissions_from_updates (update : Party.Update.t) ~auth =
    let default = Permissions.user_default in
    { default with
      edit_state =
        ( if
          Snapp_state.V.to_list update.app_state
          |> List.exists ~f:Snapp_basic.Set_or_keep.is_set
        then auth
        else default.edit_state )
    ; set_delegate =
        ( if Snapp_basic.Set_or_keep.is_keep update.delegate then
          default.set_delegate
        else auth )
    ; set_verification_key =
        ( if Snapp_basic.Set_or_keep.is_keep update.verification_key then
          default.set_verification_key
        else auth )
    ; set_permissions =
        ( if Snapp_basic.Set_or_keep.is_keep update.permissions then
          default.set_permissions
        else auth )
    ; set_snapp_uri =
        ( if Snapp_basic.Set_or_keep.is_keep update.snapp_uri then
          default.set_snapp_uri
        else auth )
    ; set_token_symbol =
        ( if Snapp_basic.Set_or_keep.is_keep update.token_symbol then
          default.set_token_symbol
        else auth )
    ; set_voting_for =
        ( if Snapp_basic.Set_or_keep.is_keep update.voting_for then
          default.set_voting_for
        else auth )
    }

  let memo = Signed_command_memo.create_from_string_exn test_description

  let%test_unit "update a snapp account with signature and fee paid by the \
                 snapp account" =
    Quickcheck.test ~trials:1 U.gen_snapp_ledger
      ~f:(fun ({ init_ledger; specs = _ }, new_kp) ->
        let fee = Fee.of_int 1_000_000 in
        let amount = Amount.of_int 10_000_000_000 in
        let test_spec : Spec.t =
          { sender = (new_kp, Mina_base.Account.Nonce.zero)
          ; fee
          ; receivers = []
          ; amount
          ; snapp_account_keypair = Some new_kp
          ; memo
          ; new_snapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.Signature
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          }
        in
        test_snapp_update test_spec ~init_ledger
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
          ; receivers = []
          ; amount
          ; snapp_account_keypair = Some new_kp
          ; memo
          ; new_snapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.Signature
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          }
        in
        test_snapp_update test_spec ~init_ledger
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
          ; snapp_account_keypair = Some new_kp
          ; memo
          ; new_snapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.Proof
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          }
        in
        test_snapp_update
          ~snapp_permissions:(permissions_from_updates snapp_update ~auth:Proof)
          test_spec ~init_ledger
          ~snapp_pk:(Public_key.compress new_kp.public_key))

  let%test_unit "update a snapp account with proof and fee paid by a non-snapp \
                 account" =
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
          ; snapp_account_keypair = Some new_kp
          ; memo
          ; new_snapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.Proof
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          }
        in
        test_snapp_update
          ~snapp_permissions:(permissions_from_updates snapp_update ~auth:Proof)
          test_spec ~init_ledger
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
          ; snapp_account_keypair = Some new_kp
          ; memo
          ; new_snapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.None
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          }
        in
        test_snapp_update
          ~snapp_permissions:(permissions_from_updates snapp_update ~auth:None)
          test_spec ~init_ledger
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
          ; snapp_account_keypair = Some new_kp
          ; memo
          ; new_snapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.Signature
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          }
        in
        test_snapp_update
          ~snapp_permissions:(permissions_from_updates snapp_update ~auth:None)
          test_spec ~init_ledger
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
          ; snapp_account_keypair = Some new_kp
          ; memo
          ; new_snapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.Proof
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          }
        in
        test_snapp_update
          ~snapp_permissions:(permissions_from_updates snapp_update ~auth:None)
          test_spec ~init_ledger
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
          ; snapp_account_keypair = Some new_kp
          ; memo
          ; new_snapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.Signature
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          }
        in
        test_snapp_update
          ~snapp_permissions:
            (permissions_from_updates snapp_update ~auth:Either)
          test_spec ~init_ledger
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
          ; snapp_account_keypair = Some new_kp
          ; memo
          ; new_snapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.Proof
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          }
        in
        test_snapp_update
          ~snapp_permissions:
            (permissions_from_updates snapp_update ~auth:Either)
          test_spec ~init_ledger
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
          ; snapp_account_keypair = Some new_kp
          ; memo
          ; new_snapp_account = false
          ; snapp_update
          ; current_auth = Permissions.Auth_required.None
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; sequence_events = []
          }
        in
        test_snapp_update
          ~snapp_permissions:
            (permissions_from_updates snapp_update ~auth:Either)
          test_spec ~init_ledger
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
              ; snapp_account_keypair = Some new_kp
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
            (*Ledger.apply_transaction should be applied if fee payer update is successfull*)
            let parties =
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Transaction_snark.For_tests.update_state test_spec
                    ~snapp_prover ~constraint_constants)
            in
            Init_ledger.init (module Ledger.Ledger_inner) init_ledger ledger ;
            (*Create snapp transaction*)
            Transaction_snark.For_tests.create_trivial_snapp_account
              ~permissions:(permissions_from_updates snapp_update ~auth:Proof)
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
            test_snapp_update
              ~snapp_permissions:
                (permissions_from_updates snapp_update ~auth:Proof)
              test_spec ~init_ledger ~snapp_pk))

  let%test_unit "snapp transaction with non-existent fee payer account" =
    let open Mina_base.Transaction_logic.For_tests in
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
              ; snapp_account_keypair = Some (fst spec.sender)
              ; memo
              ; new_snapp_account = true
              ; snapp_update
              ; current_auth = Permissions.Auth_required.Signature
              ; call_data = Snark_params.Tick.Field.zero
              ; events = []
              ; sequence_events = []
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
                    (Mina_state.Protocol_state.Body.view U.state_body)
                  (Transaction.Command (Parties parties))
              with
            | Error _ ->
                (*TODO : match on exact error*) ()
            | Ok _ ->
                failwith "Ledger.apply_transaction should have failed" ) ;
            (*Sparse ledger application fails*)
            match
              Or_error.try_with (fun () ->
                  Transaction_snark.parties_witnesses_exn ~constraint_constants
                    ~state_body:U.state_body ~fee_excess:Amount.Signed.zero
                    ~pending_coinbase_init_stack:U.init_stack (`Ledger ledger)
                    [ parties ])
            with
            | Ok _a ->
                failwith "Expected sparse ledger application to fail"
            | Error _e ->
                ()))
end
