open Core
open Async
open Integration_test_lib
open Mina_base

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  (* TODO: find a way to avoid this type alias (first class module signatures restrictions make this tricky) *)
  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  (* TODO: refactor all currency values to decimal represenation *)
  (* TODO: test account creation fee *)
  let config =
    let open Test_config in
    let make_timing ~min_balance ~cliff_time ~cliff_amount ~vesting_period
        ~vesting_increment : Mina_base.Account_timing.t =
      let open Currency in
      Timed
        { initial_minimum_balance = Balance.of_int min_balance
        ; cliff_time = Mina_numbers.Global_slot.of_int cliff_time
        ; cliff_amount = Amount.of_int cliff_amount
        ; vesting_period = Mina_numbers.Global_slot.of_int vesting_period
        ; vesting_increment = Amount.of_int vesting_increment
        }
    in
    { default with
      requires_graphql = true
    ; genesis_ledger =
        [ { account_name = "untimed-node-a-key"
          ; balance = "400000"
          ; timing = Untimed (* 400_000_000_000_000 *)
          }
        ; { account_name = "untimed-node-b-key"
          ; balance = "300000"
          ; timing = Untimed (* 300_000_000_000_000 *)
          }
        ; { account_name = "timed-node-c-key"
          ; balance = "30000"
          ; timing =
              make_timing ~min_balance:10_000_000_000_000 ~cliff_time:8
                ~cliff_amount:0 ~vesting_period:4
                ~vesting_increment:5_000_000_000_000
              (* 30_000_000_000_000 mina is the total.  initially, the balance will be 10k mina.  after 8 global slots, the cliff is hit, although the cliff amount is 0.  4 slots after that, 5_000_000_000_000 mina will vest, and 4 slots after that another 5_000_000_000_000 will vest, and then twice again, for a total of 30k mina all fully liquid and unlocked at the end of the schedule*)
          }
        ; { account_name = "snark-node-key1"; balance = "0"; timing = Untimed }
        ; { account_name = "snark-node-key2"; balance = "0"; timing = Untimed }
        ; { account_name = "fish1"; balance = "100"; timing = Untimed }
        ; { account_name = "fish2"; balance = "100"; timing = Untimed }
        ]
    ; block_producers =
        [ { node_name = "untimed-node-a"; account_name = "untimed-node-a-key" }
        ; { node_name = "untimed-node-b"; account_name = "untimed-node-b-key" }
        ; { node_name = "timed-node-c"; account_name = "timed-node-c-key" }
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
    let untimed_node_a =
      Core.String.Map.find_exn
        (Network.block_producers network)
        "untimed-node-a"
    in
    let untimed_node_b =
      Core.String.Map.find_exn
        (Network.block_producers network)
        "untimed-node-b"
    in
    let timed_node_c =
      Core.String.Map.find_exn (Network.block_producers network) "timed-node-c"
    in
    let fish1 =
      Core.String.Map.find_exn (Network.genesis_keypairs network) "fish1"
    in
    let fish2 =
      Core.String.Map.find_exn (Network.genesis_keypairs network) "fish2"
    in
    (* hardcoded values of the balances of fish1 (receiver) and fish2 (sender), update here if they change in the config *)
    (* TODO undo the harcoding, don't be lazy and just make the graphql commands to fetch the balances *)
    let receiver_original_balance = Currency.Amount.of_formatted_string "100" in
    let sender_original_balance = Currency.Amount.of_formatted_string "100" in
    let sender = fish2.keypair in
    let receiver = fish1.keypair in
    [%log info] "extra genesis keypairs: %s"
      (List.to_string [ fish1.keypair; fish2.keypair ]
         ~f:(fun { Signature_lib.Keypair.public_key; _ } ->
           public_key |> Signature_lib.Public_key.to_bigstring
           |> Bigstring.to_string ) ) ;
    let snark_coordinator =
      Core.String.Map.find_exn (Network.all_nodes network) "snark-node"
    in
    let snark_node_key1 =
      Core.String.Map.find_exn
        (Network.genesis_keypairs network)
        "snark-node-key1"
    in
    let snark_node_key2 =
      Core.String.Map.find_exn
        (Network.genesis_keypairs network)
        "snark-node-key2"
    in
    [%log info] "snark node keypairs: %s"
      (List.to_string [ snark_node_key1.keypair; snark_node_key2.keypair ]
         ~f:(fun { Signature_lib.Keypair.public_key; _ } ->
           public_key |> Signature_lib.Public_key.to_yojson
           |> Yojson.Safe.to_string ) ) ;
    (* setup code, creating a signed txn which we'll use to make a successful txn, and then use the same txn in a replay attack which should fail *)
    let receiver_pub_key =
      receiver.public_key |> Signature_lib.Public_key.compress
    in
    let sender_pub_key =
      sender.public_key |> Signature_lib.Public_key.compress
    in
    let%bind { nonce = sender_current_nonce; _ } =
      Integration_test_lib.Graphql_requests.must_get_account_data ~logger
        (Network.Node.get_ingress_uri untimed_node_b)
        ~public_key:sender_pub_key
    in
    let amount = Currency.Amount.of_formatted_string "10" in
    let fee = Currency.Fee.of_formatted_string "1" in
    let memo = "" in
    let token = Token_id.default in
    let valid_until = Mina_numbers.Global_slot.max_value in
    let payload =
      let payment_payload =
        { Payment_payload.Poly.receiver_pk = receiver_pub_key
        ; source_pk = sender_pub_key
        ; token_id = token
        ; amount
        }
      in
      let body = Signed_command_payload.Body.Payment payment_payload in
      let common =
        { Signed_command_payload.Common.Poly.fee
        ; fee_token = Signed_command_payload.Body.token body
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
    (* setup complete *)
    let%bind () =
      section "send a single signed payment between 2 fish accounts"
        (let%bind { hash; _ } =
           Integration_test_lib.Graphql_requests.must_send_payment_with_raw_sig
             (Network.Node.get_ingress_uri untimed_node_b)
             ~logger
             ~sender_pub_key:(Signed_command_payload.source_pk payload)
             ~receiver_pub_key:(Signed_command_payload.receiver_pk payload)
             ~amount ~fee
             ~nonce:(Signed_command_payload.nonce payload)
             ~memo ~token ~valid_until ~raw_signature
         in
         wait_for t
           (Wait_condition.signed_command_to_be_included_in_frontier
              ~txn_hash:hash ~node_included_in:(`Node untimed_node_b) ) )
    in
    let%bind () =
      section
        "check that the account balances are what we expect after the previous \
         txn"
        (let%bind { total_balance = receiver_balance; _ } =
           Integration_test_lib.Graphql_requests.must_get_account_data ~logger
             (Network.Node.get_ingress_uri untimed_node_b)
             ~public_key:receiver_pub_key
         in
         let%bind { total_balance = sender_balance; _ } =
           Integration_test_lib.Graphql_requests.must_get_account_data ~logger
             (Network.Node.get_ingress_uri untimed_node_b)
             ~public_key:sender_pub_key
         in
         (* TODO, the intg test framework is ignoring test_constants.coinbase_amount for whatever reason, so hardcoding this until that is fixed *)
         let receiver_expected =
           Currency.Amount.add receiver_original_balance amount
           |> Option.value_exn
         in
         let sender_expected =
           Currency.Amount.sub sender_original_balance amount
           (* ( Currency.Amount.add amount (Currency.Amount.of_fee fee)
              |> Option.value_exn ) *)
           (* TODO: put the fee back in *)
           |> Option.value_exn
         in
         (* [%log info] "coinbase_amount: %s"
            (Currency.Amount.to_formatted_string coinbase_reward) ; *)
         [%log info] "txn_amount: %s"
           (Currency.Amount.to_formatted_string amount) ;
         [%log info] "receiver_expected: %s"
           (Currency.Amount.to_formatted_string receiver_expected) ;
         [%log info] "receiver_balance: %s"
           (Currency.Balance.to_formatted_string receiver_balance) ;
         [%log info] "sender_expected: %s"
           (Currency.Amount.to_formatted_string sender_expected) ;
         [%log info] "sender_balance: %s"
           (Currency.Balance.to_formatted_string sender_balance) ;
         if
           (* node_a is the receiver *)
           (* node_a_balance >= 400_000_000_000_000 + txn_amount *)
           (* coinbase_amount is much less than txn_amount, so that even if node_a receives a coinbase, the balance (before receiving currency from a txn) should be less than original_amount + txn_amount *)
           Currency.Amount.( >= )
             (Currency.Balance.to_amount receiver_balance)
             receiver_expected
           (* node_b is the sender *)
           (* node_b_balance <= (300_000_000_000_000 + node_b_num_produced_blocks*possible_coinbase_reward*2) - (txn_amount + txn_fee) *)
           (* if one is unlucky, node_b could theoretically win a bunch of blocks in a row, which is why we have the `node_b_num_produced_blocks*possible_coinbase_reward*2` bit.  the *2 is because untimed accounts get supercharged rewards *)
           (* TODO, the fee is not calculated in at the moment *)
           && Currency.Amount.( <= )
                (Currency.Balance.to_amount sender_balance)
                sender_expected
         then Malleable_error.return ()
         else
           Malleable_error.soft_error_format ~value:()
             "Error with account balances.  receiver balance is %d and should \
              be %d, sender balance is %d and should be %d.  and txn_amount is \
              %d"
             (Currency.Balance.to_int receiver_balance)
             (Currency.Amount.to_int receiver_expected)
             (Currency.Balance.to_int sender_balance)
             (Currency.Amount.to_int sender_expected)
             (Currency.Amount.to_int amount) )
    in
    let%bind () =
      section
        "attempt to send again the same signed transaction command as before \
         to conduct a replay attack. expecting a bad nonce"
        (let open Deferred.Let_syntax in
        match%bind
          Integration_test_lib.Graphql_requests.send_payment_with_raw_sig
            (Network.Node.get_ingress_uri untimed_node_b)
            ~logger
            ~sender_pub_key:(Signed_command_payload.source_pk payload)
            ~receiver_pub_key:(Signed_command_payload.receiver_pk payload)
            ~amount ~fee
            ~nonce:(Signed_command_payload.nonce payload)
            ~memo ~token ~valid_until ~raw_signature
        with
        | Ok { nonce; _ } ->
            Malleable_error.soft_error_format ~value:()
              "Replay attack succeeded, but it should fail because the nonce \
               is old.  attempted nonce: %d"
              (Unsigned.UInt32.to_int nonce)
        | Error error ->
            (* expect GraphQL error due to bad nonce *)
            let err_str = Error.to_string_mach error in
            let err_str_lowercase = String.lowercase err_str in
            if
              String.is_substring
                ~substring:"either different from inferred nonce"
                err_str_lowercase
            then (
              [%log info] "Got expected bad nonce error from GraphQL" ;
              Malleable_error.return () )
            else (
              [%log error]
                "Payment failed in GraphQL, but for unexpected reason: %s"
                err_str ;
              Malleable_error.soft_error_format ~value:()
                "Payment failed for unexpected reason: %s" err_str ))
    in
    let%bind () =
      section
        "attempt to send again the same signed transaction command as before, \
         but changing the nonce, to conduct a replay attack.  expecting an \
         Invalid_signature"
        (let open Deferred.Let_syntax in
        match%bind
          Integration_test_lib.Graphql_requests.send_payment_with_raw_sig
            (Network.Node.get_ingress_uri untimed_node_a)
            ~logger
            ~sender_pub_key:(Signed_command_payload.source_pk payload)
            ~receiver_pub_key:(Signed_command_payload.receiver_pk payload)
            ~amount ~fee
            ~nonce:
              (Mina_numbers.Account_nonce.succ
                 (Signed_command_payload.nonce payload) )
            ~memo ~token ~valid_until ~raw_signature
        with
        | Ok { nonce = returned_nonce; _ } ->
            Malleable_error.soft_error_format ~value:()
              "Replay attack succeeded, but it should fail because the \
               signature is wrong.  payload nonce: %d.  returned nonce: %d"
              (Unsigned.UInt32.to_int (Signed_command_payload.nonce payload))
              (Unsigned.UInt32.to_int returned_nonce)
        | Error error ->
            (* expect GraphQL error due to invalid signature *)
            let err_str = Error.to_string_mach error in
            let err_str_lowercase = String.lowercase err_str in
            if
              String.is_substring ~substring:"invalid_signature"
                err_str_lowercase
            then (
              [%log info] "Got expected invalid signature error from GraphQL" ;
              Malleable_error.return () )
            else (
              [%log error]
                "Payment failed in GraphQL, but for unexpected reason: %s"
                err_str ;
              Malleable_error.soft_error_format ~value:()
                "Payment failed, but for unexpected reason: %s" err_str ))
    in
    let%bind () =
      section "send a single payment from timed account using available liquid"
        (let amount = Currency.Amount.of_int 1_000_000_000_000 in
         let receiver = untimed_node_a in
         let%bind receiver_pub_key = pub_key_of_node receiver in
         let sender = timed_node_c in
         let%bind sender_pub_key = pub_key_of_node sender in
         let%bind { hash; _ } =
           Integration_test_lib.Graphql_requests.must_send_online_payment
             ~logger
             (Network.Node.get_ingress_uri timed_node_c)
             ~sender_pub_key ~receiver_pub_key ~amount ~fee
         in
         wait_for t
           (Wait_condition.signed_command_to_be_included_in_frontier
              ~txn_hash:hash ~node_included_in:(`Node timed_node_c) ) )
    in
    let%bind () =
      section "unable to send payment from timed account using illiquid tokens"
        (let amount = Currency.Amount.of_int 25_000_000_000_000 in
         let receiver = untimed_node_b in
         let%bind receiver_pub_key = pub_key_of_node receiver in
         let sender = timed_node_c in
         let%bind sender_pub_key = pub_key_of_node sender in
         let%bind { total_balance = timed_node_c_total; _ } =
           Integration_test_lib.Graphql_requests.must_get_account_data ~logger
             (Network.Node.get_ingress_uri timed_node_c)
             ~public_key:sender_pub_key
         in
         [%log info] "timed_node_c total balance: %s"
           (Currency.Balance.to_formatted_string timed_node_c_total) ;
         [%log info]
           "Attempting to send txn from timed_node_c to untimed_node_a for \
            amount of %s"
           (Currency.Amount.to_formatted_string amount) ;
         (* TODO: refactor this using new [expect] dsl when it's available *)
         let open Deferred.Let_syntax in
         match%bind
           Integration_test_lib.Graphql_requests.send_online_payment ~logger
             (Network.Node.get_ingress_uri sender)
             ~sender_pub_key ~receiver_pub_key ~amount ~fee
         with
         | Ok _ ->
             Malleable_error.soft_error_string ~value:()
               "Payment succeeded, but expected it to fail because of a \
                minimum balance violation"
         | Error error ->
             (* expect GraphQL error due to insufficient funds *)
             let err_str = Error.to_string_mach error in
             let err_str_lowercase = String.lowercase err_str in
             if
               String.is_substring ~substring:"insufficient_funds"
                 err_str_lowercase
             then (
               [%log info] "Got expected insufficient funds error from GraphQL" ;
               Malleable_error.return () )
             else (
               [%log error]
                 "Payment failed in GraphQL, but for unexpected reason: %s"
                 err_str ;
               Malleable_error.soft_error_format ~value:()
                 "Payment failed for unexpected reason: %s" err_str ) )
    in
    let%bind () =
      section_hard
        "send out a bunch more txns to fill up the snark ledger, then wait for \
         proofs to be emitted"
        (let receiver = untimed_node_a in
         let%bind receiver_pub_key = pub_key_of_node receiver in
         let sender = untimed_node_b in
         let%bind sender_pub_key = pub_key_of_node sender in
         let%bind _ =
           (*
            To fill up a `small` transaction capacity with work delay of 1,
            there needs to be 12 total txns sent.
            Calculation is as follows:
            Max number trees in the scan state is
              `(transaction_capacity_log+1) * (work_delay+1)`
            and for 2^2 transaction capacity and work delay 1 it is
              `(2+1)*(1+1)=6`.
            Per block there can be 2 transactions included (other two slots would be for a coinbase and fee transfers).
            In the initial state of the network, the scan state waits till all the trees are filled before emitting a proof from the first tree.
            Hence, 6*2 = 12 transactions untill we get the first snarked ledger.
            2 successful txn are sent in the prior course of this test,
            so spamming out at least 10 more here will trigger a ledger proof to be emitted *)
           send_payments ~logger ~sender_pub_key ~receiver_pub_key
             ~amount:Currency.Amount.one ~fee ~node:sender 10
         in
         wait_for t
           (Wait_condition.ledger_proofs_emitted_since_genesis
              ~test_config:config ~num_proofs:1 ) )
    in
    let%bind () =
      section_hard
        "check account balances.  snark-node-key1 should be greater than or \
         equal to the snark fee"
        (let%bind { total_balance = key_1_balance_actual; _ } =
           Integration_test_lib.Graphql_requests.must_get_account_data ~logger
             (Network.Node.get_ingress_uri untimed_node_b)
             ~public_key:
               ( snark_node_key1.keypair.public_key
               |> Signature_lib.Public_key.compress )
         in
         let%bind { total_balance = key_2_balance_actual; _ } =
           Integration_test_lib.Graphql_requests.must_get_account_data ~logger
             (Network.Node.get_ingress_uri untimed_node_a)
             ~public_key:
               ( snark_node_key2.keypair.public_key
               |> Signature_lib.Public_key.compress )
         in
         let key_1_balance_expected =
           Currency.Amount.of_formatted_string config.snark_worker_fee
         in
         if
           Currency.Amount.( >= )
             (Currency.Balance.to_amount key_1_balance_actual)
             key_1_balance_expected
         then (
           [%log info]
             "balance check successful.  \n\
              snark-node-key1 balance: %s.  \n\
              snark-node-key2 balance: %s.  \n\
              snark-worker-fee: %s"
             (Currency.Balance.to_formatted_string key_1_balance_actual)
             (Currency.Balance.to_formatted_string key_2_balance_actual)
             config.snark_worker_fee ;

           Malleable_error.return () )
         else
           Malleable_error.soft_error_format ~value:()
             "Error with balance of snark-node-key1.  \n\
              snark-node-key1 balance: %s.  \n\
              snark-node-key2 balance: %s.  \n\
              snark-worker-fee: %s"
             (Currency.Balance.to_formatted_string key_1_balance_actual)
             (Currency.Balance.to_formatted_string key_2_balance_actual)
             config.snark_worker_fee )
    in
    let%bind () =
      section_hard
        "change snark worker key from snark-node-key1 to snark-node-key2"
        (Integration_test_lib.Graphql_requests.must_set_snark_worker ~logger
           (Network.Node.get_ingress_uri snark_coordinator)
           ~new_snark_pub_key:
             ( snark_node_key2.keypair.public_key
             |> Signature_lib.Public_key.compress ) )
    in
    let%bind () =
      section_hard "change snark work fee from 0.0002 to 0.0001"
        (Integration_test_lib.Graphql_requests.must_set_snark_work_fee ~logger
           (Network.Node.get_ingress_uri snark_coordinator)
           ~new_snark_work_fee:1 )
    in
    let%bind () =
      section_hard
        "send out a bunch of txns to fill up the snark ledger, then wait for \
         proofs to be emitted"
        (let receiver = untimed_node_b in
         let%bind receiver_pub_key = pub_key_of_node receiver in
         let sender = untimed_node_a in
         let%bind sender_pub_key = pub_key_of_node sender in
         let%bind _ =
           send_payments ~logger ~sender_pub_key ~receiver_pub_key
             ~amount:Currency.Amount.one ~fee ~node:sender 12
         in
         wait_for t
           (Wait_condition.ledger_proofs_emitted_since_genesis ~num_proofs:2
              ~test_config:config ) )
    in
    let%bind () =
      section_hard
        "check account balances.  snark-node-key2 should be greater than or \
         equal to the snark fee"
        (let%bind { total_balance = key_1_balance_actual; _ } =
           Integration_test_lib.Graphql_requests.must_get_account_data ~logger
             (Network.Node.get_ingress_uri untimed_node_b)
             ~public_key:
               ( snark_node_key1.keypair.public_key
               |> Signature_lib.Public_key.compress )
         in
         let%bind { total_balance = key_2_balance_actual; _ } =
           Integration_test_lib.Graphql_requests.must_get_account_data ~logger
             (Network.Node.get_ingress_uri untimed_node_a)
             ~public_key:
               ( snark_node_key2.keypair.public_key
               |> Signature_lib.Public_key.compress )
         in
         let key_2_balance_expected =
           Currency.Amount.of_formatted_string "0.0001"
         in
         if
           Currency.Amount.( >= )
             (Currency.Balance.to_amount key_2_balance_actual)
             key_2_balance_expected
         then (
           [%log info]
             "balance check successful.  \n\
              snark-node-key1 balance: %s.  \n\
              snark-node-key2 balance: %s.  \n\
              snark-worker-fee: %s"
             (Currency.Balance.to_formatted_string key_1_balance_actual)
             (Currency.Balance.to_formatted_string key_2_balance_actual)
             (Currency.Amount.to_formatted_string key_2_balance_expected) ;

           Malleable_error.return () )
         else
           Malleable_error.soft_error_format ~value:()
             "Error with balance of snark-node-key2.  \n\
              snark-node-key1 balance: %s.  \n\
              snark-node-key2 balance: %s.  \n\
              snark-worker-fee: %s"
             (Currency.Balance.to_formatted_string key_1_balance_actual)
             (Currency.Balance.to_formatted_string key_2_balance_actual)
             (Currency.Amount.to_formatted_string key_2_balance_expected) )
    in
    section_hard "running replayer"
      (let%bind logs =
         Network.Node.run_replayer ~logger
           (List.hd_exn @@ (Network.archive_nodes network |> Core.Map.data))
       in
       check_replayer_logs ~logger logs )
end
