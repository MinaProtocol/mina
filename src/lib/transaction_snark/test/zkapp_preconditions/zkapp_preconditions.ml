open Core_kernel
open Currency
open Signature_lib
module U = Transaction_snark_tests.Util
module Spec = Transaction_snark.For_tests.Update_states_spec
open Mina_base

let%test_module "Valid_while precondition tests" =
  ( module struct
    let constraint_constants = U.constraint_constants

    let `VK vk, `Prover zkapp_prover = Lazy.force U.trivial_zkapp

    let snapp_update : Account_update.Update.t =
      { Account_update.Update.dummy with
        app_state =
          Pickles_types.Vector.init Zkapp_state.Max_state_size.n ~f:(fun i ->
              Zkapp_basic.Set_or_keep.Set (Pickles.Backend.Tick.Field.of_int i) )
      }

    let create_spec
        (specs : Mina_transaction_logic.For_tests.Transaction_spec.t list)
        new_kp global_slot : Spec.t =
      let fee = Fee.of_nanomina_int_exn 1_000_000 in
      let spec = List.hd_exn specs in
      { sender = spec.sender
      ; fee
      ; fee_payer = None
      ; receivers = []
      ; amount = Amount.zero
      ; zkapp_account_keypairs = [ new_kp ]
      ; memo = Signed_command_memo.create_from_string_exn "valid_while precond"
      ; new_zkapp_account = false
      ; snapp_update
      ; current_auth = Permissions.Auth_required.Signature
      ; call_data = Snark_params.Tick.Field.zero
      ; events = []
      ; actions = []
      ; preconditions =
          Some
            { Account_update.Preconditions.network =
                Zkapp_precondition.Protocol_state.accept
            ; account = Account_update.Account_precondition.Accept
            ; valid_while = Check { lower = global_slot; upper = global_slot }
            }
      }

    let%test_unit "exact valid_while precondition" =
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Mina_ledger.Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let global_slot = Mina_numbers.Global_slot.of_int 5 in
                  Mina_transaction_logic.For_tests.Init_ledger.init
                    (module Mina_ledger.Ledger.Ledger_inner)
                    init_ledger ledger ;
                  Transaction_snark.For_tests.create_trivial_zkapp_account ~vk
                    ~ledger
                    (Signature_lib.Public_key.compress new_kp.public_key) ;
                  let open Async.Deferred.Let_syntax in
                  let%bind zkapp_command =
                    Transaction_snark.For_tests.update_states
                      ~zkapp_prover_and_vk:(zkapp_prover, vk)
                      ~constraint_constants
                      (create_spec specs new_kp global_slot)
                  in
                  U.check_zkapp_command_with_merges_exn ~global_slot ledger
                    [ zkapp_command ] ) ) )

    let%test_unit "invalid valid_while precondition" =
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Mina_ledger.Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let global_slot = Mina_numbers.Global_slot.of_int 5 in
                  Mina_transaction_logic.For_tests.Init_ledger.init
                    (module Mina_ledger.Ledger.Ledger_inner)
                    init_ledger ledger ;
                  Transaction_snark.For_tests.create_trivial_zkapp_account ~vk
                    ~ledger
                    (Signature_lib.Public_key.compress new_kp.public_key) ;
                  let open Async.Deferred.Let_syntax in
                  let%bind zkapp_command =
                    Transaction_snark.For_tests.update_states
                      ~zkapp_prover_and_vk:(zkapp_prover, vk)
                      ~constraint_constants
                      (create_spec specs new_kp global_slot)
                  in
                  U.check_zkapp_command_with_merges_exn
                    ~expected_failure:
                      (Valid_while_precondition_unsatisfied, U.Pass_2)
                    ~global_slot:Mina_numbers.Global_slot.zero ledger
                    [ zkapp_command ] ) ) )
  end )

