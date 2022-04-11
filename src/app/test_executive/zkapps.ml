open Core
open Async
open Integration_test_lib

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
    let open Test_config.Block_producer in
    let keypair =
      let private_key = Signature_lib.Private_key.create () in
      let public_key =
        Signature_lib.Public_key.of_private_key_exn private_key
      in
      { Signature_lib.Keypair.private_key; public_key }
    in
    { default with
      requires_graphql = true
    ; block_producers =
        [ { balance = "8000000000"; timing = Untimed }
        ; { balance = "1000000000"; timing = Untimed }
        ]
    ; extra_genesis_accounts = [ { keypair; balance = "1000" } ]
    ; num_snark_workers = 2
    ; snark_worker_fee = "0.0001"
    ; work_delay = Some 1
    ; transaction_capacity =
        Some Runtime_config.Proof_keys.Transaction_capacity.small
    }

  let transactions_sent = ref 0

  let send_zkapp ~logger node parties =
    incr transactions_sent ;
    send_zkapp ~logger node parties

  (* An event which fires when [n] ledger proofs have been emitted *)
  let ledger_proofs_emitted ~logger ~num_proofs =
    Wait_condition.network_state ~description:"snarked ledger emitted"
      ~f:(fun network_state ->
        [%log info] "snarked ledgers generated = %d"
          network_state.snarked_ledgers_generated ;
        let module T = struct
          type t = (string * Mina_base.State_hash.t) list [@@deriving to_yojson]
        end in
        network_state.snarked_ledgers_generated >= num_proofs)
    |> Wait_condition.with_timeouts ~soft_timeout:(Slots 15)
         ~hard_timeout:(Slots 20)

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
        >>| ignore)

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let block_producer_nodes = Network.block_producers network in
    let%bind () =
      Malleable_error.List.iter block_producer_nodes
        ~f:(Fn.compose (wait_for t) Wait_condition.node_to_initialize)
    in
    let node = List.hd_exn block_producer_nodes in
    let constraint_constants =
      Genesis_constants.Constraint_constants.compiled
    in
    let%bind fee_payer_pk = Util.pub_key_of_node node in
    let%bind fee_payer_sk = Util.priv_key_of_node node in
    let (keypair : Signature_lib.Keypair.t) =
      { public_key = fee_payer_pk |> Signature_lib.Public_key.decompress_exn
      ; private_key = fee_payer_sk
      }
    in
    let keypair2 = (List.hd_exn config.extra_genesis_accounts).keypair in
    let num_zkapp_accounts = 3 in
    let snapp_keypairs =
      List.init num_zkapp_accounts ~f:(fun _ -> Signature_lib.Keypair.create ())
    in
    let zkapp_account_ids =
      List.map snapp_keypairs ~f:(fun snapp_keypair ->
          Mina_base.Account_id.create
            (snapp_keypair.public_key |> Signature_lib.Public_key.compress)
            Mina_base.Token_id.default)
    in
    let fee = Currency.Fee.of_int 1_000_000 in
    let%bind parties_create_account =
      (* construct a Parties.t, similar to zkapp_test_transaction create-snapp-account *)
      let open Mina_base in
      let amount = Currency.Amount.of_int 10_000_000_000 in
      let nonce = Account.Nonce.zero in
      let memo =
        Signed_command_memo.create_from_string_exn "Snapp create account"
      in
      let (parties_spec : Transaction_snark.For_tests.Spec.t) =
        { sender = (keypair, nonce)
        ; fee
        ; receivers = []
        ; amount
        ; zkapp_account_keypairs = snapp_keypairs
        ; memo
        ; new_zkapp_account = true
        ; snapp_update = Party.Update.dummy
        ; current_auth = Permissions.Auth_required.Signature
        ; call_data = Snark_params.Tick.Field.zero
        ; events = []
        ; sequence_events = []
        }
      in
      return
      @@ Transaction_snark.For_tests.deploy_snapp ~constraint_constants
           parties_spec
    in
    let%bind.Deferred parties_update_permissions, permissions_updated =
      (* construct a Parties.t, similar to zkapp_test_transaction update-permissions *)
      let open Mina_base in
      let nonce = Account.Nonce.zero in
      let memo =
        Signed_command_memo.create_from_string_exn "Snapp update permissions"
      in
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
        { sender = (keypair2, nonce)
        ; fee
        ; receivers = []
        ; amount = Currency.Amount.zero
        ; zkapp_account_keypairs = snapp_keypairs
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
        }
      in
      let%map.Deferred parties =
        Transaction_snark.For_tests.update_states ~constraint_constants
          parties_spec
      in
      (parties, new_permissions)
    in
    let%bind.Deferred snapp_update_all, parties_update_all =
      let open Mina_base in
      let amount = Currency.Amount.zero in
      let nonce = Account.Nonce.of_int 1 in
      let memo =
        Signed_command_memo.create_from_string_exn "Snapp update all"
      in
      let app_state =
        let len = Zkapp_state.Max_state_size.n |> Pickles_types.Nat.to_int in
        let fields =
          Quickcheck.random_value
            (Quickcheck.Generator.list_with_length len
               Snark_params.Tick.Field.gen)
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
        { sender = (keypair2, nonce)
        ; fee
        ; receivers = []
        ; amount
        ; zkapp_account_keypairs = snapp_keypairs
        ; memo
        ; new_zkapp_account = false
        ; snapp_update
        ; current_auth = Permissions.Auth_required.Proof
        ; call_data = Snark_params.Tick.Field.zero
        ; events = []
        ; sequence_events = []
        }
      in
      let%map.Deferred parties_update_all =
        Transaction_snark.For_tests.update_states ~constraint_constants
          parties_spec
      in
      (snapp_update, parties_update_all)
    in
    let parties_invalid_nonce =
      let p = parties_update_all in
      { p with
        fee_payer =
          { p.fee_payer with
            body =
              { p.fee_payer.body with
                account_precondition = Mina_base.Account.Nonce.of_int 42
              }
          }
      }
    in
    let parties_invalid_signature =
      let p = parties_update_all in
      { p with
        fee_payer =
          { body =
              { p.fee_payer.body with
                account_precondition = Mina_base.Account.Nonce.of_int 2
              }
          ; authorization = Mina_base.Signature.dummy
          }
      }
    in
    let with_timeout =
      let soft_slots = 4 in
      let soft_timeout = Network_time_span.Slots soft_slots in
      let hard_timeout = Network_time_span.Slots (soft_slots * 2) in
      Wait_condition.with_timeouts ~soft_timeout ~hard_timeout
    in
    let compatible req_item ledg_item ~equal =
      match (req_item, ledg_item) with
      | Mina_base.Zkapp_basic.Set_or_keep.Keep, _ ->
          true
      | Set v1, Mina_base.Zkapp_basic.Set_or_keep.Set v2 ->
          equal v1 v2
      | Set _, Keep ->
          false
    in
    let compatible_updates ~(ledger_update : Mina_base.Party.Update.t)
        ~(requested_update : Mina_base.Party.Update.t) : bool =
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
            compatible req ledg ~equal:Pickles.Backend.Tick.Field.equal)
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
          ~equal:Mina_base.Permissions.equal
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
          ~equal:Mina_base.Party.Update.Timing_info.equal
      in
      let voting_fors_compat =
        compatible requested_update.voting_for ledger_update.voting_for
          ~equal:Mina_base.State_hash.equal
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
    let wait_for_snapp parties =
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
      section_hard
        "Wait for zkApp to create accounts to be included in transition \
         frontier"
        (wait_for_snapp parties_create_account)
    in
    let%bind () =
      section_hard "Send a zkApp transaction to update permissions"
        (send_zkapp ~logger node parties_update_permissions)
    in
    let%bind () =
      section_hard
        "Wait for zkApp transaction to update permissions to be included in \
         transition frontier"
        (wait_for_snapp parties_update_permissions)
    in
    let%bind () =
      section_hard "Verify that updated permissions are in ledger accounts"
        (Malleable_error.List.iter zkapp_account_ids ~f:(fun account_id ->
             [%log info] "Verifying permissions for account"
               ~metadata:
                 [ ("account_id", Mina_base.Account_id.to_yojson account_id) ] ;
             let%bind ledger_permissions =
               get_account_permissions ~logger node account_id
             in
             if
               Mina_base.Permissions.equal ledger_permissions
                 permissions_updated
             then (
               [%log info] "Ledger, updated permissions are equal" ;
               return () )
             else (
               [%log error] "Ledger, updated permissions differ"
                 ~metadata:
                   [ ( "ledger_permissions"
                     , Mina_base.Permissions.to_yojson ledger_permissions )
                   ; ( "updated_permissions"
                     , Mina_base.Permissions.to_yojson permissions_updated )
                   ] ;
               Malleable_error.hard_error
                 (Error.of_string
                    "Ledger permissions do not match update permissions") )))
    in
    (*Won't be accepted until the previous transactions are applied*)
    let%bind () =
      section_hard "Send a zkApp transaction to update all fields"
        (send_zkapp ~logger node parties_update_all)
    in
    let%bind () =
      section_hard
        "Wait for snapp to update all fields to be included in transition \
         frontier"
        (wait_for_snapp parties_update_all)
    in
    let%bind () =
      section_hard "Verify zkApp updates in ledger"
        (Malleable_error.List.iter zkapp_account_ids ~f:(fun account_id ->
             [%log info] "Verifying updates for account"
               ~metadata:
                 [ ("account_id", Mina_base.Account_id.to_yojson account_id) ] ;
             let%bind ledger_update =
               get_account_update ~logger node account_id
             in
             if
               compatible_updates ~ledger_update
                 ~requested_update:snapp_update_all
             then (
               [%log info] "Ledger update and requested update are compatible" ;
               return () )
             else (
               [%log error]
                 "Ledger update and requested update are incompatible"
                 ~metadata:
                   [ ( "ledger_update"
                     , Mina_base.Party.Update.to_yojson ledger_update )
                   ; ( "requested_update"
                     , Mina_base.Party.Update.to_yojson snapp_update_all )
                   ] ;
               Malleable_error.hard_error
                 (Error.of_string
                    "Ledger update and requested update are incompatible") )))
    in
    let%bind () =
      let padding_payments =
        (* for work_delay=1 and transaction_capacity=4 per block*)
        let needed = 12 in
        if !transactions_sent >= needed then 0 else needed - !transactions_sent
      in
      send_padding_transactions block_producer_nodes ~fee ~logger
        ~n:padding_payments
    in
    let%bind () =
      section_hard "Send a zkApp transaction with an invalid nonce"
        (send_invalid_zkapp ~logger node parties_invalid_nonce "Invalid_nonce")
    in
    let%bind () =
      section_hard "Send a zkApp transaction with an invalid signature"
        (send_invalid_zkapp ~logger node parties_invalid_signature
           "Invalid_signature")
    in
    let%bind () =
      section_hard "Wait for proof to be emitted"
        (wait_for t (ledger_proofs_emitted ~logger ~num_proofs:1))
    in
    return ()
end
