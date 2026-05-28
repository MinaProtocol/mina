open Integration_test_lib
open Mina_base

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  (* TODO: find a way to avoid this type alias (first class module signatures
     restrictions make this tricky) *)
  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let fork_config : Runtime_config.Fork_config.t =
    { state_hash = "3NKSiqFZQmAS12U8qeX4KNo8b4199spwNh7mrSs4Ci1Vacpfix2Q"
    ; blockchain_length = 300000
    ; global_slot_since_genesis = 500000
    }

  let config ~constants =
    let open Test_config in
    let staking_accounts : Test_account.t list =
      let open Test_account in
      [ create ~account_name:"node-a-key" ~balance:"1000" ~timing:Untimed ()
      ; create ~account_name:"node-b-key" ~balance:"1000" ~timing:Untimed ()
      ]
    in
    let staking : Test_config.Epoch_data.Data.t =
      let epoch_seed =
        Epoch_seed.to_base58_check Snark_params.Tick.Field.(of_int 42)
      in
      let epoch_ledger = staking_accounts in
      { epoch_ledger; epoch_seed }
    in
    let next_accounts : Test_account.t list =
      let open Test_account in
      [ create ~account_name:"node-a-key" ~balance:"0" ~timing:Untimed ()
      ; create ~account_name:"node-b-key" ~balance:"0" ~timing:Untimed ()
      ]
    in
    let next : Test_config.Epoch_data.Data.t =
      let epoch_seed =
        Epoch_seed.to_base58_check Snark_params.Tick.Field.(of_int 1729)
      in
      let epoch_ledger = next_accounts in
      { epoch_ledger; epoch_seed }
    in
    { (default ~constants) with
      requires_graphql = true
    ; epoch_data = Some { staking; next = Some next }
    ; genesis_ledger = next_accounts
    ; block_producers =
        [ { node_name = "node-a"; account_name = "node-a-key" }
        ; { node_name = "node-b"; account_name = "node-b-key" }
        ]
    ; proof_config = { proof_config_default with fork = Some fork_config }
    }

  let run ~config:_ network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let all_mina_nodes = Network.all_mina_nodes network in
    let%bind () =
      wait_for t
        (Wait_condition.nodes_to_initialize
           (Core.String.Map.data all_mina_nodes) )
    in
    (* Since I made the balances of block producers in genesis ledger and next
       epoch ledgers to be 0, then blocks would only be produced, if the
       consensus selects the staking epoch *)
    let%bind () =
      section "wait for 3 block to be produced"
        (wait_for t (Wait_condition.blocks_to_be_produced 3))
    in
    section
      "GraphQL exposes total_stake on staking epoch ledger and total_stake <= \
       total_currency (MIP-0010)"
      (let any_node = Core.List.hd_exn (Core.String.Map.data all_mina_nodes) in
       let%bind blocks =
         Integration_test_lib.Graphql_requests.must_get_best_chain_stake_totals
           ~max_length:1 ~logger
           (Network.Node.get_ingress_uri any_node)
       in
       let block =
         match blocks with
         | b :: _ ->
             b
         | [] ->
             failwith "expected at least one best-chain block"
       in
       let { Mina_graphql_client.Types.total_currency; total_stake } =
         block.staking
       in
       [%log info] "staking epoch ledger: total_currency=%s total_stake=%s"
         (Currency.Amount.to_mina_string total_currency)
         (Currency.Amount.to_mina_string total_stake) ;
       if Currency.Amount.(total_stake <= total_currency) then
         Malleable_error.return ()
       else
         Malleable_error.hard_error_format
           "staking epoch ledger: total_stake (%s) > total_currency (%s)"
           (Currency.Amount.to_mina_string total_stake)
           (Currency.Amount.to_mina_string total_currency) )
end
