open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let config ~(constants : Test_config.constants) =
    let open Test_config in
    { (default ~constants) with
      requires_graphql = true
    ; genesis_ledger =
        (let open Test_account in
        [ create ~account_name:"node-a-key" ~balance:"1000" ()
        ; create ~account_name:"node-b-key" ~balance:"1000" ()
        ])
    ; block_producers =
        [ { node_name = "node-a"; account_name = "node-a-key" }
        ; { node_name = "node-b"; account_name = "node-b-key" }
        ]
    }

  let run ~config:_ network t =
    let open Malleable_error.Let_syntax in
    let all_mina_nodes = Network.all_mina_nodes network in
    let%bind () =
      wait_for t
        (Wait_condition.nodes_to_initialize
           (Core.String.Map.data all_mina_nodes) )
    in
    let node_a = Network.block_producer_exn network "node-a" in
    let node_b = Network.block_producer_exn network "node-b" in
    section "nodes are synced"
      (wait_for t (Wait_condition.nodes_to_synchronize [ node_a; node_b ]))
end
