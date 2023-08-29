(* hard_fork.ml -- run nodes with fork config, epoch ledger *)

open Core
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

  let fork_config : Runtime_config.Fork_config.t =
    { previous_state_hash =
        "3NKSiqFZQmAS12U8qeX4KNo8b4199spwNh7mrSs4Ci1Vacpfix2Q"
    ; previous_length = 300000
    ; previous_global_slot = 500000
    }

  let config =
    let open Test_config in
    let staking_accounts : Test_Account.t list =
      [ { account_name = "node-a-key"; balance = "400000"; timing = Untimed }
      ; { account_name = "node-b-key"; balance = "300000"; timing = Untimed }
      ; { account_name = "snark-node-key1"; balance = "0"; timing = Untimed }
      ; { account_name = "snark-node-key2"; balance = "0"; timing = Untimed }
      ]
    in
    let staking : Test_config.Epoch_data.Data.t =
      let epoch_seed =
        Epoch_seed.to_base58_check Snark_params.Tick.Field.(of_int 42)
      in
      let epoch_ledger = staking_accounts in
      { epoch_ledger; epoch_seed }
    in
    (* next accounts contains staking accounts, with balances changed, one new account *)
    let next_accounts : Test_Account.t list =
      [ { account_name = "node-a-key"; balance = "200000"; timing = Untimed }
      ; { account_name = "node-b-key"; balance = "350000"; timing = Untimed }
      ; { account_name = "snark-node-key1"; balance = "0"; timing = Untimed }
      ; { account_name = "snark-node-key2"; balance = "0"; timing = Untimed }
      ; { account_name = "fish1"; balance = "100"; timing = Untimed }
      ]
    in
    let next : Test_config.Epoch_data.Data.t =
      let epoch_seed =
        Epoch_seed.to_base58_check Snark_params.Tick.Field.(of_int 1729)
      in
      let epoch_ledger = next_accounts in
      { epoch_ledger; epoch_seed }
    in
    { default with
      requires_graphql = true
    ; epoch_data = Some { staking; next = Some next }
    ; genesis_ledger =
        (* the genesis ledger contains the staking ledger plus some other accounts *)
        staking_accounts
        @ [ { account_name = "fish1"; balance = "100"; timing = Untimed }
          ; { account_name = "fish2"; balance = "100"; timing = Untimed }
          ; { account_name = "fish3"; balance = "1000"; timing = Untimed }
          ]
    ; block_producers =
        [ { node_name = "node-a"; account_name = "node-a-key" }
        ; { node_name = "node-b"; account_name = "node-b-key" }
        ]
    ; snark_coordinator =
        Some
          { node_name = "snark-node"
          ; account_name = "snark-node-key1"
          ; worker_nodes = 4
          }
    ; snark_worker_fee = "0.0002"
    ; num_archive_nodes = 1
    ; proof_config =
        { proof_config_default with
          work_delay = Some 1
        ; transaction_capacity =
            Some Runtime_config.Proof_keys.Transaction_capacity.small
        ; fork = Some fork_config
        }
    }

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let all_nodes = Network.all_nodes network in
    let%bind () =
      wait_for t
        (Wait_condition.nodes_to_initialize (Core.String.Map.data all_nodes))
    in
    let node_a =
      Core.String.Map.find_exn (Network.block_producers network) "node-a"
    in
    let node_b =
      Core.String.Map.find_exn (Network.block_producers network) "node-b"
    in
    let fish1 =
      Core.String.Map.find_exn (Network.genesis_keypairs network) "fish1"
    in
    let fish2 =
      Core.String.Map.find_exn (Network.genesis_keypairs network) "fish2"
    in
    let sender = fish2.keypair in
    let receiver = fish1.keypair in
    [%log info] "extra genesis keypairs: %s"
      (List.to_string [ fish1.keypair; fish2.keypair ]
         ~f:(fun { Signature_lib.Keypair.public_key; _ } ->
           public_key |> Signature_lib.Public_key.to_bigstring
           |> Bigstring.to_string ) ) ;
    let receiver_pub_key =
      receiver.public_key |> Signature_lib.Public_key.compress
    in
    let sender_pub_key =
      sender.public_key |> Signature_lib.Public_key.compress
    in
    let sender_account_id = Account_id.create sender_pub_key Token_id.default in
    let%bind { nonce = sender_current_nonce; _ } =
      Integration_test_lib.Graphql_requests.must_get_account_data ~logger
        (Network.Node.get_ingress_uri node_b)
        ~account_id:sender_account_id
    in
    let amount = Currency.Amount.of_mina_string_exn "10" in
    let fee = Currency.Fee.of_mina_string_exn "1" in
    let memo = "" in
    let valid_until = Mina_numbers.Global_slot_since_genesis.max_value in
    let payload =
      let payment_payload =
        { Payment_payload.Poly.receiver_pk = receiver_pub_key; amount }
      in
      let body = Signed_command_payload.Body.Payment payment_payload in
      let common =
        { Signed_command_payload.Common.Poly.fee
        ; fee_payer_pk = sender_pub_key
        ; nonce = sender_current_nonce
        ; valid_until
        ; memo = Signed_command_memo.create_from_string_exn memo
        }
      in
      { Signed_command_payload.Poly.common; body }
    in
    let raw_signature =
      Signed_command.sign_payload sender.private_key payload
      |> Signature.Raw.encode
    in
    let%bind zkapp_command_create_accounts =
      (* construct a Zkapp_command.t *)
      let zkapp_keypairs =
        List.init 3 ~f:(fun _ -> Signature_lib.Keypair.create ())
      in
      let constraint_constants = Network.constraint_constants network in
      let amount = Currency.Amount.of_mina_int_exn 10 in
      let nonce = Account.Nonce.zero in
      let memo =
        Signed_command_memo.create_from_string_exn "Zkapp create account"
      in
      let fee = Currency.Fee.of_nanomina_int_exn 20_000_000 in
      let (zkapp_command_spec : Transaction_snark.For_tests.Deploy_snapp_spec.t)
          =
        { sender = (fish1.keypair, nonce)
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
    let wait_for_zkapp zkapp_command =
      let with_timeout =
        let soft_slots = 4 in
        let soft_timeout = Network_time_span.Slots soft_slots in
        let hard_timeout = Network_time_span.Slots (soft_slots * 2) in
        Wait_condition.with_timeouts ~soft_timeout ~hard_timeout
      in
      let%map () =
        wait_for t @@ with_timeout
        @@ Wait_condition.zkapp_to_be_included_in_frontier ~has_failures:false
             ~zkapp_command
      in
      [%log info] "ZkApp transaction included in transition frontier"
    in
    let%bind () =
      section "send a single signed payment between 2 fish accounts"
        (let%bind { hash; _ } =
           Integration_test_lib.Graphql_requests.must_send_payment_with_raw_sig
             (Network.Node.get_ingress_uri node_b)
             ~logger
             ~sender_pub_key:(Signed_command_payload.fee_payer_pk payload)
             ~receiver_pub_key:(Signed_command_payload.receiver_pk payload)
             ~amount ~fee
             ~nonce:(Signed_command_payload.nonce payload)
             ~memo ~valid_until ~raw_signature
         in
         wait_for t
           (Wait_condition.signed_command_to_be_included_in_frontier
              ~txn_hash:hash ~node_included_in:(`Node node_b) ) )
    in
    let%bind () =
      section_hard "Send a zkApp transaction to create zkApp accounts"
        (send_zkapp ~logger
           (Network.Node.get_ingress_uri node_a)
           zkapp_command_create_accounts )
    in
    let%bind () =
      section_hard
        "Wait for zkapp to create accounts to be included in transition \
         frontier"
        (wait_for_zkapp zkapp_command_create_accounts)
    in
    let%bind () =
      section_hard "send out txns to fill up the snark ledger"
        (let receiver = node_a in
         let%bind receiver_pub_key = pub_key_of_node receiver in
         let sender = node_b in
         let%bind sender_pub_key = pub_key_of_node sender in
         let%bind _ =
           send_payments ~logger ~sender_pub_key ~receiver_pub_key
             ~amount:Currency.Amount.one ~fee ~node:sender 10
         in
         wait_for t
           (Wait_condition.ledger_proofs_emitted_since_genesis
              ~test_config:config ~num_proofs:1 ) )
    in
    let%bind () =
      section_hard "checking height, global slot since genesis in best chain"
        (let%bind blocks =
           Integration_test_lib.Graphql_requests.must_get_best_chain ~logger
             (Network.Node.get_ingress_uri node_a)
         in
         let%bind () =
           Malleable_error.List.iter blocks
             ~f:(fun
                  { height
                  ; global_slot_since_genesis
                  ; global_slot_since_hard_fork
                  ; _
                  }
                ->
               [%log info]
                 "Examining block in best tip with height = %Ld, global slot \
                  since hard fork = %d, global slot since genesis = %d"
                 (Unsigned.UInt32.to_int64 height)
                 (Mina_numbers.Global_slot_since_genesis.to_int
                    global_slot_since_genesis )
                 (Mina_numbers.Global_slot_since_hard_fork.to_int
                    global_slot_since_hard_fork ) ;
               let bad_height =
                 Unsigned.UInt32.to_int height <= fork_config.previous_length
               in
               (* for now, we accept the "link block" with a global slot since genesis equal to the previous global slot
                  see issue #13897
               *)
               let bad_slot =
                 Mina_numbers.Global_slot_since_genesis.to_int
                   global_slot_since_genesis
                 < fork_config.previous_global_slot
               in
               if bad_height && bad_slot then
                 Malleable_error.hard_error
                   (Error.of_string
                      "Block height and slot not greater than in fork config" )
               else if bad_height then
                 Malleable_error.hard_error
                   (Error.of_string
                      "Block height not greater than in fork config" )
               else if bad_slot then
                 Malleable_error.hard_error
                   (Error.of_string "Block slot not greater than in fork config")
               else return () )
         in
         [%log info]
           "All blocks in best tip have a height and global slot since genesis \
            derived from hard fork config" ;
         return () )
    in
    section_hard "running replayer"
      (let%bind logs =
         Network.Node.run_replayer
           ~start_slot_since_genesis:fork_config.previous_global_slot ~logger
           (List.hd_exn @@ (Network.archive_nodes network |> Core.Map.data))
       in
       check_replayer_logs ~logger logs )
end
