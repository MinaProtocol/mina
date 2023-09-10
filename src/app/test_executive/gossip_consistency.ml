open Core
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  let test_name = "gossip-consis"

  let config =
    let open Test_config in
    let open Node_config in
    { default with
      genesis_ledger =
        [ test_account "node-a-key" "1000"; test_account "node-b-key" "1000" ]
    ; block_producers = [ bp "node-a" (); bp "node-b" () ]
    }

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    [%log info] "gossip_consistency test: starting..." ;
    let%bind () =
      wait_for t
        (Wait_condition.nodes_to_initialize
           (Core.String.Map.data (Network.all_nodes network)) )
    in
    [%log info] "gossip_consistency test: done waiting for initializations" ;
    let receiver_bp =
      Core.String.Map.find_exn (Network.block_producers network) "node-a"
    in
    let%bind receiver_pub_key = pub_key_of_node receiver_bp in
    let sender_bp =
      Core.String.Map.find_exn (Network.block_producers network) "node-b"
    in
    let%bind sender_pub_key = pub_key_of_node sender_bp in
    let num_payments = 3 in
    let fee = Currency.Fee.of_nanomina_int_exn 10_000_000 in
    let amount = Currency.Amount.of_nanomina_int_exn 10_000_000 in
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
               num_transactions_seen num_payments )
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
               threshold )
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
