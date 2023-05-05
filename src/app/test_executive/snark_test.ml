open Core
open Integration_test_lib
(* open Mina_base *)
(* open Async *)

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
  (* TODO: test snark work *)
  let config =
    let open Test_config in
    { default with
      requires_graphql = true
    ; genesis_ledger =
        [ { account_name = "node-a-key"; balance = "400000"; timing = Untimed }
        ; { account_name = "node-b-key"; balance = "300000"; timing = Untimed }
        ; { account_name = "snark-node-key1"; balance = "0"; timing = Untimed }
        ; { account_name = "snark-node-key2"; balance = "0"; timing = Untimed }
        ]
    ; block_producers =
        [ { node_name = "node-a"; account_name = "node-a-key" }
          (* 400_000_000_000_000 *)
        ; { node_name = "node-b"; account_name = "node-b-key" }
          (* 300_000_000_000_000 *)
        ]
    ; num_archive_nodes = 0
    ; snark_coordinator =
        Some
          { node_name = "snark-node"
          ; account_name = "snark-node-key1"
          ; worker_nodes = 8
          }
    ; snark_worker_fee = "0.0001"
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
    let node_a =
      Core.String.Map.find_exn (Network.block_producers network) "node-a"
    in
    let node_b =
      Core.String.Map.find_exn (Network.block_producers network) "node-b"
    in
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
    let fee = Currency.Fee.of_formatted_string "1" in
    let%bind () =
      section_hard
        "send out a bunch of txns to fill up the snark ledger, then wait for \
         proofs to be emitted"
        (let receiver = node_a in
         let%bind receiver_pub_key = pub_key_of_node receiver in
         let sender = node_b in
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
              Hence, 6*2 = 12 transactions until we get the first snarked ledger.
  *)
           send_payments ~logger ~sender_pub_key ~receiver_pub_key
             ~amount:Currency.Amount.one ~fee ~node:sender 13
         in
         wait_for t
           (Wait_condition.ledger_proofs_emitted_since_genesis ~num_proofs:1) )
    in
    let%bind () =
      section_hard
        "check account balances.  snark-node-key1 should be greater than or \
         equal to the snark fee"
        (let%bind { total_balance = key_1_balance_actual; _ } =
           Network.Node.must_get_account_data ~logger node_b
             ~public_key:
               ( snark_node_key1.keypair.public_key
               |> Signature_lib.Public_key.compress )
         in
         let%bind { total_balance = key_2_balance_actual; _ } =
           Network.Node.must_get_account_data ~logger node_a
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
        (Network.Node.must_set_snark_worker ~logger snark_coordinator
           ~new_snark_pub_key:
             ( snark_node_key2.keypair.public_key
             |> Signature_lib.Public_key.compress ) )
    in
    let%bind () =
      section_hard
        "send out a bunch of txns to fill up the snark ledger, then wait for \
         proofs to be emitted"
        (let receiver = node_b in
         let%bind receiver_pub_key = pub_key_of_node receiver in
         let sender = node_a in
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
          Hence, 6*2 = 12 transactions until we get the first snarked ledger.
*)
           send_payments ~logger ~sender_pub_key ~receiver_pub_key
             ~amount:Currency.Amount.one ~fee ~node:sender 26
         in
         wait_for t
           (Wait_condition.ledger_proofs_emitted_since_genesis ~num_proofs:2) )
    in
    section_hard
      "check account balances.  snark-node-key2 should be greater than or \
       equal to the snark fee"
      (let%bind { total_balance = key_1_balance_actual; _ } =
         Network.Node.must_get_account_data ~logger node_b
           ~public_key:
             ( snark_node_key1.keypair.public_key
             |> Signature_lib.Public_key.compress )
       in
       let%bind { total_balance = key_2_balance_actual; _ } =
         Network.Node.must_get_account_data ~logger node_a
           ~public_key:
             ( snark_node_key2.keypair.public_key
             |> Signature_lib.Public_key.compress )
       in
       let key_2_balance_expected =
         Currency.Amount.of_formatted_string config.snark_worker_fee
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
           config.snark_worker_fee ;

         Malleable_error.return () )
       else
         Malleable_error.soft_error_format ~value:()
           "Error with balance of snark-node-key2.  \n\
            snark-node-key1 balance: %s.  \n\
            snark-node-key2 balance: %s.  \n\
            snark-worker-fee: %s"
           (Currency.Balance.to_formatted_string key_1_balance_actual)
           (Currency.Balance.to_formatted_string key_2_balance_actual)
           config.snark_worker_fee )
end
