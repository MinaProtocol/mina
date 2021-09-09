(* open Async *)
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let config =
    let open Test_config in
    { default with
      requires_graphql= true
    ; block_producers=
        [{balance= "4000"; timing= Untimed}; {balance= "3000"; timing= Untimed}]
    ; num_snark_workers= 0 }

  let expected_error_event_reprs = []

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    [%log info] "send_payment_test: starting..." ;
    let receiver_bp = Caml.List.nth (Network.block_producers network) 0 in
    let%bind receiver_pub_key = Util.pub_key_of_node receiver_bp in
    let sender_bp =
      Core_kernel.List.nth_exn (Network.block_producers network) 1
    in
    let%bind sender_pub_key = Util.pub_key_of_node sender_bp in
    (* wait for initialization *)
    let%bind () = wait_for t (Wait_condition.node_to_initialize receiver_bp) in
    let%bind () = wait_for t (Wait_condition.node_to_initialize sender_bp) in
    [%log info] "send_payment_test: done waiting for initialization" ;
    (* send the payment *)
    let amount = Currency.Amount.of_int 200_000_000 in
    let fee = Currency.Fee.of_int 10_000_000 in
    let%bind () =
      Network.Node.send_payment ~logger sender_bp ~sender:sender_pub_key
        ~receiver:receiver_pub_key ~amount ~fee
    in
    (* confirm payment *)
    let%map () =
      wait_for t
        (Wait_condition.payment_to_be_included_in_frontier
           ~sender:sender_pub_key ~receiver:receiver_pub_key ~amount)
    in
    [%log info] "send_payment_test: succesfully completed"
end
