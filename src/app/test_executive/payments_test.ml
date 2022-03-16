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

  (* DONE BUT UNTESTED: porting send-payments *)
  (* CURRENTLY: port timed accounts test *)
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
        [ { balance = "40000"; timing = Untimed }
        ; { balance = "30000"; timing = Untimed }
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
    (* fee for user commands *)
    let fee = Currency.Fee.of_int 10_000_000 in
    let all_nodes = Network.all_nodes network in
    let%bind () = wait_for t (Wait_condition.nodes_to_initialize all_nodes) in
    let[@warning "-8"] [ untimed_node_a; untimed_node_b; timed_node_a ] =
      Network.block_producers network
    in
    let%bind () =
      section "send a single payment between 2 untimed accounts"
        (let amount = Currency.Amount.of_int 2_000_000_000 in
         let fee = Currency.Fee.of_int 10_000_000 in
         let%bind receiver_pub_key = Util.pub_key_of_node untimed_node_a in

         let kp =
           (Node.network_keypair untimed_node_b |> Option.value_exn).keypair
         in
         (* let ({ public_key = sender_pub_key_uncompressed
                 ; private_key = sender_priv_key
                 }
                  : Signature_lib.Keypair.t) =
              (Node.network_keypair untimed_node_b |> Option.value_exn).keypair
            in *)
         let sender_pub_key =
           kp.public_key |> Signature_lib.Public_key.compress
         in
         let txn_body =
           Signed_command_payload.Body.Payment
             { source_pk = sender_pub_key
             ; receiver_pk = receiver_pub_key
             ; token_id = Token_id.default
             ; amount
             }
         in
         (* let%bind signature =
              match signature with
              | Some signature ->
                  return signature
              | None ->
                  Deferred.Result.fail "Signature field is missing"
            in
            let%bind user_command_input =
              Mutations.make_signed_user_command ~nonce_opt ~signer:sender_pub_key ~memo ~fee
                ~fee_token:Token_id.default ~fee_payer_pk:sender_pub_key ~valid_until ~txn_body ~signature
            in *)
         let user_command_input =
           User_command_input.create ~fee ~fee_token:Token_id.default
             ~fee_payer_pk:sender_pub_key ~valid_until:None
             ~memo:(Signed_command_memo.of_string "")
             ~body:txn_body ~signer:sender_pub_key
             ~sign_choice:(User_command_input.Sign_choice.Keypair kp) ()
           (* (Marlin_plonk_bindings_pasta_fp.t, bool) Public_key.Compressed.Poly.t *)
         in
         let%bind txn_signed =
           User_command_input.to_user_command
             ~get_current_nonce:(fun _ -> failwith "don't call me")
             ~get_account:(fun _ -> failwith "don't call me")
             ~constraint_constants:(Engine.Network.constraint_constants network)
             ~logger user_command_input
           |> Deferred.bind ~f:Malleable_error.or_hard_error
         in
         let (signed_cmmd, _)
               : Signed_command.t
                 * (Unsigned.uint32 * Unsigned.uint32) Account_id.Map.t =
           txn_signed
         in
         (* let {_ ; _ ; extracted_sig } = signed_cmmd in *)
         (* : ((Signed_command_payload.Common.t, Signed_command_payload.Body.t)
             Signed_command_payload.Poly.t,
             Marlin_plonk_bindings_pasta_fp.t * Marlin_plonk_bindings_pasta_fp.t,
             Marlin_plonk_bindings_pasta_fp.t * Marlin_plonk_bindings_pasta_fq.t)
            Signed_command.Poly.t
         *)
         let%bind { nonce; _ } =
           Network.Node.must_send_payment_with_raw_sig untimed_node_b ~logger
             ~sender_pub_key ~receiver_pub_key ~amount ~fee
             ~raw_signature:
               (Mina_base.Signature.Raw.encode signed_cmmd.signature)
         in
         wait_for t
           (Wait_condition.signed_command_to_be_included_in_frontier
              ~sender_pub_key ~receiver_pub_key ~amount ~nonce
              ~command_type:Send_payment))
    in
    let%bind () =
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
    in
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
