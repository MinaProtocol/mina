open Core
open Integration_test_lib
open Currency
open Mina_base
open Mina_numbers
open Signature_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  (* TODO: find a way to avoid this type alias (first class module signatures restrictions make this tricky) *)
  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let config =
    let open Test_config in
    let make_timing ~min_balance ~cliff_time ~cliff_amount ~vesting_period
        ~vesting_increment : Mina_base.Account_timing.t =
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
        [ { account_name = "bp-1"
          ; balance = "400000"
          ; timing = Untimed (* 400_000_000_000_000 *)
          }
        ; { account_name = "bp-2"
          ; balance = "300000"
          ; timing = Untimed (* 300_000_000_000_000 *)
          }
        ; { account_name = "timed-bp"
          ; balance = "30000"
          ; timing =
              make_timing ~min_balance:10_000_000_000_000 ~cliff_time:8
                ~cliff_amount:0 ~vesting_period:4
                ~vesting_increment:5_000_000_000_000
              (* 30_000_000_000_000 mina is the total.  initially, the balance will be 10k mina.  after 8 global slots, the cliff is hit, although the cliff amount is 0.  4 slots after that, 5_000_000_000_000 mina will vest, and 4 slots after that another 5_000_000_000_000 will vest, and then twice again, for a total of 30k mina all fully liquid and unlocked at the end of the schedule*)
          }
        ; { account_name = "snark-node-1"; balance = "0"; timing = Untimed }
        ; { account_name = "snark-node-2"; balance = "0"; timing = Untimed }
        ; { account_name = "fish-1"; balance = "100"; timing = Untimed }
        ; { account_name = "fish-2"; balance = "100"; timing = Untimed }
        ]
    ; block_producers =
        [ { node_name = "bp-1-node"; account_name = "bp-1" }
        ; { node_name = "bp-2-node"; account_name = "bp-2" }
        ; { node_name = "timed-bp-node"; account_name = "timed-bp" }
        ]
    ; snark_coordinator =
        Some
          { node_name = "snark-node"
          ; account_name = "snark-node-1"
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

  let payment ?(memo = "") ?(token = Token_id.default)
      ?(valid_until = Global_slot.max_value) ?(fee = Fee.of_int 1_000_000_000)
      ~logger ~node ~sender ~receiver amount =
    let open Network_keypair in
    let open Malleable_error.Let_syntax in
    let sender_pk = sender.keypair.public_key |> Public_key.compress in
    let payment_payload =
      { Payment_payload.Poly.receiver_pk =
          receiver.keypair.public_key |> Public_key.compress
      ; source_pk = sender_pk
      ; token_id = token
      ; amount
      }
    in
    [%log info] "Executing payment of %s from %s to %s"
      (Currency.Amount.to_string amount)
      (Public_key.Compressed.to_string sender_pk)
      (Public_key.Compressed.to_string
         (Public_key.compress receiver.keypair.public_key) ) ;
    let%bind { nonce; _ } =
      Integration_test_lib.Graphql_requests.must_get_account_data ~logger
        (Network.Node.get_ingress_uri node)
        ~public_key:sender_pk
    in
    let common =
      { Signed_command_payload.Common.Poly.fee
      ; fee_token = token
      ; fee_payer_pk = sender_pk
      ; nonce
      ; valid_until
      ; memo = Signed_command_memo.create_from_string_exn memo
      }
    in
    let payload =
      { Signed_command_payload.Poly.common
      ; body = Signed_command_payload.Body.Payment payment_payload
      }
    in
    let raw_signature =
      Signed_command.sign_payload sender.keypair.private_key payload
      |> Signature.Raw.encode
    in
    Integration_test_lib.Graphql_requests.must_send_payment_with_raw_sig
      (Network.Node.get_ingress_uri node)
      ~logger
      ~sender_pub_key:(Signed_command_payload.source_pk payload)
      ~receiver_pub_key:(Signed_command_payload.receiver_pk payload)
      ~amount ~fee
      ~nonce:(Signed_command_payload.nonce payload)
      ~memo ~token ~valid_until ~raw_signature

  let mina amt = Amount.of_int (1_000_000_000 * amt)

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let all_mina_nodes = Network.all_mina_nodes network in
    let%bind () =
      wait_for t
        (Wait_condition.nodes_to_initialize
           (Core.String.Map.data all_mina_nodes) )
    in
    let node =
      Core.String.Map.find_exn (Network.block_producers network) "bp-1-node"
    in
    let bp1 =
      Core.String.Map.find_exn (Network.genesis_keypairs network) "bp-1"
    in
    let bp2 =
      Core.String.Map.find_exn (Network.genesis_keypairs network) "bp-2"
    in
    let timed_bp =
      Core.String.Map.find_exn (Network.genesis_keypairs network) "timed-bp"
    in
    let fish1 =
      Core.String.Map.find_exn (Network.genesis_keypairs network) "fish-1"
    in
    let fish2 =
      Core.String.Map.find_exn (Network.genesis_keypairs network) "fish-2"
    in
    let snark_worker1 =
      Core.String.Map.find_exn (Network.genesis_keypairs network) "snark-node-1"
    in
    let snark_worker2 =
      Core.String.Map.find_exn (Network.genesis_keypairs network) "snark-node-2"
    in
    [%log info] "Node GQL URI: %s."
      (Network.Node.get_ingress_uri node |> Uri.to_string) ;
    let%bind { hash = txn_hash1; _ } =
      payment ~logger ~node ~sender:fish1 ~receiver:snark_worker1 (mina 20)
    and { hash = txn_hash2; _ } =
      payment ~logger ~node ~sender:fish2 ~receiver:snark_worker2 (mina 30)
    in
    let%bind () =
      wait_for t
        (Wait_condition.signed_command_to_be_included_in_frontier
           ~txn_hash:txn_hash1 ~node_included_in:(`Node node) )
    and () =
      wait_for t
        (Wait_condition.signed_command_to_be_included_in_frontier
           ~txn_hash:txn_hash2 ~node_included_in:(`Node node) )
    in
    let%bind { hash = txn_hash4; _ } =
      payment ~logger ~node ~sender:fish1 ~receiver:snark_worker1 (mina 25)
    and { hash = txn_hash5; _ } =
      payment ~logger ~node ~sender:fish2 ~receiver:snark_worker2 (mina 50)
    in
    let%bind () =
      wait_for t
        (Wait_condition.signed_command_to_be_included_in_frontier
           ~txn_hash:txn_hash4 ~node_included_in:(`Node node) )
    and () =
      wait_for t
        (Wait_condition.signed_command_to_be_included_in_frontier
           ~txn_hash:txn_hash5 ~node_included_in:(`Node node) )
    in
    let%bind { hash = txn_hash7; _ } =
      payment ~logger ~node ~sender:timed_bp ~receiver:fish1 (mina 10)
    and { hash = txn_hash8; _ } =
      payment ~logger ~node ~sender:fish2 ~receiver:timed_bp (mina 15)
    in
    let%bind () =
      wait_for t
        (Wait_condition.signed_command_to_be_included_in_frontier
           ~txn_hash:txn_hash7 ~node_included_in:(`Node node) )
    and () =
      wait_for t
        (Wait_condition.signed_command_to_be_included_in_frontier
           ~txn_hash:txn_hash8 ~node_included_in:(`Node node) )
    in
    [%log info] "Sending delegation from fish1 (%s) to bp1 (%s)."
      ( Public_key.Compressed.to_base58_check
      @@ Public_key.compress fish1.keypair.public_key )
      ( Public_key.Compressed.to_base58_check
      @@ Public_key.compress bp1.keypair.public_key ) ;
    [%log info] "Sending delegation from fish2 (%s) to bp2 (%s)."
      ( Public_key.Compressed.to_base58_check
      @@ Public_key.compress fish2.keypair.public_key )
      ( Public_key.Compressed.to_base58_check
      @@ Public_key.compress bp2.keypair.public_key ) ;
    let%bind node_pk = pub_key_of_node node in
    let%bind { hash = delegation_hash; _ } =
      Integration_test_lib.Graphql_requests.must_send_delegation
        ~sender_pub_key:node_pk
        ~receiver_pub_key:(Public_key.compress timed_bp.keypair.public_key)
        ~fee:(Amount.to_fee @@ mina 1)
        ~logger
        (Network.Node.get_ingress_uri node)
    in
    let%bind () =
      wait_for t
        (Wait_condition.signed_command_to_be_included_in_frontier
           ~txn_hash:delegation_hash ~node_included_in:(`Node node) )
    in
    let%bind genesis_config =
      Integration_test_lib.Graphql_requests.export_genesis_ledger ~logger
        (Network.Node.get_ingress_uri node)
    in
    let ledger_accounts =
      let open Runtime_config in
      let open Ledger in
      let ledger = Option.value_exn genesis_config.ledger in
      match ledger.base with
      | Accounts accounts ->
          accounts
      | _ ->
          failwith "Expected base to be accounts"
    in
    Malleable_error.List.iter ledger_accounts ~f:(fun genesis_account ->
        let open Runtime_config.Accounts in
        let public_key =
          Option.value_exn genesis_account.pk
          |> Public_key.Compressed.of_base58_check_exn
        in
        let%bind gql_account =
          Integration_test_lib.Graphql_requests.must_get_account_data ~logger
            ~public_key
            (Network.Node.get_ingress_uri node)
        in
        if Balance.equal genesis_account.balance gql_account.total_balance then (
          [%log info] "balance check successful for account %s."
            (Option.value_exn genesis_account.pk) ;
          Malleable_error.return () )
        else
          Malleable_error.soft_error_format ~value:()
            "Error with balance of %s.  \n\
             In the genesis ledger: %s.  \n\
             On the original blockchain: %s."
            (Option.value_exn genesis_account.pk)
            (Balance.to_formatted_string genesis_account.balance)
            (Balance.to_formatted_string gql_account.total_balance) )
end
