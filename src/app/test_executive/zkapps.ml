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
    ; genesis_ledger =
        [ { account_name = "node-a-key"
          ; balance = "8000000000"
          ; timing = Untimed
          }
        ; { account_name = "node-b-key"
          ; balance = "1000000000"
          ; timing = Untimed
          }
        ; { account_name = "fish1"; balance = "3000"; timing = Untimed }
        ; { account_name = "fish2"; balance = "3000"; timing = Untimed }
        ; { account_name = "snark-node-key"; balance = "0"; timing = Untimed }
        ]
    ; block_producers =
        [ { node_name = "node-a"; account_name = "node-a-key" }
        ; { node_name = "node-b"; account_name = "node-b-key" }
        ]
    ; num_archive_nodes = 1
    ; snark_coordinator =
        Some
          { node_name = "snark-node"
          ; account_name = "snark-node-key"
          ; worker_nodes = 2
          }
    ; snark_worker_fee = "0.0001"
    ; proof_config =
        { proof_config_default with
          work_delay = Some 1
        ; transaction_capacity =
            Some Runtime_config.Proof_keys.Transaction_capacity.small
        }
    }

  let transactions_sent = ref 0

  let send_zkapp ~logger node zkapp_command =
    incr transactions_sent ;
    send_zkapp ~logger node zkapp_command

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
    let%bind sender_pub_key = pub_key_of_node sender in
    let%bind receiver_pub_key = pub_key_of_node receiver in
    repeat_seq ~n ~f:(fun () ->
        Network.Node.must_send_payment ~logger sender ~sender_pub_key
          ~receiver_pub_key ~amount:Currency.Amount.one ~fee
        >>| ignore )

  let payment_receiver =
    Signature_lib.(Public_key.compress (Keypair.create ()).public_key)

  let send_payment_from_zkapp_account ?expected_failure
      ~(constraint_constants : Genesis_constants.Constraint_constants.t) ~logger
      ~node (sender : Signature_lib.Keypair.t) nonce =
    let sender_pk = Signature_lib.Public_key.compress sender.public_key in
    let receiver_pk = payment_receiver in
    let amount =
      Currency.Amount.of_fee constraint_constants.account_creation_fee
    in
    let memo = "" in
    let valid_until = Mina_numbers.Global_slot_since_genesis.max_value in
    let fee = Currency.Fee.of_nanomina_int_exn 1_000_000 in
    let payload =
      let common =
        { Signed_command_payload.Common.Poly.fee
        ; fee_payer_pk = sender_pk
        ; nonce
        ; valid_until
        ; memo = Signed_command_memo.empty
        }
      in
      let payment_payload = { Payment_payload.Poly.receiver_pk; amount } in
      let body = Signed_command_payload.Body.Payment payment_payload in
      { Signed_command_payload.Poly.common; body }
    in
    let raw_signature =
      Signed_command.sign_payload sender.private_key payload
      |> Signature.Raw.encode
    in
    match expected_failure with
    | Some failure ->
        send_invalid_payment ~logger ~sender_pub_key:sender_pk
          ~receiver_pub_key:receiver_pk ~amount ~fee ~nonce ~memo ~valid_until
          ~raw_signature ~expected_failure:failure node
    | None ->
        incr transactions_sent ;
        Network.Node.must_send_payment_with_raw_sig ~logger
          ~sender_pub_key:sender_pk ~receiver_pub_key:receiver_pk ~amount ~fee
          ~nonce ~memo ~valid_until ~raw_signature node
        |> Malleable_error.ignore_m

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let block_producer_nodes =
      Network.block_producers network |> Core.String.Map.data
    in
    (* TODO: capture snark worker processes' failures *)
    let%bind () =
      section_hard "Wait for nodes to initialize"
        (wait_for t
           ( Wait_condition.nodes_to_initialize
           @@ (Network.all_nodes network |> Core.String.Map.data) ) )
    in
    let node =
      Core.String.Map.find_exn (Network.block_producers network) "node-a"
    in
    let constraint_constants = Network.constraint_constants network in
    let fish1_kp =
      (Core.String.Map.find_exn (Network.genesis_keypairs network) "fish1")
        .keypair
    in
    let fish2_kp =
      (Core.String.Map.find_exn (Network.genesis_keypairs network) "fish2")
        .keypair
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
    let%bind zkapp_command_create_accounts =
      (* construct a Zkapp_command.t, similar to zkapp_test_transaction create-zkapp-account *)
      let amount = Currency.Amount.of_mina_int_exn 10 in
      let nonce = Account.Nonce.zero in
      let memo =
        Signed_command_memo.create_from_string_exn "Zkapp create account"
      in
      let fee = Currency.Fee.of_nanomina_int_exn 20_000_000 in
      let (zkapp_command_spec : Transaction_snark.For_tests.Deploy_snapp_spec.t)
          =
        { sender = (fish1_kp, nonce)
        ; fee
        ; fee_payer = None
        ; amount
        ; zkapp_account_keypairs = zkapp_keypairs
        ; memo
        ; new_zkapp_account = true
        ; snapp_update = Account_update.Update.dummy
        ; preconditions = None
        ; authorization_kind = Signature
        }
      in
      return
      @@ Transaction_snark.For_tests.deploy_snapp ~constraint_constants
           zkapp_command_spec
    in
    let%bind.Deferred zkapp_command_update_permissions, permissions_updated =
      (* construct a Zkapp_command.t, similar to zkapp_test_transaction update-permissions *)
      let nonce = Account.Nonce.zero in
      let memo =
        Signed_command_memo.create_from_string_exn "Zkapp update permissions"
      in
      (* Lower fee so that zkapp_command_create_accounts gets applied first *)
      let fee = Currency.Fee.of_nanomina_int_exn 10_000_000 in
      let new_permissions : Permissions.t =
        { Permissions.user_default with
          edit_state = Permissions.Auth_required.Proof
        ; edit_action_state = Proof
        ; set_delegate = Proof
        ; set_verification_key = Proof
        ; set_permissions = Proof
        ; set_zkapp_uri = Proof
        ; set_token_symbol = Proof
        ; set_voting_for = Proof
        ; set_timing = Proof
        ; send = Proof
        }
      in
      let (zkapp_command_spec : Transaction_snark.For_tests.Update_states_spec.t)
          =
        { sender = (fish2_kp, nonce)
        ; fee
        ; fee_payer = None
        ; receivers = []
        ; amount = Currency.Amount.zero
        ; zkapp_account_keypairs = zkapp_keypairs
        ; memo
        ; new_zkapp_account = false
        ; snapp_update =
            { Account_update.Update.dummy with
              permissions = Set new_permissions
            }
        ; current_auth =
            (* current set_permissions permission requires Signature *)
            Permissions.Auth_required.Signature
        ; call_data = Snark_params.Tick.Field.zero
        ; events = []
        ; actions = []
        ; preconditions = None
        }
      in
      let%map.Deferred zkapp_command =
        Transaction_snark.For_tests.update_states ~constraint_constants
          zkapp_command_spec
      in
      (zkapp_command, new_permissions)
    in
    let%bind.Deferred ( zkapp_update_all
                      , zkapp_command_update_all
                      , zkapp_command_invalid_nonce
                      , zkapp_command_insufficient_funds
                      , zkapp_command_insufficient_replace_fee
                      , zkapp_command_insufficient_fee ) =
      let amount = Currency.Amount.zero in
      let nonce = Account.Nonce.of_int 1 in
      let memo =
        Signed_command_memo.create_from_string_exn "Zkapp update all"
      in
      let fee = Currency.Fee.of_nanomina_int_exn 10_000_000 in
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
      let snapp_update : Account_update.Update.t =
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
      let (zkapp_command_spec : Transaction_snark.For_tests.Update_states_spec.t)
          =
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
        ; actions = []
        ; preconditions = None
        }
      in
      let%bind.Deferred zkapp_command_update_all =
        Transaction_snark.For_tests.update_states ~constraint_constants
          zkapp_command_spec
      in
      let%bind.Deferred zkapp_command_invalid_nonce =
        Transaction_snark.For_tests.update_states ~constraint_constants
          { zkapp_command_spec with
            sender = (fish2_kp, Account.Nonce.max_value)
          }
      in
      let%bind.Deferred zkapp_command_insufficient_funds =
        Transaction_snark.For_tests.update_states ~constraint_constants
          { zkapp_command_spec with fee = Currency.Fee.max_int }
      in
      let%bind.Deferred zkapp_command_insufficient_replace_fee =
        let spec_insufficient_replace_fee :
            Transaction_snark.For_tests.Update_states_spec.t =
          { zkapp_command_spec with
            fee = Currency.Fee.of_nanomina_int_exn 5_000_000
          }
        in
        Transaction_snark.For_tests.update_states ~constraint_constants
          spec_insufficient_replace_fee
      in
      let%map.Deferred zkapp_command_insufficient_fee =
        let spec_insufficient_fee :
            Transaction_snark.For_tests.Update_states_spec.t =
          { zkapp_command_spec with
            fee = Currency.Fee.of_nanomina_int_exn 1000
          }
        in
        Transaction_snark.For_tests.update_states ~constraint_constants
          spec_insufficient_fee
      in
      ( snapp_update
      , zkapp_command_update_all
      , zkapp_command_invalid_nonce
      , zkapp_command_insufficient_funds
      , zkapp_command_insufficient_replace_fee
      , zkapp_command_insufficient_fee )
    in
    let zkapp_command_invalid_signature =
      let p = zkapp_command_update_all in
      { p with
        fee_payer =
          { body = { p.fee_payer.body with nonce = Account.Nonce.of_int 2 }
          ; authorization = Signature.dummy
          }
      }
    in
    let zkapp_command_invalid_proof =
      let p = zkapp_command_update_all in
      Zkapp_command.
        { p with
          account_updates =
            Call_forest.map p.account_updates ~f:(fun other_p ->
                match other_p.Account_update.authorization with
                | Proof _ ->
                    { other_p with
                      authorization =
                        Control.Proof Mina_base.Proof.blockchain_dummy
                    }
                | _ ->
                    other_p )
        }
    in
    let%bind.Deferred zkapp_command_nonexistent_fee_payer =
      let new_kp = Signature_lib.Keypair.create () in
      let memo =
        Signed_command_memo.create_from_string_exn "Non-existent account"
      in
      let fee = Currency.Fee.of_nanomina_int_exn 10_000_000 in
      let spec : Transaction_snark.For_tests.Update_states_spec.t =
        { sender = (new_kp, Account.Nonce.zero)
        ; fee
        ; fee_payer = None
        ; receivers = []
        ; amount = Currency.Amount.zero
        ; zkapp_account_keypairs = zkapp_keypairs
        ; memo
        ; new_zkapp_account = false
        ; snapp_update = Account_update.Update.dummy
        ; current_auth = Permissions.Auth_required.None
        ; call_data = Snark_params.Tick.Field.zero
        ; events = []
        ; actions = []
        ; preconditions = None
        }
      in
      Transaction_snark.For_tests.update_states ~constraint_constants spec
    in
    let%bind.Deferred ( zkapp_command_mint_token
                      , zkapp_command_mint_token2
                      , zkapp_command_token_transfer
                      , zkapp_command_token_transfer2 ) =
      (* similar to tokens tests in transaction_snark/tests/zkapp_tokens.ml
         and `Mina_ledger.Ledger`

         the token owner account has already been created here, so don't
         need that as a separate transaction
      *)
      let account_creation_fee_int =
        Currency.Fee.to_nanomina_int constraint_constants.account_creation_fee
      in
      let token_funder = fish1_kp in
      let token_owner = fish2_kp in
      let token_accounts =
        Array.init 4 ~f:(fun _ -> Signature_lib.Keypair.create ())
      in
      let custom_token_id =
        Account_id.derive_token_id
          ~owner:
            (Account_id.create
               (Signature_lib.Public_key.compress token_owner.public_key)
               Token_id.default )
      in
      let custom_token_id2 =
        Account_id.derive_token_id
          ~owner:
            (Account_id.create
               (Signature_lib.Public_key.compress token_owner.public_key)
               custom_token_id )
      in
      let keymap =
        List.fold
          ([ token_funder; token_owner ] @ Array.to_list token_accounts)
          ~init:Signature_lib.Public_key.Compressed.Map.empty
          ~f:(fun map { private_key; public_key } ->
            Signature_lib.Public_key.Compressed.Map.add_exn map
              ~key:(Signature_lib.Public_key.compress public_key)
              ~data:private_key )
      in
      let fee_payer_pk =
        Signature_lib.Public_key.compress token_funder.public_key
      in
      let%bind.Deferred zkapp_command_mint_token =
        let open Zkapp_command_builder in
        let with_dummy_signatures =
          mk_forest
            [ mk_node
                (mk_account_update_body Signature No token_owner
                   Token_id.default
                   (-account_creation_fee_int) )
                [ mk_node
                    (mk_account_update_body Signature Parents_own_token
                       token_accounts.(0) custom_token_id 10000 )
                    []
                ]
            ]
          |> mk_zkapp_command ~memo:"mint token" ~fee:12_000_000 ~fee_payer_pk
               ~fee_payer_nonce:(Account.Nonce.of_int 1)
        in
        replace_authorizations ~keymap with_dummy_signatures
      in
      let%bind.Deferred zkapp_command_mint_token2 =
        let open Zkapp_command_builder in
        let with_dummy_signatures =
          mk_forest
            [ mk_node
                (mk_account_update_body Signature No token_owner
                   Token_id.default
                   (-2 * account_creation_fee_int) )
                [ mk_node
                    (mk_account_update_body Signature Parents_own_token
                       token_owner custom_token_id 0 )
                    [ mk_node
                        (mk_account_update_body Signature Parents_own_token
                           token_accounts.(2) custom_token_id2 500 )
                        []
                    ]
                ]
            ]
          |> mk_zkapp_command ~memo:"zkapp to mint token2" ~fee:11_500_000
               ~fee_payer_pk ~fee_payer_nonce:(Account.Nonce.of_int 2)
        in
        replace_authorizations ~keymap with_dummy_signatures
      in
      let%bind.Deferred zkapp_command_token_transfer =
        let open Zkapp_command_builder in
        (* lower fee than minting Zkapp_command.t *)
        let with_dummy_signatures =
          mk_forest
            [ mk_node
                (mk_account_update_body Signature No token_owner
                   Token_id.default
                   (-account_creation_fee_int) )
                [ mk_node
                    (mk_account_update_body Signature Parents_own_token
                       token_accounts.(0) custom_token_id (-30) )
                    []
                ; mk_node
                    (mk_account_update_body Signature Parents_own_token
                       token_accounts.(1) custom_token_id 30 )
                    []
                ; mk_node
                    (mk_account_update_body Signature No token_funder
                       Token_id.default (-50) )
                    []
                ; mk_node
                    (mk_account_update_body Signature No token_funder
                       Token_id.default 50 )
                    []
                ]
            ]
          |> mk_zkapp_command ~memo:"zkapp for tokens transfer" ~fee:11_000_000
               ~fee_payer_pk ~fee_payer_nonce:(Account.Nonce.of_int 3)
        in
        replace_authorizations ~keymap with_dummy_signatures
      in
      let%map.Deferred zkapp_command_token_transfer2 =
        let open Zkapp_command_builder in
        (* lower fee than first tokens transfer *)
        let with_dummy_signatures =
          mk_forest
            [ mk_node
                (mk_account_update_body Signature No token_owner
                   Token_id.default
                   (-account_creation_fee_int) )
                [ mk_node
                    (mk_account_update_body Signature Parents_own_token
                       token_accounts.(1) custom_token_id (-5) )
                    []
                ; mk_node
                    (mk_account_update_body Signature Parents_own_token
                       token_accounts.(0) custom_token_id 5 )
                    []
                ; mk_node
                    (mk_account_update_body Signature Parents_own_token
                       token_owner custom_token_id 0 )
                    [ mk_node
                        (mk_account_update_body Signature Parents_own_token
                           token_accounts.(2) custom_token_id2 (-210) )
                        []
                    ; mk_node
                        (mk_account_update_body Signature Parents_own_token
                           token_accounts.(3) custom_token_id2 210 )
                        []
                    ]
                ]
            ]
          |> mk_zkapp_command ~memo:"zkapp for tokens transfer 2"
               ~fee:10_000_000 ~fee_payer_pk
               ~fee_payer_nonce:(Account.Nonce.of_int 4)
        in
        replace_authorizations ~keymap with_dummy_signatures
      in
      ( zkapp_command_mint_token
      , zkapp_command_mint_token2
      , zkapp_command_token_transfer
      , zkapp_command_token_transfer2 )
    in
    let with_timeout =
      let soft_slots = 4 in
      let soft_timeout = Network_time_span.Slots soft_slots in
      let hard_timeout = Network_time_span.Slots (soft_slots * 2) in
      Wait_condition.with_timeouts ~soft_timeout ~hard_timeout
    in
    let wait_for_zkapp zkapp_command =
      let%map () =
        wait_for t @@ with_timeout
        @@ Wait_condition.zkapp_to_be_included_in_frontier ~has_failures:false
             ~zkapp_command
      in
      [%log info] "ZkApp transaction included in transition frontier"
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
    let compatible_updates ~(ledger_update : Account_update.Update.t)
        ~(requested_update : Account_update.Update.t) : bool =
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
          ~equal:Account_update.Update.Timing_info.equal
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
    let snark_work_event_subscription =
      Event_router.on (event_router t) Snark_work_gossip
        ~f:(fun _ (_, direction) ->
          ( match direction with
          | Sent ->
              ()
          | Received ->
              [%log info] "Received new snark work" ) ;
          Deferred.return `Continue )
    in
    let snark_work_failure_subscription =
      Event_router.on (event_router t) Snark_work_failed ~f:(fun _ failure ->
          [%log error]
            "A snark worker encountered an error while creating a proof: \
             $failure"
            ~metadata:
              [ ("failure", Event_type.Snark_work_failed.to_yojson failure) ] ;
          Deferred.return `Continue )
    in
    let%bind () =
      section_hard "Send a zkApp transaction to create zkApp accounts"
        (send_zkapp ~logger node zkapp_command_create_accounts)
    in
    let%bind () =
      section_hard
        "Wait for zkapp to create accounts to be included in transition \
         frontier"
        (wait_for_zkapp zkapp_command_create_accounts)
    in
    let%bind () =
      let sender = List.hd_exn zkapp_keypairs in
      let nonce = Account.Nonce.zero in
      section_hard "Send a valid payment from zkApp account"
        (send_payment_from_zkapp_account ~constraint_constants ~node ~logger
           sender nonce )
    in
    let%bind () =
      section_hard "Send a zkApp transaction to update permissions"
        (send_zkapp ~logger node zkapp_command_update_permissions)
    in
    let%bind () =
      section_hard
        "Wait for zkApp transaction to update permissions to be included in \
         transition frontier"
        (wait_for_zkapp zkapp_command_update_permissions)
    in
    let%bind () =
      let sender = List.hd_exn zkapp_keypairs in
      let nonce = Account.Nonce.of_int 1 in
      section_hard "Send an invalid payment from zkApp account"
        (send_payment_from_zkapp_account ~constraint_constants ~logger sender
           nonce ~node
           ~expected_failure:
             Network_pool.Transaction_pool.Diff_versioned.Diff_error.(
               to_string_name Fee_payer_not_permitted_to_send) )
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
        (send_invalid_zkapp ~logger node zkapp_command_insufficient_fee
           "Insufficient fee" )
    in
    (* Won't be accepted until the previous transactions are applied *)
    let%bind () =
      section_hard "Send a zkApp transaction to update all fields"
        (send_zkapp ~logger node zkapp_command_update_all)
    in
    let%bind () =
      section_hard "Send a zkapp with an invalid proof"
        (send_invalid_zkapp ~logger node zkapp_command_invalid_proof
           "Verification_failed" )
    in
    let%bind () =
      section_hard "Send a zkapp with an insufficient replace fee"
        (send_invalid_zkapp ~logger node zkapp_command_insufficient_replace_fee
           "Insufficient_replace_fee" )
    in
    let%bind () =
      section_hard "Send a zkApp transaction with an invalid nonce"
        (send_invalid_zkapp ~logger node zkapp_command_invalid_nonce
           "Invalid_nonce" )
    in
    let%bind () =
      section_hard
        "Send a zkApp transaction with insufficient_funds, fee too high"
        (send_invalid_zkapp ~logger node zkapp_command_insufficient_funds
           "Insufficient_funds" )
    in
    let%bind () =
      section_hard "Send a zkApp transaction with an invalid signature"
        (send_invalid_zkapp ~logger node zkapp_command_invalid_signature
           "Verification_failed" )
    in
    let%bind () =
      section_hard "Send a zkApp transaction with a nonexistent fee payer"
        (send_invalid_zkapp ~logger node zkapp_command_nonexistent_fee_payer
           "Fee_payer_account_not_found" )
    in
    let%bind () =
      section_hard
        "Wait for zkApp transaction to update all fields to be included in \
         transition frontier"
        (wait_for_zkapp zkapp_command_update_all)
    in
    let%bind () =
      section_hard "Send a zkApp transaction to mint token"
        (send_zkapp ~logger node zkapp_command_mint_token)
    in
    let%bind () =
      section_hard "Send a zkApp transaction to mint 2nd token"
        (send_zkapp ~logger node zkapp_command_mint_token2)
    in
    let%bind () =
      section_hard "Send a zkApp transaction to transfer tokens"
        (send_zkapp ~logger node zkapp_command_token_transfer)
    in
    let%bind () =
      section_hard "Send a zkApp transaction to transfer tokens (2)"
        (send_zkapp ~logger node zkapp_command_token_transfer2)
    in
    let%bind () =
      section_hard "Wait for zkApp transaction to mint token"
        (wait_for_zkapp zkapp_command_mint_token)
    in
    let%bind () =
      section_hard "Wait for zkApp transaction to mint 2nd token"
        (wait_for_zkapp zkapp_command_mint_token2)
    in
    let%bind () =
      section_hard "Wait for zkApp transaction to transfer tokens"
        (wait_for_zkapp zkapp_command_token_transfer)
    in
    let%bind () =
      section_hard "Wait for zkApp transaction to transfer tokens (2)"
        (wait_for_zkapp zkapp_command_token_transfer2)
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
                   [ ( "ledger_update"
                     , Account_update.Update.to_yojson ledger_update )
                   ; ( "requested_update"
                     , Account_update.Update.to_yojson zkapp_update_all )
                   ] ;
               Malleable_error.hard_error
                 (Error.of_string
                    "Ledger update and requested update are incompatible" ) ) )
        )
    in
    let%bind () =
      let padding_payments =
        (* for work_delay=1 and transaction_capacity=4 per block*)
        let needed = 36 in
        if !transactions_sent >= needed then 0 else needed - !transactions_sent
      in
      let fee = Currency.Fee.of_nanomina_int_exn 1_000_000 in
      send_padding_transactions block_producer_nodes ~fee ~logger
        ~n:padding_payments
    in
    let%bind () =
      section_hard "Wait for proof to be emitted"
        (wait_for t
           (Wait_condition.ledger_proofs_emitted_since_genesis
              ~test_config:config ~num_proofs:1 ) )
    in
    Event_router.cancel (event_router t) snark_work_event_subscription () ;
    Event_router.cancel (event_router t) snark_work_failure_subscription () ;
    section_hard "Running replayer"
      (let%bind logs =
         Network.Node.run_replayer ~logger
           (List.hd_exn @@ (Network.archive_nodes network |> Core.Map.data))
       in
       check_replayer_logs ~logger logs )
end
