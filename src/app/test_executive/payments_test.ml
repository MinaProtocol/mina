open Core
open Async
open Integration_test_lib
open Mina_base

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  (* TODO: find a way to avoid this type alias (first class module signatures restrictions make this tricky) *)
  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  (* TODO: refactor all currency values to decimal represenation *)
  (* TODO: test account creation fee *)
  (* TODO: test snark work *)
  let config =
    let open Test_config in
    let open Test_config.Block_producer in
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
    ; block_producers =
        [ { balance = "40000"; timing = Untimed } (* 40_000_000_000_000 *)
        ; { balance = "30000"; timing = Untimed } (* 30_000_000_000_000 *)
        ; { balance = "10000"
          ; timing =
              make_timing ~min_balance:1_000_000_000_000 ~cliff_time:8
                ~cliff_amount:0 ~vesting_period:4
                ~vesting_increment:500_000_000_000
          }
        ]
    ; num_snark_workers =
        3
        (* this test doesn't need snark workers, however turning it on in this test just to make sure the snark workers function within integration tests *)
    }

  let run network t =
    let open Network in
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let all_nodes = Network.all_nodes network in
    let%bind () = wait_for t (Wait_condition.nodes_to_initialize all_nodes) in
    let[@warning "-8"] [ untimed_node_a; untimed_node_b; timed_node_a ] =
      Network.block_producers network
    in
    (* create a signed txn which we'll use to make a successfull txn, and then a replay attack *)
    let amount = Currency.Amount.of_int 2_000_000_000_000 in
    let fee = Currency.Fee.of_int 10_000_000 in
    let test_constants = Engine.Network.constraint_constants network in
    let%bind receiver_pub_key = Util.pub_key_of_node untimed_node_a in
    let sender_kp =
      (Node.network_keypair untimed_node_b |> Option.value_exn).keypair
    in
    let sender_pub_key =
      sender_kp.public_key |> Signature_lib.Public_key.compress
    in
    let txn_body =
      Signed_command_payload.Body.Payment
        { source_pk = sender_pub_key
        ; receiver_pk = receiver_pub_key
        ; token_id = Token_id.default
        ; amount
        }
    in
    let%bind { nonce = sender_current_nonce; _ } =
      Network.Node.must_get_balance ~logger untimed_node_b
        ~public_key:sender_pub_key
    in
    let user_command_input =
      User_command_input.create ~fee ~nonce:sender_current_nonce
        ~fee_token:(Signed_command_payload.Body.token txn_body)
        ~fee_payer_pk:sender_pub_key ~valid_until:None
        ~memo:(Signed_command_memo.create_from_string_exn "")
        ~body:txn_body ~signer:sender_pub_key
        ~sign_choice:(User_command_input.Sign_choice.Keypair sender_kp) ()
    in
    [%log info] "user_command_input: $user_command"
      ~metadata:
        [ ( "user_command"
          , User_command_input.Stable.Latest.to_yojson user_command_input )
        ] ;
    let%bind txn_signed =
      User_command_input.to_user_command
        ~get_current_nonce:(fun _ ->
          failwith "get_current_nonce, don't call me")
        ~nonce_map:
          (Account_id.Map.of_alist_exn
             [ ( Account_id.create sender_pub_key
                   (Signed_command_payload.Body.token txn_body)
               , (sender_current_nonce, sender_current_nonce) )
             ])
        ~get_account:(fun _ -> `Bootstrapping)
          (* (fun _ -> failwith "get_account, don't call me") *)
        ~constraint_constants:test_constants ~logger user_command_input
      |> Deferred.bind ~f:Malleable_error.or_hard_error
    in
    let (signed_cmmd, _)
          : Signed_command.t
            * (Unsigned.uint32 * Unsigned.uint32) Account_id.Map.t =
      txn_signed
    in
    (* setup complete *)
    let%bind () =
      section "send a single payment between 2 untimed accounts"
        (let%bind { nonce; _ } =
           Network.Node.must_send_payment_with_raw_sig untimed_node_b ~logger
             ~sender_pub_key:
               (Signed_command_payload.Body.source_pk signed_cmmd.payload.body)
             ~receiver_pub_key:
               (Signed_command_payload.Body.receiver_pk
                  signed_cmmd.payload.body)
             ~amount:
               ( Signed_command_payload.amount signed_cmmd.payload
               |> Option.value_exn )
             ~fee:(Signed_command_payload.fee signed_cmmd.payload)
             ~nonce:signed_cmmd.payload.common.nonce
             ~memo:
               (Signed_command_memo.to_raw_bytes_exn
                  signed_cmmd.payload.common.memo)
             ~token:(Signed_command_payload.token signed_cmmd.payload)
             ~valid_until:signed_cmmd.payload.common.valid_until
             ~raw_signature:
               (Mina_base.Signature.Raw.encode signed_cmmd.signature)
         in
         wait_for t
           (Wait_condition.signed_command_to_be_included_in_frontier
              ~sender_pub_key ~receiver_pub_key ~amount ~nonce
              ~command_type:Send_payment))
    in
    let%bind () =
      section
        "check that the account balances are what we expect after the previous \
         txn"
        (let%bind { total_balance = node_b_balance; _ } =
           Network.Node.must_get_balance ~logger untimed_node_b
             ~public_key:sender_pub_key
           (* ~account_id:
              (Mina_base.Account_id.create sender_pub_key Token_id.default) *)
         in
         let%bind { total_balance = node_a_balance; _ } =
           Network.Node.must_get_balance ~logger untimed_node_a
             ~public_key:receiver_pub_key
           (* ~account_id:
              (Mina_base.Account_id.create receiver_pub_key Token_id.default) *)
         in
         let node_a_expected =
           (* 40_000_000_000_000 is hardcoded as the original amount, change this is original amount changes *)
           Currency.Amount.add
             (Currency.Amount.of_int 40_000_000_000_000)
             amount
           |> Option.value_exn
         in

         let node_b_expected =
           Currency.Amount.sub
             ( Currency.Amount.add
                 (* 30_000_000_000_000 is hardcoded the original amount, change this is original amount changes *)
                 (Currency.Amount.of_int 30_000_000_000_000)
                 test_constants.coinbase_amount
             |> Option.value_exn )
             amount
           |> Option.value_exn
         in
         [%log info] "coinbase_amount: %s"
           (Currency.Amount.to_formatted_string test_constants.coinbase_amount) ;
         [%log info] "txn_amount: %s"
           (Currency.Amount.to_formatted_string amount) ;
         [%log info] "node_a_expected: %s"
           (Currency.Amount.to_formatted_string node_a_expected) ;
         [%log info] "node_b_expected: %s"
           (Currency.Amount.to_formatted_string node_b_expected) ;
         [%log info] "node_a_balance: %s"
           (Currency.Balance.to_formatted_string node_a_balance) ;
         [%log info] "node_b_balance: %s"
           (Currency.Balance.to_formatted_string node_b_balance) ;
         if
           (* node_a is the receiver *)
           (* node_a_balance >= 40_000_000_000_000 + txn_amount *)
           (* coinbase_amount is much less than txn_amount, so that even if node_a receives a coinbase, the balance (before receiving currency from a txn) should be less than original_amount + txn_amount *)
           Currency.Amount.( >= )
             (Currency.Balance.to_amount node_a_balance)
             node_a_expected
           (* node_b is the sender *)
           (* node_b_balance <= (30_000_000_000_000 + possible_coinbase_reward) - txn_amount *)
           && Currency.Amount.( <= )
                (Currency.Balance.to_amount node_b_balance)
                node_b_expected
         then Malleable_error.return ()
         else
           Malleable_error.soft_error_format ~value:()
             "Error with account balances.  receiving node_a balance is %d and \
              should be at least %d, node_b balance is %d and should be at \
              most %d.  possible coinbase_amount is %d, and txn_amount is %d"
             (Currency.Balance.to_int node_a_balance)
             (Currency.Amount.to_int node_a_expected)
             (Currency.Balance.to_int node_b_balance)
             (Currency.Amount.to_int node_b_expected)
             (Currency.Amount.to_int test_constants.coinbase_amount)
             (Currency.Amount.to_int amount))
    in
    let%bind () =
      section
        "attempt to send again the same signed transaction command as before \
         to conduct a replay attack"
        (let open Deferred.Let_syntax in
        match%bind
          Network.Node.send_payment_with_raw_sig untimed_node_b ~logger
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
                 signed_cmmd.payload.common.memo)
            ~token:(Signed_command_payload.token signed_cmmd.payload)
            ~valid_until:signed_cmmd.payload.common.valid_until
            ~raw_signature:
              (Mina_base.Signature.Raw.encode signed_cmmd.signature)
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
    (* let%bind () =
         section "send a single payment between 2 untimed accounts"
           (let amount = Currency.Amount.of_int 2_000_000_000 in
            let fee = Currency.Fee.of_int 10_000_000 in
            let receiver = untimed_node_a in
            let%bind receiver_pub_key = Util.pub_key_of_node receiver in
            let sender = untimed_node_b in
            let%bind sender_pub_key = Util.pub_key_of_node sender in
            let%bind { nonce; _ } =
              Network.Node.must_send_payment ~logger sender ~sender_pub_key
                ~receiver_pub_key ~amount ~fee
            in
            wait_for t
              (Wait_condition.signed_command_to_be_included_in_frontier
                 ~sender_pub_key ~receiver_pub_key ~amount ~nonce
                 ~command_type:Send_payment))
       in *)
    let%bind () =
      section "send a single payment from timed account using available liquid"
        (let amount = Currency.Amount.of_int 3_000_000_000_000 in
         let receiver = untimed_node_a in
         let%bind receiver_pub_key = Util.pub_key_of_node receiver in
         let sender = timed_node_a in
         let%bind sender_pub_key = Util.pub_key_of_node sender in
         let%bind { nonce; _ } =
           Network.Node.must_send_payment ~logger sender ~sender_pub_key
             ~receiver_pub_key ~amount ~fee
         in
         wait_for t
           (Wait_condition.signed_command_to_be_included_in_frontier
              ~sender_pub_key ~receiver_pub_key ~amount ~nonce
              ~command_type:Send_payment))
    in
    section "unable to send payment from timed account using illiquid tokens"
      (let amount = Currency.Amount.of_int 6_900_000_000_000 in
       let receiver = untimed_node_b in
       let%bind receiver_pub_key = Util.pub_key_of_node receiver in
       let sender = timed_node_a in
       let%bind sender_pub_key = Util.pub_key_of_node sender in
       (* TODO: refactor this using new [expect] dsl when it's available *)
       let open Deferred.Let_syntax in
       match%bind
         Node.send_payment ~logger sender ~sender_pub_key ~receiver_pub_key
           ~amount ~fee
       with
       | Ok _ ->
           Malleable_error.soft_error_string ~value:()
             "Payment succeeded, but expected it to fail because of a minimum \
              balance violation"
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
               "Payment failed for unexpected reason: %s" err_str ))
end
