open Core
open Integration_test_lib
open Mina_base
open Async

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
        ; { account_name = "fish1"; balance = "100"; timing = Untimed }
        ; { account_name = "fish2"; balance = "100"; timing = Untimed }
        ; { account_name = "snark-node-key"; balance = "100"; timing = Untimed }
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
          ; account_name = "snark-node-key"
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
    let fish1 =
      Core.String.Map.find_exn (Network.genesis_keypairs network) "fish1"
    in
    let fish2 =
      Core.String.Map.find_exn (Network.genesis_keypairs network) "fish2"
    in
    [%log info] "extra genesis keypairs: %s"
      (List.to_string [ fish1.keypair; fish2.keypair ]
         ~f:(fun { Signature_lib.Keypair.public_key; _ } ->
           public_key |> Signature_lib.Public_key.to_bigstring
           |> Bigstring.to_string ) ) ;
    let amount = Currency.Amount.of_mina_string_exn "10" in
    let fee = Currency.Fee.of_mina_string_exn "1" in
    let test_constants = Engine.Network.constraint_constants network in
    let receiver_pub_key =
      fish1.keypair.public_key |> Signature_lib.Public_key.compress
    in
    let sender_pub_key =
      fish2.keypair.public_key |> Signature_lib.Public_key.compress
    in
    let sender_account_id = Account_id.create sender_pub_key Token_id.default in
    let txn_body =
      Signed_command_payload.Body.Payment
        { source_pk = sender_pub_key; receiver_pk = receiver_pub_key; amount }
    in
    let%bind { nonce = sender_current_nonce; _ } =
      Network.Node.must_get_account_data ~logger node_b
        ~account_id:sender_account_id
    in
    let user_command_input =
      User_command_input.create ~fee ~nonce:sender_current_nonce
        ~fee_payer_pk:sender_pub_key ~valid_until:None
        ~memo:(Signed_command_memo.create_from_string_exn "")
        ~body:txn_body ~signer:sender_pub_key
        ~sign_choice:(User_command_input.Sign_choice.Keypair fish2.keypair) ()
    in
    [%log info] "user_command_input: $user_command"
      ~metadata:
        [ ( "user_command"
          , User_command_input.Stable.Latest.to_yojson user_command_input )
        ] ;
    let%bind txn_signed =
      User_command_input.to_user_command
        ~get_current_nonce:(fun _ -> failwith "get_current_nonce, don't call me")
        ~nonce_map:
          (Account_id.Map.of_alist_exn
             [ ( Account_id.create sender_pub_key Account_id.Digest.default
               , (sender_current_nonce, sender_current_nonce) )
             ] )
        ~get_account:(fun _ -> `Bootstrapping)
        ~constraint_constants:test_constants ~logger user_command_input
      |> Deferred.bind ~f:Malleable_error.or_hard_error
    in
    let (signed_cmmd, _)
          : Signed_command.t
            * (Unsigned.uint32 * Unsigned.uint32) Account_id.Map.t =
      txn_signed
    in
    (* let snark_worker_pk = Test_config.default.snark_worker_public_key in *)
    let%bind () =
      section "send a single signed payment between 2 fish accounts"
        (let%bind { hash; _ } =
           Network.Node.must_send_payment_with_raw_sig node_b ~logger
             ~sender_pub_key:
               (Signed_command_payload.Body.source_pk signed_cmmd.payload.body)
             ~receiver_pub_key:
               (Signed_command_payload.Body.receiver_pk signed_cmmd.payload.body)
             ~amount:
               ( Signed_command_payload.amount signed_cmmd.payload
               |> Option.value_exn )
             ~fee:(Signed_command_payload.fee signed_cmmd.payload)
             ~nonce:signed_cmmd.payload.common.nonce
             ~memo:
               (Signed_command_memo.to_raw_bytes_exn
                  signed_cmmd.payload.common.memo )
             ~valid_until:signed_cmmd.payload.common.valid_until
             ~raw_signature:
               (Mina_base.Signature.Raw.encode signed_cmmd.signature)
         in
         wait_for t
           (Wait_condition.signed_command_to_be_included_in_frontier
              ~txn_hash:hash ~node_included_in:(`Node node_b) ) )
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
    section_hard
      "send out a bunch more txns to fill up the snark ledger, then wait for \
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
            Hence, 6*2 = 12 transactions untill we get the first snarked ledger.
*)
         send_payments ~logger ~sender_pub_key ~receiver_pub_key
           ~amount:Currency.Amount.one ~fee ~node:sender 12
       in
       wait_for t
         (Wait_condition.ledger_proofs_emitted_since_genesis ~num_proofs:1) )
end
