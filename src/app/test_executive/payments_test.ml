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
  (* TODO: test snark work *)
  let config =
    let open Test_config in
    let open Test_config.Wallet in
    let make_timing ~min_balance ~cliff_time ~cliff_amount ~vesting_period
        ~vesting_increment : Mina_base.Account_timing.t =
      let open Currency in
      Timed
        { initial_minimum_balance = Balance.nanomina_unsafe min_balance
        ; cliff_time = Mina_numbers.Global_slot.of_int cliff_time
        ; cliff_amount = Amount.nanomina_unsafe cliff_amount
        ; vesting_period = Mina_numbers.Global_slot.of_int vesting_period
        ; vesting_increment = Amount.nanomina_unsafe vesting_increment
        }
    in
    { default with
      requires_graphql = true
    ; block_producers =
        [ { balance = "400000"; timing = Untimed } (* 400_000_000_000_000 *)
        ; { balance = "300000"; timing = Untimed } (* 300_000_000_000_000 *)
        ; { balance = "30000"
          ; timing =
              make_timing ~min_balance:10_000_000_000_000 ~cliff_time:8
                ~cliff_amount:0 ~vesting_period:4
                ~vesting_increment:5_000_000_000_000
          }
          (* 30_000_000_000_000 mina is the total.  initially, the balance will be 10k mina.  after 8 global slots, the cliff is hit, although the cliff amount is 0.  4 slots after that, 5_000_000_000_000 mina will vest, and 4 slots after that another 5_000_000_000_000 will vest, and then twice again, for a total of 30k mina all fully liquid and unlocked at the end of the schedule*)
        ]
    ; extra_genesis_accounts =
        [ { balance = "1000"; timing = Untimed }
        ; { balance = "1000"; timing = Untimed }
        ]
    ; num_archive_nodes = 1
    ; num_snark_workers = 4
    ; snark_worker_fee = "0.0001"
    ; proof_config =
        { proof_config_default with
          work_delay = Some 1
        ; transaction_capacity =
            Some Runtime_config.Proof_keys.Transaction_capacity.small
        }
    }

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

  let run network t =
    let open Network in
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let all_nodes = Network.all_nodes network in
    let%bind () = wait_for t (Wait_condition.nodes_to_initialize all_nodes) in
    let[@warning "-8"] [ untimed_node_a; untimed_node_b; timed_node_c ] =
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
    (* create a signed txn which we'll use to make a successfull txn, and then a replay attack *)
    let amount = Currency.Amount.of_formatted_string "10" in
    let fee = Currency.Fee.of_formatted_string "1" in
    let test_constants = Engine.Network.constraint_constants network in
    let receiver_pub_key =
      fish1.public_key |> Signature_lib.Public_key.compress
    in
    let sender_kp = fish2 in
    let sender_pub_key =
      sender_kp.public_key |> Signature_lib.Public_key.compress
    in
    (* hardcoded copy of extra_genesis_accounts[0] and extra_genesis_accounts[1], update here if they change *)
    let receiver_original_balance =
      Currency.Amount.of_formatted_string "1000"
    in
    let sender_original_balance = Currency.Amount.of_formatted_string "1000" in
    let sender_account_id = Account_id.create sender_pub_key Token_id.default in
    let receiver_account_id =
      Account_id.create receiver_pub_key Token_id.default
    in
    let txn_body =
      Signed_command_payload.Body.Payment
        { source_pk = sender_pub_key; receiver_pk = receiver_pub_key; amount }
    in
    let%bind { nonce = sender_current_nonce; _ } =
      Network.Node.must_get_account_data ~logger untimed_node_b
        ~account_id:sender_account_id
    in
    let user_command_input =
      User_command_input.create ~fee ~nonce:sender_current_nonce
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
        ~get_current_nonce:(fun _ -> failwith "get_current_nonce, don't call me")
        ~nonce_map:
          (Account_id.Map.of_alist_exn
             [ ( Account_id.create sender_pub_key Account_id.Digest.default
               , (sender_current_nonce, sender_current_nonce) )
             ] )
        ~get_account:(fun _ : Account.t option Participating_state.t ->
          `Bootstrapping )
        ~constraint_constants:test_constants ~logger user_command_input
      |> Deferred.bind ~f:Malleable_error.or_hard_error
    in
    let (signed_cmmd, _)
          : Signed_command.t
            * (Mina_numbers.Account_nonce.t * Mina_numbers.Account_nonce.t)
              Account_id.Map.t =
      txn_signed
    in
    (* setup complete *)
    let%bind () =
      section "send a single payment between 2 untimed accounts"
        (let%bind { hash; _ } =
           Network.Node.must_send_payment_with_raw_sig untimed_node_b ~logger
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
              ~txn_hash:hash ~node_included_in:(`Node untimed_node_b) ) )
    in
    let%bind () =
      section
        "check that the account balances are what we expect after the previous \
         txn"
        (let%bind { total_balance = receiver_balance; _ } =
           Network.Node.must_get_account_data ~logger untimed_node_b
             ~account_id:receiver_account_id
         in
         let%bind { total_balance = sender_balance; _ } =
           Network.Node.must_get_account_data ~logger untimed_node_b
             ~account_id:sender_account_id
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
             (Currency.Balance.int_of_nanomina receiver_balance)
             (Currency.Amount.int_of_nanomina receiver_expected)
             (Currency.Balance.int_of_nanomina sender_balance)
             (Currency.Amount.int_of_nanomina sender_expected)
             (Currency.Amount.int_of_nanomina amount) )
    in
    let%bind () =
      section
        "attempt to send again the same signed transaction command as before \
         to conduct a replay attack. expecting a bad nonce"
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
                 signed_cmmd.payload.common.memo )
            ~valid_until:signed_cmmd.payload.common.valid_until
            ~raw_signature:
              (Mina_base.Signature.Raw.encode signed_cmmd.signature)
        with
        | Ok { nonce; _ } ->
            Malleable_error.soft_error_format ~value:()
              "Replay attack succeeded, but it should fail because the nonce \
               is old.  attempted nonce: %d"
              (Mina_numbers.Account_nonce.to_int nonce)
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
         but changing the nonce, to conduct a replay attack.  expecting a \
         Invalid_signature"
        (let open Deferred.Let_syntax in
        match%bind
          Network.Node.send_payment_with_raw_sig untimed_node_a ~logger
            ~sender_pub_key:
              (Signed_command_payload.Body.source_pk signed_cmmd.payload.body)
            ~receiver_pub_key:
              (Signed_command_payload.Body.receiver_pk signed_cmmd.payload.body)
            ~amount:
              ( Signed_command_payload.amount signed_cmmd.payload
              |> Option.value_exn )
            ~fee:(Signed_command_payload.fee signed_cmmd.payload)
            ~nonce:
              (Mina_numbers.Account_nonce.succ signed_cmmd.payload.common.nonce)
            ~memo:
              (Signed_command_memo.to_raw_bytes_exn
                 signed_cmmd.payload.common.memo )
            ~valid_until:signed_cmmd.payload.common.valid_until
            ~raw_signature:
              (Mina_base.Signature.Raw.encode signed_cmmd.signature)
        with
        | Ok { nonce; _ } ->
            Malleable_error.soft_error_format ~value:()
              "Replay attack succeeded, but it should fail because the \
               signature is wrong.  attempted nonce: %d"
              (Mina_numbers.Account_nonce.to_int nonce)
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
                "Payment failed for unexpected reason: %s" err_str ))
    in
    let%bind () =
      section "send a single payment from timed account using available liquid"
        (let amount = Currency.Amount.mina_unsafe 1_000 in
         let receiver = untimed_node_a in
         let%bind receiver_pub_key = Util.pub_key_of_node receiver in
         let sender = timed_node_c in
         let%bind sender_pub_key = Util.pub_key_of_node sender in
         let receiver_account_id =
           Account_id.create receiver_pub_key Token_id.default
         in
         let%bind { total_balance = timed_node_c_total
                  ; liquid_balance_opt = timed_node_c_liquid_opt
                  ; locked_balance_opt = timed_node_c_locked_opt
                  ; _
                  } =
           Network.Node.must_get_account_data ~logger timed_node_c
             ~account_id:receiver_account_id
         in
         [%log info] "timed_node_c total balance: %s"
           (Currency.Balance.to_formatted_string timed_node_c_total) ;
         [%log info] "timed_node_c liquid balance: %s"
           (Currency.Balance.to_formatted_string
              ( timed_node_c_liquid_opt
              |> Option.value ~default:Currency.Balance.zero ) ) ;
         [%log info] "timed_node_c liquid locked: %s"
           (Currency.Balance.to_formatted_string
              ( timed_node_c_locked_opt
              |> Option.value ~default:Currency.Balance.zero ) ) ;
         [%log info]
           "Attempting to send txn from timed_node_c to untimed_node_a for \
            amount of %s"
           (Currency.Amount.to_formatted_string amount) ;
         let%bind { hash; _ } =
           Network.Node.must_send_payment ~logger timed_node_c ~sender_pub_key
             ~receiver_pub_key ~amount ~fee
         in
         wait_for t
           (Wait_condition.signed_command_to_be_included_in_frontier
              ~txn_hash:hash ~node_included_in:(`Node timed_node_c) ) )
    in
    let%bind () =
      section "unable to send payment from timed account using illiquid tokens"
        (let amount = Currency.Amount.mina_unsafe 25_000 in
         let receiver = untimed_node_b in
         let%bind receiver_pub_key = Util.pub_key_of_node receiver in
         let sender = timed_node_c in
         let%bind sender_pub_key = Util.pub_key_of_node sender in
         let sender_account_id =
           Account_id.create sender_pub_key Token_id.default
         in
         let%bind { total_balance = timed_node_c_total; _ } =
           Network.Node.must_get_account_data ~logger timed_node_c
             ~account_id:sender_account_id
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
           Node.send_payment ~logger sender ~sender_pub_key ~receiver_pub_key
             ~amount ~fee
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
         let%bind receiver_pub_key = Util.pub_key_of_node receiver in
         let sender = untimed_node_b in
         let%bind sender_pub_key = Util.pub_key_of_node sender in
         let%bind () =
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
           repeat_seq ~n:10 ~f:(fun () ->
               Network.Node.must_send_payment ~logger sender ~sender_pub_key
                 ~receiver_pub_key ~amount:Currency.Amount.one ~fee
               >>| ignore )
         in
         wait_for t
           (Wait_condition.ledger_proofs_emitted_since_genesis ~num_proofs:1) )
    in
    section_hard "running replayer"
      (let%bind logs =
         Network.Node.run_replayer ~logger
           (List.hd_exn @@ Network.archive_nodes network)
       in
       check_replayer_logs ~logger logs )
end
