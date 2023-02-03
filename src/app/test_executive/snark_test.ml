open Core
open Integration_test_lib

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
    let open Test_config.Wallet in
    { default with
      requires_graphql = true
    ; block_producers =
        [ { balance = "400000"; timing = Untimed } (* 400_000_000_000_000 *)
        ; { balance = "300000"; timing = Untimed } (* 300_000_000_000_000 *)
        ]
    ; extra_genesis_accounts =
        [ { balance = "1000"; timing = Untimed }
        ; { balance = "1000"; timing = Untimed }
        ]
    ; num_archive_nodes = 0
    ; num_snark_workers = 4
    ; snark_worker_fee = "0.0001"
    ; proof_config =
        { proof_config_default with
          work_delay = Some 1
        ; transaction_capacity =
            Some Runtime_config.Proof_keys.Transaction_capacity.small
        }
    }

  (*
     TODO, new config format should look like

       let config =
         let open Test_config in
         let open Test_config.Wallet in
         { default with
           requires_graphql = true
         ; genesis_ledger = [
               { key_name = "bp1_key"; balance = "400000"; timing = Untimed }
             ; { key_name = "bp2_key"; balance = "300000"; timing = Untimed }
             ; { key_name = "extra1_key"; balance = "1000"; timing = Untimed }
             ; { key_name = "extra2_key"; balance = "1000"; timing = Untimed }
             ; { key_name = "snark_worker1_key"; balance = "10"; timing = Untimed }
         ]
         ; block_producers =
             [ { node_name = "bp1"; node_key_name = "bp1_key" }
             ; { node_name = "bp2"; node_key_name = "bp2_key" }
             ]
         ; num_archive_nodes = 0
         ; snark_workers = [
               { node_name = "snark_worker"; node_key_name = "snark_worker1_key"; replicas = 4 }
         ]
         ; snark_worker_fee = "0.0001"
         ; proof_config =
             { proof_config_default with
               work_delay = Some 1
             ; transaction_capacity =
                 Some Runtime_config.Proof_keys.Transaction_capacity.small
             }
         }
  *)

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let all_nodes = Network.all_nodes network in
    let%bind () = wait_for t (Wait_condition.nodes_to_initialize all_nodes) in
    let[@warning "-8"] [ untimed_node_a; untimed_node_b ] =
      Network.block_producers network
    in
    [%log info] "extra genesis keypairs: %s"
      (List.to_string (Network.extra_genesis_keypairs network)
         ~f:(fun { Signature_lib.Keypair.public_key; _ } ->
           public_key |> Signature_lib.Public_key.to_bigstring
           |> Bigstring.to_string ) ) ;
    let[@warning "-8"] [ fish1; fish2 ] =
      Network.extra_genesis_keypairs network
    in
    let amount = Currency.Amount.of_formatted_string "10" in
    let fee = Currency.Fee.of_formatted_string "1" in
    let receiver_pub_key =
      fish1.public_key |> Signature_lib.Public_key.compress
    in
    let sender_kp = fish2 in
    let sender_pub_key =
      sender_kp.public_key |> Signature_lib.Public_key.compress
    in
    (* let snark_worker_pk = Test_config.default.snark_worker_public_key in *)
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
*)
           send_payments ~logger ~sender_pub_key ~receiver_pub_key
             ~amount:Currency.Amount.one ~fee ~node:sender 12
         in
         wait_for t
           (Wait_condition.ledger_proofs_emitted_since_genesis ~num_proofs:1) )
    in
    (* let%bind () =
         section_hard "check snark worker's account balance"
           (let%bind { total_balance = snark_worker_balance; _ } =
              Network.Node.must_get_account_data ~logger untimed_node_b
                ~public_key:snark_worker_pk
            in
            if
              Currency.Amount.( >= )
                (Currency.Balance.to_amount snark_worker_balance)
                snark_worker_expected
            then Malleable_error.return ()
            else
              Malleable_error.soft_error_format ~value:()
                "Error with snark_worker_balance.  snark_worker_balance is %d and \
                 should be %d.  snark fee is %d"
                (Currency.Balance.to_int snark_worker_balance)
                (Currency.Amount.to_int snark_worker_expected)
                (Currency.Fee.to_int fee) )
       in *)
    section_hard "dfasdfdasf"
      (let%bind hash =
         let%map { hash; _ } =
           Engine.Network.Node.must_send_payment ~logger ~sender_pub_key
             ~receiver_pub_key ~amount ~fee untimed_node_b
         in
         hash
       in
       Dsl.wait_for t
         (Dsl.Wait_condition.signed_command_to_be_included_in_frontier
            ~txn_hash:hash ~node_included_in:`Any_node ) )
end
