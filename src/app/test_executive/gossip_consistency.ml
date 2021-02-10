open Core
open Integration_test_lib
open Currency
open Signature_lib

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
    let n = 5 in
    let open Test_config in
    { default with
      block_producers=
        List.init n ~f:(fun _ ->
            {Block_producer.balance= block_producer_balance; timing= Untimed}
        ) }

  let expected_error_event_reprs = []

  let pk_of_keypair keypairs n =
    Public_key.compress (List.nth_exn keypairs n).Keypair.public_key

  let wait_for_all_to_initialize ~logger network t =
    let open Malleable_error.Let_syntax in
    let producers = Network.block_producers network in
    let n = List.length producers in
    List.mapi producers ~f:(fun i node ->
        let%map () = wait_for t (Wait_condition.node_to_initialize node) in
        [%log info] "Block producer %d (of %d) initialized" (i + 1) n ;
        () )
    |> Malleable_error.all_unit

  let send_payments ~logger ~sender ~receiver ~node n =
    let open Malleable_error.Let_syntax in
    let amount = Currency.Amount.of_int 1 in
    let fee = Currency.Fee.of_int 1 in
    let rec go n =
      if n = 0 then return ()
      else
        let%bind () =
          Network.Node.send_payment ~retry_on_graphql_error:false ~logger node
            ~sender ~receiver ~amount ~fee
        in
        go (n - 1)
    in
    go n

  let run network t =
    let open Network in
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let%bind () = wait_for_all_to_initialize ~logger network t in
    let sender = pk_of_keypair (Network.keypairs network) 1 in
    let receiver = pk_of_keypair (Network.keypairs network) 0 in
    let%bind () =
      let num_payments = 10 in
      send_payments ~logger ~sender ~receiver
        ~node:(List.nth_exn (Network.block_producers network) 1)
        num_payments
    in
    let%bind () =
      let open Async in
      let%bind () = after (Time.Span.of_sec 30.) in
      Malleable_error.ok_unit
    in
    let ratio =
      Gossip_state.consistency_ratio Transactions_gossip
        (Map.data (network_state t).gossip_received)
    in
    [%log info] "Consistency ratio %f" ratio ;
    let threshold = 0.95 in
    if ratio < threshold then
      Malleable_error.of_error_hard
        (Error.createf "consistency ratio = %f < %f" ratio threshold)
    else Malleable_error.ok_unit
end
