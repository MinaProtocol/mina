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
      block_producers=
        [{balance= "4000"; timing= Untimed}; {balance= "3000"; timing= Untimed}]
    ; num_snark_workers= 0 }

  let expected_error_event_reprs = []

  let pk_of_keypair keypairs n =
    let open Signature_lib in
    let open Keypair in
    let open Core_kernel in
    let {public_key; _} = List.nth_exn keypairs n in
    public_key |> Public_key.compress

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    [%log info] "send_payment_test: starting..." ;
    let block_producer1 = Caml.List.nth (Network.block_producers network) 0 in
    let receiver = pk_of_keypair (Network.keypairs network) 0 in
    let block_producer2 =
      Core_kernel.List.nth_exn (Network.block_producers network) 1
    in
    let sender = pk_of_keypair (Network.keypairs network) 1 in
    (* wait for initialization *)
    let%bind () =
      wait_for t (Wait_condition.node_to_initialize block_producer1)
    in
    let%bind () =
      wait_for t (Wait_condition.node_to_initialize block_producer2)
    in
    [%log info] "send_payment_test: done waiting for initialization" ;
    (* send the payment *)
    let amount = Currency.Amount.of_int 200_000_000 in
    let fee = Currency.Fee.of_int 10_000_000 in
    let%bind () =
      Network.Node.send_payment ~logger block_producer2 ~sender ~receiver
        ~amount ~fee
    in
    (* confirm payment *)
    let%map () =
      wait_for t
        (Wait_condition.payment_to_be_included_in_frontier ~sender ~receiver
           ~amount)
    in
    [%log info] "send_payment_test: succesfully completed"
end
