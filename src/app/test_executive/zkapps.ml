open Core
open Async
open Integration_test_lib
open Mina_base

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let config =
    let open Test_config in
    { default with
      requires_graphql = true
    ; block_producers =
        [ { balance = "8000000000"; timing = Untimed }
        ; { balance = "1000000000"; timing = Untimed }
        ]
    ; extra_genesis_accounts =
        [ { balance = "1000"; timing = Untimed }
        ; { balance = "1000"; timing = Untimed }
        ]
    ; num_archive_nodes = 1
    ; num_snark_workers = 2
    ; snark_worker_fee = "0.0001"
    ; proof_config =
        { proof_config_default with
          work_delay = Some 1
        ; transaction_capacity =
            Some Runtime_config.Proof_keys.Transaction_capacity.small
        }
    }

  let transactions_sent = ref 0

  let send_zkapp ~logger node parties =
    incr transactions_sent ;
    send_zkapp ~logger node parties

  (* Call [f] [n] times in sequence *)
  let repeat_seq ~n ~f =
    let open Malleable_error.Let_syntax in
    let rec go n =
      if n = 0 then return ()
      else
        let%bind () = f () in
        go (n - 1)
    in
    go n

  let send_padding_transactions ~fee ~logger ~n nodes =
    let sender = List.nth_exn nodes 0 in
    let receiver = List.nth_exn nodes 1 in
    let open Malleable_error.Let_syntax in
    let%bind sender_pub_key = Util.pub_key_of_node sender in
    let%bind receiver_pub_key = Util.pub_key_of_node receiver in
    repeat_seq ~n ~f:(fun () ->
        Network.Node.must_send_payment ~logger sender ~sender_pub_key
          ~receiver_pub_key ~amount:Currency.Amount.one ~fee
        >>| ignore )

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let block_producer_nodes = Network.block_producers network in
    (*TODO: capture snark worker processes' failures*)
    let%bind () =
      section_hard "Wait for nodes to initialize"
        (wait_for t
           (Wait_condition.nodes_to_initialize
              ( Network.seeds network @ block_producer_nodes
              @ Network.snark_coordinators network ) ) )
    in
    let node = List.hd_exn block_producer_nodes in
    let constraint_constants =
      Genesis_constants.Constraint_constants.compiled
    in
    let[@warning "-8"] [ fish1_kp; fish2_kp ] =
      Network.extra_genesis_keypairs network
    in
    let num_zkapp_accounts = 3 in
    let zkapp_keypairs =
      List.init num_zkapp_accounts ~f:(fun _ -> Signature_lib.Keypair.create ())
    in
    let zkapp_account_ids =
      List.map zkapp_keypairs ~f:(fun zkapp_keypair ->
          Account_id.create
            (zkapp_keypair.public_key |> Signature_lib.Public_key.compress)
            Token_id.default )
    in
    let%bind parties_create_account =
      (* construct a Parties.t, similar to zkapp_test_transaction create-snapp-account *)
      let amount = Currency.Amount.of_int 10_000_000_000 in
      let nonce = Account.Nonce.zero in
      let memo =
        Signed_command_memo.create_from_string_exn "Zkapp create account"
      in
      let fee = Currency.Fee.of_int 20_000_000 in
      let (parties_spec : Transaction_snark.For_tests.Spec.t) =
        { sender = (fish1_kp, nonce)
        ; fee
        ; fee_payer = None
        ; receivers = []
        ; amount
        ; zkapp_account_keypairs = zkapp_keypairs
        ; memo
        ; new_zkapp_account = true
        ; snapp_update = Party.Update.dummy
        ; current_auth = Permissions.Auth_required.Signature
        ; call_data = Snark_params.Tick.Field.zero
        ; events = []
        ; sequence_events = []
        ; preconditions = None
        }
      in
      return
      @@ Transaction_snark.For_tests.deploy_snapp ~constraint_constants
           parties_spec
    in
    let%bind.Deferred parties_update_permissions, permissions_updated =
      (* construct a Parties.t, similar to zkapp_test_transaction update-permissions *)
      let nonce = Account.Nonce.zero in
      let memo =
        Signed_command_memo.create_from_string_exn "Zkapp update permissions"
      in
      (*Lower fee so that parties_create_account gets applied first*)
      let fee = Currency.Fee.of_int 10_000_000 in
      let new_permissions : Permissions.t =
        { Permissions.user_default with
          edit_state = Permissions.Auth_required.Proof
        ; edit_sequence_state = Proof
        ; set_delegate = Proof
        ; set_verification_key = Proof
        ; set_permissions = Proof
        ; set_zkapp_uri = Proof
        ; set_token_symbol = Proof
        ; set_voting_for = Proof
        }
      in
      let (parties_spec : Transaction_snark.For_tests.Spec.t) =
        { sender = (fish2_kp, nonce)
        ; fee
        ; fee_payer = None
        ; receivers = []
        ; amount = Currency.Amount.zero
        ; zkapp_account_keypairs = zkapp_keypairs
        ; memo
        ; new_zkapp_account = false
        ; snapp_update =
            { Party.Update.dummy with permissions = Set new_permissions }
        ; current_auth =
            (* current set_permissions permission requires Signature *)
            Permissions.Auth_required.Signature
        ; call_data = Snark_params.Tick.Field.zero
        ; events = []
        ; sequence_events = []
        ; preconditions = None
        }
      in
      let%map.Deferred parties =
        Transaction_snark.For_tests.update_states ~constraint_constants
          parties_spec
      in
      (parties, new_permissions)
    in
    let%bind.Deferred ( zkapp_update_all
                      , parties_update_all
                      , parties_insufficient_replace_fee
                      , parties_insufficient_fee ) =
      let amount = Currency.Amount.zero in
      let nonce = Account.Nonce.of_int 1 in
      let memo =
        Signed_command_memo.create_from_string_exn "Zkapp update all"
      in
      let fee = Currency.Fee.of_int 10_000_000 in
      let app_state =
        let len = Zkapp_state.Max_state_size.n |> Pickles_types.Nat.to_int in
        let fields =
          Quickcheck.random_value
            (Quickcheck.Generator.list_with_length len
               Snark_params.Tick.Field.gen )
        in
        List.map fields ~f:(fun field -> Zkapp_basic.Set_or_keep.Set field)
        |> Zkapp_state.V.of_list_exn
      in
      let new_delegate =
        Quickcheck.random_value Signature_lib.Public_key.Compressed.gen
      in
      let new_verification_key =
        let data = Pickles.Side_loaded.Verification_key.dummy in
        let hash = Zkapp_account.digest_vk data in
        ({ data; hash } : _ With_hash.t)
      in
      let new_permissions =
        Quickcheck.random_value (Permissions.gen ~auth_tag:Proof)
      in
      let new_zkapp_uri = "https://www.minaprotocol.com" in
      let new_token_symbol = "SHEKEL" in
      let new_voting_for = Quickcheck.random_value State_hash.gen in
      let snapp_update : Party.Update.t =
        { app_state
        ; delegate = Set new_delegate
        ; verification_key = Set new_verification_key
        ; permissions = Set new_permissions
        ; zkapp_uri = Set new_zkapp_uri
        ; token_symbol = Set new_token_symbol
        ; timing = (* timing can't be updated for an existing account *)
                   Keep
        ; voting_for = Set new_voting_for
        }
      in
      let (parties_spec : Transaction_snark.For_tests.Spec.t) =
        { sender = (fish2_kp, nonce)
        ; fee
        ; fee_payer = None
        ; receivers = []
        ; amount
        ; zkapp_account_keypairs = zkapp_keypairs
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
      let%bind.Deferred parties_update_all =
        Transaction_snark.For_tests.update_states ~constraint_constants
          parties_spec
      in
      let spec_insufficient_replace_fee : Transaction_snark.For_tests.Spec.t =
        { parties_spec with fee = Currency.Fee.of_int 5_000_000 }
      in
      let%bind.Deferred parties_insufficient_replace_fee =
        Transaction_snark.For_tests.update_states ~constraint_constants
          spec_insufficient_replace_fee
      in
      let spec_insufficient_fee : Transaction_snark.For_tests.Spec.t =
        { parties_spec with fee = Currency.Fee.of_int 1000 }
      in
      let%map.Deferred parties_insufficient_fee =
        Transaction_snark.For_tests.update_states ~constraint_constants
          spec_insufficient_fee
      in
      ( snapp_update
      , parties_update_all
      , parties_insufficient_replace_fee
      , parties_insufficient_fee )
    in
    let parties_invalid_nonce =
      let p = parties_update_all in
      { p with
        fee_payer =
          { p.fee_payer with
            body = { p.fee_payer.body with nonce = Account.Nonce.of_int 42 }
          }
      }
    in
    let parties_invalid_signature =
      let p = parties_update_all in
      { p with
        fee_payer =
          { body = { p.fee_payer.body with nonce = Account.Nonce.of_int 2 }
          ; authorization = Signature.dummy
          }
      }
    in
    let parties_invalid_proof =
      let p = parties_update_all in
      Parties.
        { p with
          other_parties =
            Call_forest.map p.other_parties ~f:(fun other_p ->
                match other_p.Party.authorization with
                | Proof _ ->
                    { other_p with
                      authorization =
                        Control.Proof Mina_base.Proof.blockchain_dummy
                    }
                | _ ->
                    other_p )
        }
    in
    let%bind.Deferred parties_nonexistent_fee_payer =
      let new_kp = Signature_lib.Keypair.create () in
      let memo =
        Signed_command_memo.create_from_string_exn "Non-existent account"
      in
      let fee = Currency.Fee.of_int 10_000_000 in
      let spec : Transaction_snark.For_tests.Spec.t =
        { sender = (new_kp, Account.Nonce.zero)
        ; fee
        ; fee_payer = None
        ; receivers = []
        ; amount = Currency.Amount.zero
        ; zkapp_account_keypairs = zkapp_keypairs
        ; memo
        ; new_zkapp_account = false
        ; snapp_update = Party.Update.dummy
        ; current_auth = Permissions.Auth_required.None
        ; call_data = Snark_params.Tick.Field.zero
        ; events = []
        ; sequence_events = []
        ; preconditions = None
        }
      in
      Transaction_snark.For_tests.update_states ~constraint_constants spec
    in
    let with_timeout =
      let soft_slots = 4 in
      let soft_timeout = Network_time_span.Slots soft_slots in
      let hard_timeout = Network_time_span.Slots (soft_slots * 2) in
      Wait_condition.with_timeouts ~soft_timeout ~hard_timeout
    in
    let compatible req_item ledg_item ~equal =
      match (req_item, ledg_item) with
      | Zkapp_basic.Set_or_keep.Keep, _ ->
          true
      | Set v1, Zkapp_basic.Set_or_keep.Set v2 ->
          equal v1 v2
      | Set _, Keep ->
          false
    in
    let compatible_updates ~(ledger_update : Party.Update.t)
        ~(requested_update : Party.Update.t) : bool =
      (* the "update" in the ledger is derived from the account

         if the requested update has `Set` for a field, we
         should see `Set` for the same value in the ledger update

         if the requested update has `Keep` for a field, any
         value in the ledger update is acceptable

         for the app state, we apply this principle element-wise
      *)
      let app_states_compat =
        let fs_requested =
          Pickles_types.Vector.Vector_8.to_list requested_update.app_state
        in
        let fs_ledger =
          Pickles_types.Vector.Vector_8.to_list ledger_update.app_state
        in
        List.for_all2_exn fs_requested fs_ledger ~f:(fun req ledg ->
            compatible req ledg ~equal:Pickles.Backend.Tick.Field.equal )
      in
      let delegates_compat =
        compatible requested_update.delegate ledger_update.delegate
          ~equal:Signature_lib.Public_key.Compressed.equal
      in
      let verification_keys_compat =
        compatible requested_update.verification_key
          ledger_update.verification_key
          ~equal:
            [%equal:
              ( Pickles.Side_loaded.Verification_key.t
              , Pickles.Backend.Tick.Field.t )
              With_hash.t]
      in
      let permissions_compat =
        compatible requested_update.permissions ledger_update.permissions
          ~equal:Permissions.equal
      in
      let zkapp_uris_compat =
        compatible requested_update.zkapp_uri ledger_update.zkapp_uri
          ~equal:String.equal
      in
      let token_symbols_compat =
        compatible requested_update.token_symbol ledger_update.token_symbol
          ~equal:String.equal
      in
      let timings_compat =
        compatible requested_update.timing ledger_update.timing
          ~equal:Party.Update.Timing_info.equal
      in
      let voting_fors_compat =
        compatible requested_update.voting_for ledger_update.voting_for
          ~equal:State_hash.equal
      in
      List.for_all
        [ app_states_compat
        ; delegates_compat
        ; verification_keys_compat
        ; permissions_compat
        ; zkapp_uris_compat
        ; token_symbols_compat
        ; timings_compat
        ; voting_fors_compat
        ]
        ~f:Fn.id
    in
    let wait_for_zkapp parties =
      let%map () =
        wait_for t @@ with_timeout
        @@ Wait_condition.snapp_to_be_included_in_frontier ~has_failures:false
             ~parties
      in
      [%log info] "ZkApp transactions included in transition frontier"
    in
    let%bind () =
      section_hard "Send a zkApp transaction to create zkApp accounts"
        (send_zkapp ~logger node parties_create_account)
    in
    let%bind () =
      section_hard "Send a zkApp transaction to update permissions"
        (send_zkapp ~logger node parties_update_permissions)
    in
    let%bind () =
      let padding_payments =
        (* for work_delay=1 and transaction_capacity=4 per block*)
        let needed = 12 in
        if !transactions_sent >= needed then 0 else needed - !transactions_sent
      in
      let fee = Currency.Fee.of_int 1_000_000 in
      send_padding_transactions block_producer_nodes ~fee ~logger
        ~n:padding_payments
    in
    let%bind () =
      section_hard
        "Wait for zkapp to create accounts to be included in transition \
         frontier"
        (wait_for_zkapp parties_create_account)
    in
    let%bind () =
      section_hard
        "Wait for zkApp transaction to update permissions to be included in \
         transition frontier"
        (wait_for_zkapp parties_update_permissions)
    in
    let%bind () =
      section_hard "Verify that updated permissions are in ledger accounts"
        (Malleable_error.List.iter zkapp_account_ids ~f:(fun account_id ->
             [%log info] "Verifying permissions for account"
               ~metadata:[ ("account_id", Account_id.to_yojson account_id) ] ;
             let%bind ledger_permissions =
               get_account_permissions ~logger node account_id
             in
             if Permissions.equal ledger_permissions permissions_updated then (
               [%log info] "Ledger, updated permissions are equal" ;
               return () )
             else (
               [%log error] "Ledger, updated permissions differ"
                 ~metadata:
                   [ ( "ledger_permissions"
                     , Permissions.to_yojson ledger_permissions )
                   ; ( "updated_permissions"
                     , Permissions.to_yojson permissions_updated )
                   ] ;
               Malleable_error.hard_error
                 (Error.of_string
                    "Ledger permissions do not match update permissions" ) ) )
        )
    in
    let%bind () =
      section_hard "Send a zkapp with an insufficient fee"
        (send_invalid_zkapp ~logger node parties_insufficient_fee
           "at least one user command had an insufficient fee" )
    in
    (*Won't be accepted until the previous transactions are applied*)
    let%bind () =
      section_hard "Send a zkApp transaction to update all fields"
        (send_zkapp ~logger node parties_update_all)
    in
    let%bind () =
      section_hard "Send a zkapp with an invalid proof"
        (send_invalid_zkapp ~logger node parties_invalid_proof
           "Verification_failed" )
    in
    let%bind () =
      section_hard "Send a zkapp with an insufficient replace fee"
        (send_invalid_zkapp ~logger node parties_insufficient_replace_fee
           "Insufficient_replace_fee" )
    in
    let%bind () =
      section_hard
        "Wait for zkApp transaction to update all fields to be included in \
         transition frontier"
        (wait_for_zkapp parties_update_all)
    in
    let%bind () =
      section_hard "Send a zkApp transaction with an invalid nonce"
        (send_invalid_zkapp ~logger node parties_invalid_nonce "Invalid_nonce")
    in
    let%bind () =
      section_hard "Send a zkApp transaction with an invalid signature"
        (send_invalid_zkapp ~logger node parties_invalid_signature
           "Verification_failed" )
    in
    let%bind () =
      section_hard "Send a zkApp transaction with a nonexistent fee payer"
        (send_invalid_zkapp ~logger node parties_nonexistent_fee_payer
           "Fee_payer_account_not_found" )
    in
    let%bind () =
      section_hard "Verify zkApp transaction updates in ledger"
        (Malleable_error.List.iter zkapp_account_ids ~f:(fun account_id ->
             [%log info] "Verifying updates for account"
               ~metadata:[ ("account_id", Account_id.to_yojson account_id) ] ;
             let%bind ledger_update =
               get_account_update ~logger node account_id
             in
             if
               compatible_updates ~ledger_update
                 ~requested_update:zkapp_update_all
             then (
               [%log info] "Ledger update and requested update are compatible" ;
               return () )
             else (
               [%log error]
                 "Ledger update and requested update are incompatible"
                 ~metadata:
                   [ ("ledger_update", Party.Update.to_yojson ledger_update)
                   ; ( "requested_update"
                     , Party.Update.to_yojson zkapp_update_all )
                   ] ;
               Malleable_error.hard_error
                 (Error.of_string
                    "Ledger update and requested update are incompatible" ) ) )
        )
    in
    (* Log snark work as it comes in. *)
    don't_wait_for
      (let rec go () =
         let open Deferred.Let_syntax in
         match%bind wait_for t (Wait_condition.snark_work ()) with
         | Ok _ ->
             [%log info] "Received new snark work" ;
             go ()
         | Error _ ->
             Deferred.return ()
       in
       go () ) ;
    let%bind () =
      section_hard "Wait for proof to be emitted"
        (wait_for t
           (Wait_condition.ledger_proofs_emitted_since_genesis ~num_proofs:1) )
    in
    section_hard "Running replayer"
      (let%bind logs =
         Network.Node.run_replayer ~logger
           (List.hd_exn @@ Network.archive_nodes network)
       in
       check_replayer_logs ~logger logs )
end
