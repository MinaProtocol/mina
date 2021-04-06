open Integration_test_lib
open Core_kernel

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  (* TODO: find a way to avoid this type alias (first class module signatures restrictions make this tricky) *)
  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let block_producer_balance = "1000" (* 1_000_000_000_000 *)

  let config =
    let open Test_config in
    let open Test_config.Block_producer in
    let open Currency in
    let make_timing ~min_balance ~cliff_time ~cliff_amount ~vesting_period
        ~vesting_increment : Mina_base.Account_timing.t =
      Timed
        { initial_minimum_balance= Balance.of_int min_balance
        ; cliff_time= Mina_numbers.Global_slot.of_int cliff_time
        ; cliff_amount= Amount.of_int cliff_amount
        ; vesting_period= Mina_numbers.Global_slot.of_int vesting_period
        ; vesting_increment= Amount.of_int vesting_increment }
    in
    let timing1 =
      make_timing ~min_balance:100_000_000_000 ~cliff_time:4 ~cliff_amount:0
        ~vesting_period:2 ~vesting_increment:50_000_000_000
    in
    let timing2 =
      make_timing ~min_balance:650_000_000_000 ~cliff_time:2000 ~cliff_amount:0
        ~vesting_period:1 ~vesting_increment:500_000_000_000
    in
    { default with
      requires_graphql= true
    ; block_producers=
        [ {balance= block_producer_balance; timing= timing1}
        ; {balance= block_producer_balance; timing= timing2} ] }

  let expected_error_event_reprs =
    let open Network_pool.Transaction_pool in
    [rejecting_command_for_reason_structured_events_repr]

  let run network t =
    let open Network in
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let receiver_bp = List.nth_exn (Network.block_producers network) 0 in
    let%bind receiver_pub_key = Util.pub_key_of_node receiver_bp in
    let sender_bp = List.nth_exn (Network.block_producers network) 1 in
    let%bind sender_pub_key = Util.pub_key_of_node sender_bp in
    [%log info] "Waiting for block producer 1 (of 2) to initialize" ;
    let%bind () = wait_for t (Wait_condition.node_to_initialize receiver_bp) in
    [%log info] "Block producer 1 (of 2) initialized" ;
    [%log info] "Waiting for block producer 2 (of 2) to initialize" ;
    let%bind () = wait_for t (Wait_condition.node_to_initialize sender_bp) in
    [%log info] "Block producer 2 (of 2) initialized" ;
    let fee = Currency.Fee.of_int 10_000_000 in
    [%log info] "Sending payment, should succeed" ;
    let amount = Currency.Amount.of_int 300_000_000_000 in
    let payment_or_error =
      Node.send_payment ~retry_on_graphql_error:false ~logger sender_bp
        ~sender:sender_pub_key ~receiver:receiver_pub_key ~amount ~fee
    in
    let%bind () =
      match%bind.Async_kernel.Deferred.Let_syntax payment_or_error with
      | Ok {computation_result= _; soft_errors= _} ->
          [%log info] "Payment succeeded, as expected" ;
          Malleable_error.return ()
      | Error {hard_error= {error; _}; soft_errors= _} ->
          let err_str = Error.to_string_mach error in
          [%log error] "Unexpected payment failure in GraphQL"
            ~metadata:[("error", `String err_str)] ;
          Malleable_error.of_string_hard_error_format
            "Unexpected payment failure in GraphQL: %s" err_str
    in
    [%log info] "Waiting for payment to appear in breadcrumb" ;
    let%bind () =
      wait_for t
        (Wait_condition.payment_to_be_included_in_frontier
           ~sender:sender_pub_key ~receiver:receiver_pub_key ~amount)
    in
    [%log info] "Got breadcrumb with desired payment" ;
    [%log info]
      "Sending payment, should fail because of minimum balance violation" ;
    let amount' = Currency.Amount.of_int 600_000_000_000 in
    let payment_or_error =
      Node.send_payment ~retry_on_graphql_error:false ~logger sender_bp
        ~sender:sender_pub_key ~receiver:receiver_pub_key ~amount:amount' ~fee
    in
    let%map () =
      match%bind.Async_kernel.Deferred.Let_syntax payment_or_error with
      | Ok {computation_result= _; soft_errors= _} ->
          [%log error]
            "Payment succeeded, but expected it to fail because of a minimum \
             balance violation" ;
          Malleable_error.of_string_hard_error
            "Payment succeeded when it should have failed"
      | Error {hard_error= {error; _}; soft_errors= _} ->
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
            Malleable_error.of_string_hard_error_format
              "Payment failed for unexpected reason: %s" err_str )
    in
    [%log info] "Payment test with timed accounts completed"
end
