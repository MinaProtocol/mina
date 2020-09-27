(* open Async *)
open Integration_test_lib

module Make (Engine : Engine_intf) = struct
  open Engine

  type network = Network.t

  type log_engine = Log_engine.t

  let config =
    let open Test_config in
    { default with
      block_producers= [{balance= "4000"}; {balance= "3000"}]
    ; num_snark_workers= 0 }

  let run network log_engine =
    let open Malleable_error.Let_syntax in
    let block_producer = Caml.List.nth network.Network.block_producers 0 in
    let%bind () = Log_engine.wait_for_init block_producer log_engine in
    let node = Core_kernel.List.nth_exn network.block_producers 0 in
    let logger = Logger.create () in
    (* wait for initialization *)
    let%bind () = Log_engine.wait_for_init node log_engine in
    [%log info] "send_payment_test: done waiting for initialization" ;
    (* same keypairs used by Coda_automation to populate the ledger *)
    let keypairs = Lazy.force Coda_base.Sample_keypairs.keypairs in
    (* send the payment *)
    let sender, _sk1 = keypairs.(0) in
    let receiver, _sk2 = keypairs.(1) in
    let amount = Currency.Amount.of_int 200_000_000 in
    let fee = Currency.Fee.of_int 10_000_000 in
    let%bind () =
      Node.send_payment ~logger node ~sender ~receiver ~amount ~fee
    in
    (* confirm payment *)
    Log_engine.wait_for_payment log_engine ~logger ~sender ~receiver ~amount ()
end