let%test_module "Protocol state precondition tests" =
  ( module struct
    let `VK vk, `Prover zkapp_prover = Lazy.force U.trivial_zkapp

    let constraint_constants = U.constraint_constants

    let memo =
      Signed_command_memo.create_from_string_exn "protocol state precondition"

    let snapp_update : Account_update.Update.t =
      { Account_update.Update.dummy with
        app_state =
          Pickles_types.Vector.init Zkapp_state.Max_state_size.n ~f:(fun i ->
              Zkapp_basic.Set_or_keep.Set (Pickles.Backend.Tick.Field.of_int i) )
      }

    let precondition_exact
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
      ; blockchain_length = Check (interval protocol_state.blockchain_length)
      ; min_window_density = Check (interval protocol_state.min_window_density)
      ; total_currency = Check (interval protocol_state.total_currency)
      ; global_slot_since_genesis =
          Check (interval protocol_state.global_slot_since_genesis)
      ; staking_epoch_data = epoch_data protocol_state.staking_epoch_data
      ; next_epoch_data = epoch_data protocol_state.next_epoch_data
      }

    let%test_unit "exact protocol state predicate" =
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          let state_body = U.genesis_state_body in
          let fee = Fee.of_nanomina_int_exn 1_000_000 in
          let _amount = Amount.of_mina_int_exn 10 in
          let spec = List.hd_exn specs in
          let test_spec : Spec.t =
            { sender = spec.sender
            ; fee
            ; fee_payer = None
            ; receivers = []
            ; amount = Amount.zero
            ; zkapp_account_keypairs = [ new_kp ]
            ; memo
            ; new_zkapp_account = false
            ; snapp_update
            ; current_auth = Permissions.Auth_required.Signature
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
            ; preconditions =
                Some
                  { Account_update.Preconditions.network =
                      precondition_exact
                        (Mina_state.Protocol_state.Body.view state_body)
                  ; account = Account_update.Account_precondition.Accept
                  ; valid_while = Ignore
                  }
            }
          in
          U.test_snapp_update test_spec ~state_body ~init_ledger ~vk
            ~zkapp_prover
            ~snapp_pk:(Public_key.compress new_kp.public_key) )

    let%test_unit "generated protocol state predicate" =
      let state_body = U.genesis_state_body in
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let%bind ledger = U.gen_snapp_ledger in
        let%map network_precondition =
          Mina_generators.Zkapp_command_generators
          .gen_protocol_state_precondition
            (Mina_state.Protocol_state.Body.view state_body)
        in
        (ledger, network_precondition)
      in
      Quickcheck.test ~trials:2 gen
        ~f:(fun (({ init_ledger; specs }, new_kp), network_precondition) ->
          let fee = Fee.of_nanomina_int_exn 1_000_000 in
          let spec = List.hd_exn specs in
          let test_spec : Spec.t =
            { sender = spec.sender
            ; fee
            ; fee_payer = None
            ; receivers = []
            ; amount = Amount.zero
            ; zkapp_account_keypairs = [ new_kp ]
            ; memo
            ; new_zkapp_account = false
            ; snapp_update
            ; current_auth = Permissions.Auth_required.Signature
            ; call_data = Snark_params.Tick.Field.zero
            ; events = []
            ; actions = []
            ; preconditions =
                Some
                  { Account_update.Preconditions.network = network_precondition
                  ; account = Account_update.Account_precondition.Accept
                  ; valid_while = Ignore
                  }
            }
          in
          U.test_snapp_update test_spec ~state_body ~init_ledger ~vk
            ~zkapp_prover
            ~snapp_pk:(Public_key.compress new_kp.public_key) )

    let%test_unit "invalid protocol state predicate in other zkapp_command" =
      let state_body = U.genesis_state_body in
      let psv = Mina_state.Protocol_state.Body.view state_body in
      let gen =
        let open Quickcheck.Let_syntax in
        let%bind ledger = U.gen_snapp_ledger in
        let%map network_precondition =
          Mina_generators.Zkapp_command_generators
          .gen_protocol_state_precondition psv
        in
        (ledger, network_precondition)
      in
      Quickcheck.test ~trials:1 gen
        ~f:(fun (({ init_ledger; specs }, new_kp), network_precondition) ->
          Mina_ledger.Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let fee = Fee.of_nanomina_int_exn 1_000_000 in
                  let amount = Amount.of_mina_int_exn 10 in
                  let spec = List.hd_exn specs in
                  let new_slot =
                    Mina_numbers.Global_slot.succ psv.global_slot_since_genesis
                  in
                  let invalid_network_precondition =
                    { network_precondition with
                      global_slot_since_genesis =
                        Zkapp_basic.Or_ignore.(
                          Check
                            Zkapp_precondition.Closed_interval.
                              { lower = new_slot; upper = new_slot })
                    }
                  in
                  let sender, sender_nonce = spec.sender in
                  let sender_pk =
                    Signature_lib.Public_key.compress sender.public_key
                  in
                  let snapp_pk =
                    Signature_lib.Public_key.compress new_kp.public_key
                  in
                  let fee_payer =
                    { Account_update.Fee_payer.body =
                        { public_key = sender_pk
                        ; fee
                        ; valid_until = None
                        ; nonce = sender_nonce
                        }
                        (*To be updated later*)
                    ; authorization = Signature.dummy
                    }
                  in
                  let sender_account_update : Account_update.Simple.t =
                    { body =
                        { public_key = sender_pk
                        ; update = Account_update.Update.noop
                        ; token_id = Token_id.default
                        ; balance_change =
                            Amount.(Signed.(negate (of_unsigned amount)))
                        ; increment_nonce = true
                        ; implicit_account_creation_fee = true
                        ; events = []
                        ; actions = []
                        ; call_data = Snark_params.Tick.Field.zero
                        ; call_depth = 0
                        ; preconditions =
                            { Account_update.Preconditions.network =
                                invalid_network_precondition
                            ; account = Nonce (Account.Nonce.succ sender_nonce)
                            ; valid_while = Ignore
                            }
                        ; use_full_commitment = false
                        ; may_use_token = No
                        ; authorization_kind = Signature
                        }
                        (*To be updated later*)
                    ; authorization = Control.Signature Signature.dummy
                    }
                  in
                  let snapp_account_update : Account_update.Simple.t =
                    { body =
                        { public_key = snapp_pk
                        ; update = snapp_update
                        ; token_id = Token_id.default
                        ; balance_change =
                            Amount.(
                              Signed.of_unsigned
                                (Option.value_exn
                                   (sub amount
                                      (of_fee
                                         constraint_constants
                                           .account_creation_fee ) ) ))
                        ; increment_nonce = false
                        ; implicit_account_creation_fee = true
                        ; events = []
                        ; actions = []
                        ; call_data = Snark_params.Tick.Field.zero
                        ; call_depth = 0
                        ; preconditions =
                            { Account_update.Preconditions.network =
                                invalid_network_precondition
                            ; account =
                                Account_update.Account_precondition.Accept
                            ; valid_while = Ignore
                            }
                        ; use_full_commitment = true
                        ; may_use_token = No
                        ; authorization_kind = Signature
                        }
                    ; authorization =
                        Control.Signature Signature.dummy
                        (*To be updated later*)
                    }
                  in
                  let ps =
                    Zkapp_command.Call_forest.With_hashes
                    .of_zkapp_command_simple_list
                      [ sender_account_update; snapp_account_update ]
                  in
                  let account_updates_hash =
                    Zkapp_command.Call_forest.hash ps
                  in
                  let commitment =
                    Zkapp_command.Transaction_commitment.create
                      ~account_updates_hash
                  in
                  let memo_hash = Signed_command_memo.hash memo in
                  let fee_payer_hash =
                    Zkapp_command.Digest.Account_update.create
                      (Account_update.of_fee_payer fee_payer)
                  in
                  let full_commitment =
                    Zkapp_command.Transaction_commitment.create_complete
                      commitment ~memo_hash ~fee_payer_hash
                  in
                  let fee_payer =
                    let fee_payer_signature_auth =
                      Signature_lib.Schnorr.Chunked.sign sender.private_key
                        (Random_oracle.Input.Chunked.field full_commitment)
                    in
                    { fee_payer with authorization = fee_payer_signature_auth }
                  in
                  let sender_account_update : Account_update.Simple.t =
                    let signature_auth : Signature.t =
                      Signature_lib.Schnorr.Chunked.sign sender.private_key
                        (Random_oracle.Input.Chunked.field commitment)
                    in
                    { sender_account_update with
                      authorization = Control.Signature signature_auth
                    }
                  in
                  let snapp_account_update =
                    let signature_auth =
                      Signature_lib.Schnorr.Chunked.sign new_kp.private_key
                        (Random_oracle.Input.Chunked.field full_commitment)
                    in
                    { snapp_account_update with
                      authorization = Control.Signature signature_auth
                    }
                  in
                  let zkapp_command_with_valid_fee_payer =
                    { fee_payer
                    ; memo
                    ; account_updates =
                        [ sender_account_update; snapp_account_update ]
                    }
                    |> Zkapp_command.of_simple
                  in
                  Mina_transaction_logic.For_tests.Init_ledger.init
                    (module Mina_ledger.Ledger.Ledger_inner)
                    init_ledger ledger ;
                  U.check_zkapp_command_with_merges_exn
                    ~expected_failure:
                      ( Transaction_status.Failure
                        .Protocol_state_precondition_unsatisfied
                      , U.Pass_2 )
                    ~state_body ledger
                    [ zkapp_command_with_valid_fee_payer ] ) ) )
  end )

