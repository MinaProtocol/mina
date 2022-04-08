open Core
open Integration_test_lib
open Mina_transaction

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
    let n = 3 in
    let open Test_config in
    { default with
      requires_graphql = true
    ; block_producers =
        List.init n ~f:(fun _ ->
            { Block_producer.balance = block_producer_balance
            ; timing = Untimed
            })
    }

  let send_payments ~logger ~sender_pub_key ~receiver_pub_key ~amount ~fee ~node
      n =
    let open Malleable_error.Let_syntax in
    let rec go n hashlist =
      if n = 0 then return hashlist
      else
        let%bind hash =
          let%map { hash; _ } =
            Network.Node.must_send_payment ~logger ~sender_pub_key
              ~receiver_pub_key ~amount ~fee node
          in
          [%log info] "gossip_consistency test: payment #%d sent with hash %s."
            n
            (Transaction_hash.to_base58_check hash) ;
          hash
        in
        go (n - 1) (List.append hashlist [ hash ])
    in
    go n []

  let wait_for_payments ~logger ~dsl ~hashlist n =
    let open Malleable_error.Let_syntax in
    let rec go n hashlist =
      if n = 0 then return ()
      else
        (* confirm payment *)
        let%bind () =
          let hash = List.hd_exn hashlist in
          let%map () =
            wait_for dsl
              (Wait_condition.signed_command_to_be_included_in_frontier
                 ~txn_hash:hash ~node_included_in:`Any_node)
          in
          [%log info]
            "gossip_consistency test: payment #%d with hash %s successfully \
             included in frontier."
            n
            (Transaction_hash.to_base58_check hash) ;
          ()
        in
        go (n - 1) (List.tl_exn hashlist)
    in
    go n hashlist

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    [%log info] "gossip_consistency test: starting..." ;
    let%bind () =
      wait_for t
        (Wait_condition.nodes_to_initialize (Network.all_nodes network))
    in
    [%log info] "gossip_consistency test: done waiting for initializations" ;
    let receiver_bp = Caml.List.nth (Network.block_producers network) 0 in
    let%bind receiver_pub_key = Util.pub_key_of_node receiver_bp in
    let sender_bp =
      Core_kernel.List.nth_exn (Network.block_producers network) 1
    in
    let%bind sender_pub_key = Util.pub_key_of_node sender_bp in
    let num_payments = 3 in
    let fee = Currency.Fee.of_int 10_000_000 in
    let amount = Currency.Amount.of_int 10_000_000 in
    [%log info] "gossip_consistency test: will now send %d payments"
      num_payments ;
    let%bind hashlist =
      send_payments ~logger ~sender_pub_key ~receiver_pub_key ~node:sender_bp
        ~fee ~amount num_payments
    in
    [%log info]
      "gossip_consistency test: sending payments done. will now wait for \
       payments" ;
    let%bind () = wait_for_payments ~logger ~dsl:t ~hashlist num_payments in
    [%log info] "gossip_consistency test: finished waiting for payments" ;
    let gossip_states = (network_state t).gossip_received in
    let num_transactions_seen =
      let open Gossip_state in
      let ss =
        Map.data gossip_states
        |> List.map ~f:(Fn.compose By_direction.received transactions)
      in
      Set.(size (union ss))
    in
    [%log info] "gossip_consistency test: num_transactions_seen = %d"
      num_transactions_seen ;
    let%bind () =
      if num_transactions_seen < num_payments - 1 then (
        let result =
          Malleable_error.soft_error_string ~value:()
            (Printf.sprintf
               "transactions seen = %d, which is less than (numpayments = %d) \
                - 1"
               num_transactions_seen num_payments)
        in
        [%log error]
          "gossip_consistency test: TEST FAILURE.  transactions seen = %d, \
           which is less than (numpayments = %d) - 1"
          num_transactions_seen num_payments ;
        result )
      else
        let result = Malleable_error.ok_unit in
        [%log info] "gossip_consistency test: num_transactions_seen OK" ;
        result
    in
    let `Seen_by_all inter, `Seen_by_some union =
      Gossip_state.stats Transactions_gossip
        (Map.data (network_state t).gossip_received)
        ~exclusion_list:[ Network.Node.id sender_bp ]
    in
    [%log info] "gossip_consistency test: inter = %d; union = %d " inter union ;
    let ratio =
      if union = 0 then 1. else Float.of_int inter /. Float.of_int union
    in
    [%log info] "gossip_consistency test: consistency ratio = %f" ratio ;
    let threshold = 0.95 in
    let%map () =
      if Float.(ratio < threshold) then (
        let result =
          Malleable_error.soft_error_string ~value:()
            (Printf.sprintf
               "consistency ratio = %f, which is less than threshold = %f" ratio
               threshold)
        in
        [%log error]
          "gossip_consistency test: TEST FAILURE. consistency ratio = %f, \
           which is less than threshold = %f"
          ratio threshold ;
        result )
      else
        let result = Malleable_error.ok_unit in
        [%log info] "gossip_consistency test: consistency ratio OK" ;
        result
    in
    [%log info] "gossip_consistency test: test finished!!"
end
