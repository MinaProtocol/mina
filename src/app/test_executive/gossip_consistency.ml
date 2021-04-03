open Core
open Integration_test_lib
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
      requires_graphql= true
    ; block_producers=
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

  let send_payments ~logger ~sender_pub_key ~receiver_pub_key ~amount ~fee
      ~node n =
    let open Malleable_error.Let_syntax in
    let rec go n =
      if n = 0 then return ()
      else
        let%bind () =
          Network.Node.must_send_payment ~retry_on_graphql_error:false ~logger
            ~sender_pub_key ~receiver_pub_key ~amount ~fee node
        in
        go (n - 1)
    in
    go n

  let wait_for_payments ~dsl ~sender_pub_key ~receiver_pub_key ~amount n =
    let open Malleable_error.Let_syntax in
    let rec go n =
      if n = 0 then return ()
      else
        (* confirm payment *)
        let%bind () =
          wait_for dsl
            (Wait_condition.payment_to_be_included_in_frontier ~sender_pub_key
               ~receiver_pub_key ~amount)
        in
        go (n - 1)
    in
    go n

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let%bind () = wait_for_all_to_initialize ~logger network t in
    let receiver_bp = Caml.List.nth (Network.block_producers network) 0 in
    let%bind receiver_pub_key = Util.pub_key_of_node receiver_bp in
    let sender_bp =
      Core_kernel.List.nth_exn (Network.block_producers network) 1
    in
    let%bind sender_pub_key = Util.pub_key_of_node sender_bp in
    let num_payments = 10 in
    let fee = Currency.Fee.of_int 10_000_000 in
    let amount = Currency.Amount.of_int 10_000_000 in
    let%bind () =
      send_payments ~logger ~sender_pub_key ~receiver_pub_key ~node:sender_bp
        ~fee ~amount num_payments
    in
    let%bind () =
      wait_for_payments ~dsl:t ~sender_pub_key ~receiver_pub_key ~amount
        num_payments
    in
    let gossip_states = (network_state t).gossip_received in
    let ratio =
      Gossip_state.consistency_ratio Transactions_gossip
        (Map.data (network_state t).gossip_received)
    in
    let num_transactions_seen =
      let open Gossip_state in
      let ss =
        Map.data gossip_states
        |> List.map ~f:(Fn.compose By_direction.received transactions)
      in
      Set.(size (union ss))
    in
    [%log info] "Transactions seen %d" num_transactions_seen ;
    [%log info] "Consistency ratio %f" ratio ;
    let%bind () =
      if num_transactions_seen < 9 then
        Malleable_error.soft_error_string ~value:()
          (Printf.sprintf "transactions seen = %d < 9" num_transactions_seen)
      else Malleable_error.ok_unit
    in
    let threshold = 0.95 in
    if ratio < threshold then
      Malleable_error.soft_error_string ~value:()
        (Printf.sprintf "consistency ratio = %f < %f" ratio threshold)
    else Malleable_error.ok_unit
end