let%test_module "Account precondition tests" =
  ( module struct
    let `VK vk, `Prover zkapp_prover = Lazy.force U.trivial_zkapp

    let zkapp_prover_and_vk = (zkapp_prover, vk)

    let constraint_constants = U.constraint_constants

    let memo = Signed_command_memo.create_from_string_exn "account precondition"

    let snapp_update : Account_update.Update.t =
      { Account_update.Update.dummy with
        app_state =
          Pickles_types.Vector.init Zkapp_state.Max_state_size.n ~f:(fun i ->
              Zkapp_basic.Set_or_keep.Set (Pickles.Backend.Tick.Field.of_int i) )
      }

    let precondition_exact (account : Account.t) =
      let open Mina_base.Zkapp_basic in
      let open Zkapp_precondition in
      let interval v =
        { Closed_interval.lower = v; Closed_interval.upper = v }
      in
      let { Mina_base.Account.Poly.balance
          ; nonce
          ; receipt_chain_hash
          ; delegate
          ; zkapp
          ; _
          } =
        account
      in
      let (predicate_account : Zkapp_precondition.Account.t) =
        let balance = Or_ignore.Check (interval balance) in
        let nonce = Or_ignore.Check (interval nonce) in
        let receipt_chain_hash = Or_ignore.Check receipt_chain_hash in
        let delegate =
          match delegate with
          | None ->
              Or_ignore.Ignore
          | Some pk ->
              Or_ignore.Check pk
        in
        let state, action_state, proved_state, is_new =
          match zkapp with
          | None ->
              let len = Pickles_types.Nat.to_int Zkapp_state.Max_state_size.n in
              (* won't raise, correct length given *)
              let state =
                Zkapp_state.V.of_list_exn
                  (List.init len ~f:(fun _ -> Or_ignore.Ignore))
              in
              let action_state = Or_ignore.Ignore in
              let proved_state = Or_ignore.Ignore in
              let is_new = Or_ignore.Ignore in
              (state, action_state, proved_state, is_new)
          | Some { app_state; action_state; proved_state; _ } ->
              let state =
                Zkapp_state.V.map app_state ~f:(fun field ->
                    Or_ignore.Check field )
              in
              let action_state =
                (* choose a value from account action state *)
                let fields =
                  Pickles_types.Vector.Vector_5.to_list action_state
                in
                Or_ignore.Check (List.hd_exn fields)
              in
              let proved_state = Or_ignore.Check proved_state in
              (* the account is in the ledger *)
              let is_new = Or_ignore.Check false in
              (state, action_state, proved_state, is_new)
        in
        { Zkapp_precondition.Account.balance
        ; nonce
        ; receipt_chain_hash
        ; delegate
        ; state
        ; action_state
        ; proved_state
        ; is_new
        }
      in
      Account_update.Account_precondition.Full predicate_account

    let%test_unit "exact account predicate" =
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Mina_ledger.Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let state_body = U.genesis_state_body in
                  let fee = Fee.of_nanomina_int_exn 1_000_000 in
                  let spec = List.hd_exn specs in
                  let snapp_pk =
                    Signature_lib.Public_key.compress new_kp.public_key
                  in
                  let snapp_account =
                    Transaction_snark.For_tests.trivial_zkapp_account ~vk
                      snapp_pk
                  in
                  let test_spec : Spec.t =
                    { sender = spec.sender
                    ; fee
                    ; fee_payer = None
                    ; receivers = []
                    ; amount = Amount.zero
                    ; zkapp_account_keypairs = [ new_kp ]
                    ; memo
                    ; new_zkapp_account = false
                    ; snapp_update
                    ; current_auth = Permissions.Auth_required.Signature
                    ; call_data = Snark_params.Tick.Field.zero
                    ; events = []
                    ; actions = []
                    ; preconditions =
                        Some
                          { Account_update.Preconditions.network =
                              Zkapp_precondition.Protocol_state.accept
                          ; account = precondition_exact snapp_account
                          ; valid_while = Ignore
                          }
                    }
                  in
                  Mina_transaction_logic.For_tests.Init_ledger.init
                    (module Mina_ledger.Ledger.Ledger_inner)
                    init_ledger ledger ;
                  (*create a zkAapp account*)
                  Transaction_snark.For_tests.create_trivial_zkapp_account ~vk
                    ~ledger snapp_pk ;
                  let open Async.Deferred.Let_syntax in
                  let%bind zkapp_command =
                    Transaction_snark.For_tests.update_states
                      ~zkapp_prover_and_vk ~constraint_constants test_spec
                  in
                  U.check_zkapp_command_with_merges_exn ~state_body ledger
                    [ zkapp_command ] ) ) )

    let%test_unit "generated account precondition" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let%bind ((_, new_kp) as l) = U.gen_snapp_ledger in
        let snapp_pk = Signature_lib.Public_key.compress new_kp.public_key in
        let zkapp_account =
          Transaction_snark.For_tests.trivial_zkapp_account ~vk snapp_pk
        in
        let%map account_precondition =
          Mina_generators.Zkapp_command_generators
          .gen_account_precondition_from_account zkapp_account
            ~first_use_of_account:true
        in
        (l, account_precondition)
      in
      Quickcheck.test ~trials:5 gen
        ~f:(fun (({ init_ledger; specs }, new_kp), account_precondition) ->
          Mina_ledger.Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let state_body = U.genesis_state_body in
                  let fee = Fee.of_nanomina_int_exn 1_000_000 in
                  let spec = List.hd_exn specs in
                  let zkapp_pk =
                    Signature_lib.Public_key.compress new_kp.public_key
                  in
                  Mina_transaction_logic.For_tests.Init_ledger.init
                    (module Mina_ledger.Ledger.Ledger_inner)
                    init_ledger ledger ;
                  (*create a zkAapp account*)
                  Transaction_snark.For_tests.create_trivial_zkapp_account ~vk
                    ~ledger zkapp_pk ;
                  let open Async.Deferred.Let_syntax in
                  let test_spec : Spec.t =
                    { sender = spec.sender
                    ; fee
                    ; fee_payer = None
                    ; receivers = []
                    ; amount = Amount.zero
                    ; zkapp_account_keypairs = [ new_kp ]
                    ; memo
                    ; new_zkapp_account = false
                    ; snapp_update
                    ; current_auth = Permissions.Auth_required.Signature
                    ; call_data = Snark_params.Tick.Field.zero
                    ; events = []
                    ; actions = []
                    ; preconditions =
                        Some
                          { Account_update.Preconditions.network =
                              Zkapp_precondition.Protocol_state.accept
                          ; account = account_precondition
                          ; valid_while = Ignore
                          }
                    }
                  in
                  let%bind zkapp_command =
                    Transaction_snark.For_tests.update_states
                      ~zkapp_prover_and_vk ~constraint_constants test_spec
                  in
                  U.check_zkapp_command_with_merges_exn ~state_body ledger
                    [ zkapp_command ] ) ) )

    let mk_delegate_precondition pk : Account_update.Account_precondition.t =
      let open Zkapp_basic.Or_ignore in
      let state =
        Pickles_types.Vector.init Zkapp_state.Max_state_size.n ~f:(fun _ ->
            Ignore )
      in
      Full
        { balance = Ignore
        ; nonce = Ignore
        ; receipt_chain_hash = Ignore
        ; delegate = Check pk
        ; state
        ; action_state = Ignore
        ; proved_state = Ignore
        ; is_new = Check true
        }

    let add_account_precondition ~at precondition account_updates =
      Zkapp_command.Call_forest.mapi account_updates
        ~f:(fun i (update : Account_update.t) ->
          if i = at then
            { update with
              body =
                { update.body with
                  preconditions =
                    { update.body.preconditions with account = precondition }
                }
            }
          else update )

    let%test_unit "delegate precondition on new account" =
      let gen = U.gen_snapp_ledger in
      Quickcheck.test ~trials:5 gen ~f:(fun ({ specs; _ }, new_kp) ->
          Mina_ledger.Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let state_body = U.genesis_state_body in
                  let fee = Fee.of_nanomina_int_exn 1_000_000 in
                  let spec = List.hd_exn specs in
                  let sender_kp, _ = spec.sender in
                  let sender_pk =
                    Signature_lib.Public_key.compress sender_kp.public_key
                  in
                  Transaction_snark.For_tests.create_trivial_zkapp_account ~vk
                    ~ledger sender_pk ;
                  let open Async.Deferred.Let_syntax in
                  let test_spec : Spec.t =
                    { sender = spec.sender
                    ; fee
                    ; fee_payer = None
                    ; receivers = []
                    ; amount = Amount.of_mina_int_exn 5
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
                  let%bind zkapp_command0 =
                    Transaction_snark.For_tests.update_states
                      ~zkapp_prover_and_vk ~constraint_constants test_spec
                  in
                  (* add delegate precondition for new account *)
                  let%bind zkapp_command =
                    let zkapp_pk = Public_key.compress new_kp.public_key in
                    let delegate_precondition =
                      mk_delegate_precondition zkapp_pk
                    in
                    let zkapp =
                      { zkapp_command0 with
                        account_updates =
                          add_account_precondition ~at:1 delegate_precondition
                            zkapp_command0.account_updates
                          |> Zkapp_command.Call_forest
                             .accumulate_hashes_predicated
                      }
                    in
                    let keymap =
                      Public_key.Compressed.Map.of_alist_exn
                        [ (sender_pk, sender_kp.private_key)
                        ; (zkapp_pk, new_kp.private_key)
                        ]
                    in
                    Zkapp_command_builder.replace_authorizations ~keymap zkapp
                  in
                  U.check_zkapp_command_with_merges_exn ~state_body ledger
                    [ zkapp_command ] ) ) )

    let%test_unit "unsatisfied delegate precondition, custom token" =
      (* when new account has a custom token, it doesn't get a self-delegation *)
      let constraint_constants = U.constraint_constants in
      let account_creation_fee =
        Currency.Fee.to_nanomina_int constraint_constants.account_creation_fee
      in
      Quickcheck.test ~trials:5 Signature_lib.Keypair.gen ~f:(fun new_kp ->
          Mina_ledger.Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let module Init_ledger =
                    Mina_transaction_logic.For_tests.Init_ledger
                  in
                  let open Async.Deferred.Let_syntax in
                  let token_owner = new_kp in
                  let token_owner_pk =
                    Signature_lib.Public_key.compress token_owner.public_key
                  in
                  Init_ledger.init
                    (module Mina_ledger.Ledger.Ledger_inner)
                    [| (token_owner, 5_000_000_000L) |]
                    ledger ;
                  let custom_token_id =
                    Account_id.derive_token_id
                      ~owner:(Account_id.create token_owner_pk Token_id.default)
                  in
                  let token_account = Keypair.create () in
                  let token_account_pk =
                    Public_key.compress token_account.public_key
                  in
                  let keymap =
                    List.fold [ token_owner; token_account ]
                      ~init:Public_key.Compressed.Map.empty
                      ~f:(fun map { private_key; public_key } ->
                        Public_key.Compressed.Map.add_exn map
                          ~key:(Public_key.compress public_key)
                          ~data:private_key )
                  in
                  let%bind mint_token_zkapp_command =
                    let open Zkapp_command_builder in
                    let nonce = Account.Nonce.zero in
                    let zkapp0 =
                      mk_forest
                        [ mk_node
                            (mk_account_update_body Signature No token_owner
                               Token_id.default (-account_creation_fee) )
                            [ mk_node
                                (mk_account_update_body Signature
                                   Parents_own_token token_account
                                   custom_token_id 100 )
                                []
                            ]
                        ]
                      |> mk_zkapp_command ~fee:7 ~fee_payer_pk:token_owner_pk
                           ~fee_payer_nonce:nonce
                    in
                    let zkapp_dummy_signatures =
                      let delegate_precondition =
                        mk_delegate_precondition token_account_pk
                      in
                      { zkapp0 with
                        account_updates =
                          add_account_precondition ~at:1 delegate_precondition
                            zkapp0.account_updates
                          |> Zkapp_command.Call_forest
                             .accumulate_hashes_predicated
                      }
                    in
                    replace_authorizations ~keymap zkapp_dummy_signatures
                  in
                  U.check_zkapp_command_with_merges_exn
                    ~expected_failure:
                      (Account_delegate_precondition_unsatisfied, U.Pass_2)
                    ledger
                    [ mint_token_zkapp_command ] ) ) )

    let%test_unit "invalid account predicate in other zkapp_command" =
      let state_body = U.genesis_state_body in
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let%bind ((_, new_kp) as l) = U.gen_snapp_ledger in
        let snapp_pk = Signature_lib.Public_key.compress new_kp.public_key in
        let snapp_account =
          Transaction_snark.For_tests.trivial_zkapp_account ~vk snapp_pk
        in
        let%map account_precondition =
          Mina_generators.Zkapp_command_generators.(
            gen_account_precondition_from_account ~first_use_of_account:true
              ~is_nonce_precondition:true ~failure:Invalid_account_precondition
              snapp_account)
        in
        (l, account_precondition)
      in
      Quickcheck.test ~trials:1 gen
        ~f:(fun (({ init_ledger; specs }, new_kp), account_precondition) ->
          Mina_ledger.Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let fee = Fee.of_nanomina_int_exn 1_000_000 in
                  let _amount = Amount.of_mina_int_exn 10 in
                  let spec = List.hd_exn specs in
                  let test_spec : Spec.t =
                    { sender = spec.sender
                    ; fee
                    ; fee_payer = None
                    ; receivers = []
                    ; amount = Amount.zero
                    ; zkapp_account_keypairs = [ new_kp ]
                    ; memo
                    ; new_zkapp_account = false
                    ; snapp_update
                    ; current_auth = Permissions.Auth_required.Signature
                    ; call_data = Snark_params.Tick.Field.zero
                    ; events = []
                    ; actions = []
                    ; preconditions =
                        Some
                          { Account_update.Preconditions.network =
                              Zkapp_precondition.Protocol_state.accept
                          ; account = account_precondition
                          ; valid_while = Ignore
                          }
                    }
                  in
                  let open Async.Deferred.Let_syntax in
                  let%bind zkapp_command =
                    Transaction_snark.For_tests.update_states
                      ~zkapp_prover_and_vk ~constraint_constants test_spec
                  in
                  Mina_transaction_logic.For_tests.Init_ledger.init
                    (module Mina_ledger.Ledger.Ledger_inner)
                    init_ledger ledger ;
                  (*create a snapp account*)
                  let snapp_pk =
                    Signature_lib.Public_key.compress new_kp.public_key
                  in
                  Transaction_snark.For_tests.create_trivial_zkapp_account ~vk
                    ~ledger snapp_pk ;
                  U.check_zkapp_command_with_merges_exn
                    ~expected_failure:
                      ( Transaction_status.Failure
                        .Account_nonce_precondition_unsatisfied
                      , U.Pass_2 )
                    ~state_body ledger [ zkapp_command ] ) ) )

    let%test_unit "invalid account predicate in fee payer" =
      let state_body = U.genesis_state_body in
      let psv = Mina_state.Protocol_state.Body.view state_body in
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Mina_ledger.Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              let fee = Fee.of_nanomina_int_exn 1_000_000 in
              let amount = Amount.of_mina_int_exn 10 in
              let spec = List.hd_exn specs in
              let sender, sender_nonce = spec.sender in
              let sender_pk =
                Signature_lib.Public_key.compress sender.public_key
              in
              let snapp_pk =
                Signature_lib.Public_key.compress new_kp.public_key
              in
              let fee_payer =
                { Account_update.Fee_payer.body =
                    { public_key = sender_pk
                    ; fee
                    ; valid_until = None
                    ; nonce = Account.Nonce.succ sender_nonce (*Invalid nonce*)
                    }
                    (*To be updated later*)
                ; authorization = Signature.dummy
                }
              in
              let sender_account_update : Account_update.Simple.t =
                { body =
                    { public_key = sender_pk
                    ; update = Account_update.Update.noop
                    ; token_id = Token_id.default
                    ; balance_change =
                        Amount.(Signed.(negate (of_unsigned amount)))
                    ; increment_nonce = true
                    ; implicit_account_creation_fee = true
                    ; events = []
                    ; actions = []
                    ; call_data = Snark_params.Tick.Field.zero
                    ; call_depth = 0
                    ; preconditions =
                        { Account_update.Preconditions.network =
                            Zkapp_precondition.Protocol_state.accept
                        ; account = Nonce (Account.Nonce.succ sender_nonce)
                        ; valid_while = Ignore
                        }
                    ; use_full_commitment = false
                    ; may_use_token = No
                    ; authorization_kind = Signature
                    }
                    (*To be updated later*)
                ; authorization = Control.Signature Signature.dummy
                }
              in
              let snapp_account_update : Account_update.Simple.t =
                { body =
                    { public_key = snapp_pk
                    ; update = snapp_update
                    ; token_id = Token_id.default
                    ; balance_change =
                        Option.value_exn
                          (Currency.Amount.sub amount
                             (Amount.of_fee
                                constraint_constants.account_creation_fee ) )
                        |> Amount.Signed.of_unsigned
                    ; increment_nonce = false
                    ; implicit_account_creation_fee = true
                    ; events = []
                    ; actions = []
                    ; call_data = Snark_params.Tick.Field.zero
                    ; call_depth = 0
                    ; preconditions =
                        { Account_update.Preconditions.network =
                            Zkapp_precondition.Protocol_state.accept
                        ; account = Account_update.Account_precondition.Accept
                        ; valid_while = Ignore
                        }
                    ; use_full_commitment = true
                    ; may_use_token = No
                    ; authorization_kind = Signature
                    }
                ; authorization =
                    Control.Signature Signature.dummy (*To be updated later*)
                }
              in
              let ps =
                Zkapp_command.Call_forest.With_hashes
                .of_zkapp_command_simple_list
                  [ sender_account_update; snapp_account_update ]
              in
              let account_updates_hash = Zkapp_command.Call_forest.hash ps in
              let commitment =
                Zkapp_command.Transaction_commitment.create
                  ~account_updates_hash
              in
              let memo_hash = Signed_command_memo.hash memo in
              let fee_payer_hash =
                Zkapp_command.Digest.Account_update.create
                  (Account_update.of_fee_payer fee_payer)
              in
              let full_commitment =
                Zkapp_command.Transaction_commitment.create_complete commitment
                  ~memo_hash ~fee_payer_hash
              in
              let fee_payer =
                let fee_payer_signature_auth =
                  Signature_lib.Schnorr.Chunked.sign sender.private_key
                    (Random_oracle.Input.Chunked.field full_commitment)
                in
                { fee_payer with authorization = fee_payer_signature_auth }
              in
              let sender_account_update =
                let signature_auth : Signature.t =
                  Signature_lib.Schnorr.Chunked.sign sender.private_key
                    (Random_oracle.Input.Chunked.field commitment)
                in
                { sender_account_update with
                  authorization = Control.Signature signature_auth
                }
              in
              let snapp_account_update =
                let signature_auth =
                  Signature_lib.Schnorr.Chunked.sign new_kp.private_key
                    (Random_oracle.Input.Chunked.field full_commitment)
                in
                { snapp_account_update with
                  authorization = Control.Signature signature_auth
                }
              in
              let zkapp_command_with_invalid_fee_payer =
                Zkapp_command.of_simple
                  { fee_payer
                  ; memo
                  ; account_updates =
                      [ sender_account_update; snapp_account_update ]
                  }
              in
              Mina_transaction_logic.For_tests.Init_ledger.init
                (module Mina_ledger.Ledger.Ledger_inner)
                init_ledger ledger ;
              match
                Mina_ledger.Ledger.apply_zkapp_command_unchecked
                  ~constraint_constants
                  ~global_slot:psv.global_slot_since_genesis ~state_view:psv
                  ledger zkapp_command_with_invalid_fee_payer
              with
              | Error e ->
                  assert (
                    Str.string_match
                      (Str.regexp
                         (sprintf {|.*\(%s\).*|}
                            Transaction_status.Failure.(
                              to_string Account_nonce_precondition_unsatisfied) ) )
                      (Error.to_string_hum e) 0 )
              | Ok _ ->
                  failwith
                    "Expected transaction to fail due to invalid account \
                     precondition in the fee payer" ) )
  end )
